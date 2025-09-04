import asyncio
from twilio.rest import Client
from twilio.base.exceptions import TwilioException
from loguru import logger

from config import get_settings

class TwilioClient:
    def __init__(self):
        settings = get_settings()
        self.client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
        self.phone_number = settings.TWILIO_PHONE_NUMBER
    
    async def make_call(self, to: str, webhook_url: str):
        try:
            loop = asyncio.get_event_loop()
            call = await loop.run_in_executor(
                None,
                lambda: self.client.calls.create(
                    to=to,
                    from_=self.phone_number,
                    url=webhook_url,
                    method="POST",
                    record=False
                )
            )
            logger.info(f"Twilio call created: {call.sid}")
            return call
            
        except TwilioException as e:
            logger.error(f"Twilio call failed: {str(e)}")
            raise e
    
    async def end_call(self, call_sid: str):
        try:
            loop = asyncio.get_event_loop()
            await loop.run_in_executor(
                None,
                lambda: self.client.calls(call_sid).update(status="completed")
            )
            logger.info(f"Twilio call ended: {call_sid}")
            
        except TwilioException as e:
            logger.error(f"Failed to end Twilio call: {str(e)}")
            raise e
    
    def validate_phone_number(self, phone_number: str) -> bool:
        if not phone_number.startswith('+'):
            return False
        
        clean_number = phone_number[1:]
        if not clean_number.isdigit():
            return False
        
        if len(clean_number) < 10 or len(clean_number) > 15:
            return False
            
        return True