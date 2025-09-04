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

SYSTEM_PROMPT = """You are a helpful AI assistant. Have a natural conversation with the caller.
Keep responses concise and engaging. Ask follow-up questions to keep the conversation flowing.
Be friendly and professional in all interactions."""


class CallPipeline:
    def __init__(self, websocket: WebSocket, stream_sid: str = "", call_sid: str = ""):
        self.websocket = websocket
        self.stream_sid = stream_sid
        self.call_sid = call_sid
        self.settings = get_settings()
        self.task = None

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

        context = OpenAILLMContext(
            messages=[{"role": "system", "content": SYSTEM_PROMPT}]
        )

        context_aggregator = llm.create_context_aggregator(context)

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
            logger.info("Client connected to pipeline")
            await self.task.queue_frames([context_aggregator.user().get_context_frame()])
            await llm.trigger_assistant_response()

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
