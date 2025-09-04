import os
import uuid
from typing import Dict, Any
import json

import uvicorn
from fastapi import FastAPI, WebSocket, HTTPException
from fastapi.responses import Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from loguru import logger

from twilio_client import TwilioClient
from pipecat_pipeline import create_pipeline
from config import get_settings

settings = get_settings()
app = FastAPI()
twilio = TwilioClient()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

active_calls: Dict[str, Dict[str, Any]] = {}


class CallRequest(BaseModel):
    phone_number: str


class CallResponse(BaseModel):
    call_id: str
    status: str
    message: str


@app.get("/health")
async def health():
    return {"status": "healthy"}


@app.post("/initiate-call", response_model=CallResponse)
async def initiate_call(request: CallRequest):
    if not request.phone_number.startswith('+'):
        raise HTTPException(
            status_code=400, detail="Phone number must include country code")

    call_id = str(uuid.uuid4())

    try:
        twilio_call = await twilio.make_call(
            to=request.phone_number,
            webhook_url=f"{settings.SERVER_URL}/webhook/twilio/{call_id}"
        )

        active_calls[call_id] = {
            "phone_number": request.phone_number,
            "twilio_sid": twilio_call.sid,
            "status": "dialing"
        }

        logger.info(f"Call initiated: {call_id} to {request.phone_number}")

        return CallResponse(
            call_id=call_id,
            status="dialing",
            message="Call initiated successfully"
        )

    except Exception as e:
        logger.error(f"Failed to initiate call: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to initiate call")


@app.websocket("/ws/call/{call_id}")
async def call_websocket(websocket: WebSocket, call_id: str):
    await websocket.accept()

    if call_id not in active_calls:
        await websocket.close(code=1000, reason="Call not found")
        return

    logger.info(f"WebSocket connected for call: {call_id}")

    try:
        # Get the first two messages from Twilio
        start_data = websocket.iter_text()
        await start_data.__anext__()  # Skip first message
        # Parse second message
        call_data = json.loads(await start_data.__anext__())

        # Extract Twilio IDs
        stream_sid = call_data["start"]["streamSid"]
        call_sid = call_data["start"]["callSid"]

        logger.info(f"Twilio stream_sid: {stream_sid}, call_sid: {call_sid}")

        # Now create pipeline with the IDs
        pipeline = create_pipeline(websocket, stream_sid, call_sid)
        await pipeline.run()

    except Exception as e:
        logger.error(f"WebSocket error for call {call_id}: {str(e)}")
        await websocket.close(code=1011, reason="Internal error")

    finally:
        if call_id in active_calls:
            active_calls[call_id]["status"] = "ended"
            logger.info(f"Call ended: {call_id}")


@app.post("/webhook/twilio/{call_id}")
async def twilio_webhook(call_id: str):
    if call_id not in active_calls:
        return {"status": "call not found"}

    active_calls[call_id]["status"] = "connected"
    logger.info(f"Twilio webhook received for call: {call_id}")

    twiml = f"""<?xml version="1.0" encoding="UTF-8"?>
    <Response>
        <Connect>
            <Stream url="wss://{settings.SERVER_HOST}/ws/call/{call_id}"></Stream>
        </Connect>
        <Pause length="40"/>
    </Response>"""

    # Return with proper XML content type
    return Response(content=twiml, media_type="application/xml")


@app.get("/call/{call_id}/status")
async def get_call_status(call_id: str):
    if call_id not in active_calls:
        raise HTTPException(status_code=404, detail="Call not found")

    return active_calls[call_id]

if __name__ == "__main__":
    uvicorn.run(
        "server:app",
        host="0.0.0.0",
        port=int(os.getenv("PORT", 8000)),
        reload=True
    )
