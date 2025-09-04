# Minimal AI Voice Call Frontend

A clean, modern React frontend for making voice calls with AI conversation.

## Features

- **One-click calling** with phone number validation
- **Real-time call states** (dialing, connecting, connected, ended)
- **Audio visualization** during active calls
- **Responsive design** with Tailwind CSS
- **WebSocket integration** for real-time communication
- **Error handling** with user-friendly messages

## Setup

1. Install dependencies:
```bash
npm install
```

2. Copy environment variables:
```bash
cp .env.example .env
```

3. Set your backend URL in `.env`:
```bash
VITE_API_URL=http://localhost:8000
```

4. Start the development server:
```bash
npm run dev
```

The app will be available at `http://localhost:3000`

## Build for Production

```bash
npm run build
npm run preview
```

## Call Flow

1. **Landing Page**: Clean interface with "Make a Call" button
2. **Call Modal**: Opens with phone number input
3. **Validation**: Checks phone number format (+country code)
4. **Dialing**: Shows spinner while initiating call
5. **Connecting**: WebSocket connection establishment
6. **Connected**: Live conversation with audio visualization
7. **Ended**: Call completion with duration summary

## Technologies

- **React 18** with TypeScript
- **Vite** for fast development and building
- **Tailwind CSS** for styling
- **Lucide React** for icons
- **WebSocket** for real-time communication

## Phone Number Format

All phone numbers must include the country code:
- US: `+1234567890`
- India: `+919876543210`
- UK: `+447123456789`