# Minimal AI Voice Call Backend

A simple FastAPI backend for making voice calls with AI conversation using Twilio and AWS Nova Sonic.

## Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Copy environment variables:
```bash
cp .env.example .env
```

3. Fill in your credentials in `.env`:
- Twilio Account SID, Auth Token, and Phone Number
- AWS Access Key ID, Secret Access Key, and Region

4. Run the server:
```bash
python server.py
```

## API Endpoints

- `GET /health` - Health check
- `POST /initiate-call` - Start a call with phone number
- `WS /ws/call/{call_id}` - WebSocket for audio streaming
- `POST /webhook/twilio/{call_id}` - Twilio webhook handler
- `GET /call/{call_id}/status` - Get call status

## Usage

Send a POST request to `/initiate-call` with:
```json
{
  "phone_number": "+1234567890"
}
```

The API will return a call ID and initiate the call through Twilio. The AI conversation is handled via WebSocket connection.