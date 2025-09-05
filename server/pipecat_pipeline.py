from fastapi import WebSocket
from loguru import logger

from pipecat.audio.vad.silero import SileroVADAnalyzer
from pipecat.pipeline.pipeline import Pipeline
from pipecat.pipeline.runner import PipelineRunner
from pipecat.pipeline.task import PipelineParams, PipelineTask
from pipecat.processors.aggregators.openai_llm_context import OpenAILLMContext
from pipecat.serializers.twilio import TwilioFrameSerializer
from pipecat.services.aws_nova_sonic.aws import AWSNovaSonicLLMService
from pipecat.transports.websocket.fastapi import (
    FastAPIWebsocketParams,
    FastAPIWebsocketTransport
)

from config import get_settings

SYSTEM_PROMPT = """You are a helpful AI assistant making outbound calls. 

IMPORTANT: When the call starts, immediately introduce yourself in a friendly, professional manner. 
Say something like: "Hi! This is your AI assistant. I'm calling to see if there's anything I can help you with today."

After your introduction:
- Ask what they might need assistance with
- Keep responses concise and engaging (2-3 sentences max)
- Ask follow-up questions to keep the conversation flowing
- Be friendly and professional in all interactions
- If they don't need anything, politely thank them and end the call
- If they seem confused about why you're calling, explain you're a helpful AI assistant

Remember to speak naturally and conversationally. Don't be overly formal."""


class CallPipeline:
    def __init__(self, websocket: WebSocket, stream_sid: str = "", call_sid: str = ""):
        self.websocket = websocket
        self.stream_sid = stream_sid
        self.call_sid = call_sid
        self.settings = get_settings()
        self.task = None
        self.context = None  # Store context reference

    async def run(self):
        transport = FastAPIWebsocketTransport(
            websocket=self.websocket,
            params=FastAPIWebsocketParams(
                audio_in_enabled=True,
                audio_out_enabled=True,
                add_wav_header=False,
                vad_analyzer=SileroVADAnalyzer(),
                serializer=TwilioFrameSerializer(
                    stream_sid=self.stream_sid,
                    call_sid=self.call_sid,
                    account_sid=self.settings.TWILIO_ACCOUNT_SID,
                    auth_token=self.settings.TWILIO_AUTH_TOKEN,
                ) if self.stream_sid else None
            )
        )

        llm = AWSNovaSonicLLMService(
            secret_access_key=self.settings.AWS_SECRET_ACCESS_KEY,
            access_key_id=self.settings.AWS_ACCESS_KEY_ID,
            session_token=self.settings.AWS_SESSION_TOKEN,
            region=self.settings.AWS_REGION,
            voice_id="matthew"
        )

        # Store context reference so we can modify it in event handlers
        self.context = OpenAILLMContext(
            messages=[{"role": "system", "content": SYSTEM_PROMPT}]
        )

        context_aggregator = llm.create_context_aggregator(self.context)

        pipeline = Pipeline([
            transport.input(),
            context_aggregator.user(),
            llm,
            transport.output(),
            context_aggregator.assistant(),
        ])

        self.task = PipelineTask(
            pipeline,
            params=PipelineParams(
                enable_metrics=False,
                enable_usage_metrics=False
            )
        )

        @transport.event_handler("on_client_connected")
        async def on_client_connected(transport, client):
            logger.info("Client connected to pipeline - triggering AI introduction")
            
            # Add an initial user message to trigger the AI introduction
            # This simulates the user saying "hello" when they pick up
            initial_trigger = {
                "role": "user", 
                "content": "Hello, I just answered the phone."
            }
            
            # Add the trigger message to context
            self.context.add_message(initial_trigger)
            
            # Queue the updated context frame
            await self.task.queue_frames([context_aggregator.user().get_context_frame()])
            
            # Trigger the AI to respond (this should make it introduce itself)
            await llm.trigger_assistant_response()
            
            logger.info("AI introduction sequence initiated")

        @transport.event_handler("on_client_disconnected")
        async def on_client_disconnected(transport, client):
            logger.info("Client disconnected from pipeline")
            if self.task:
                await self.task.cancel()

        runner = PipelineRunner(handle_sigint=False)

        try:
            await runner.run(self.task)
        except Exception as e:
            logger.error(f"Pipeline error: {str(e)}")
            raise e


def create_pipeline(websocket: WebSocket, stream_sid: str = "", call_sid: str = "") -> CallPipeline:
    return CallPipeline(websocket, stream_sid, call_sid)