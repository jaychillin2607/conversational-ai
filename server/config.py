from functools import lru_cache
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    TWILIO_ACCOUNT_SID: str
    TWILIO_AUTH_TOKEN: str  
    TWILIO_PHONE_NUMBER: str
    
    AWS_ACCESS_KEY_ID: str
    AWS_SECRET_ACCESS_KEY: str
    AWS_REGION: str = "us-east-1"
    AWS_SESSION_TOKEN: str 
    
    SERVER_URL: str = "http://localhost:8000"
    SERVER_HOST: str = "localhost:8000"
    
    class Config:
        env_file = ".env"

@lru_cache()
def get_settings() -> Settings:
    return Settings()