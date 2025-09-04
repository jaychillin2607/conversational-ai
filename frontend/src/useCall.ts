import { useState, useRef, useCallback } from 'react';
import { CallData, CallResponse } from './types';

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';
const WS_BASE_URL = API_BASE_URL.replace('http', 'ws');

export const useCall = () => {
  const [callData, setCallData] = useState<CallData | null>(null);
  const [isAudioActive, setIsAudioActive] = useState(false);
  const websocketRef = useRef<WebSocket | null>(null);
  const audioContextRef = useRef<AudioContext | null>(null);

  const validatePhoneNumber = (phoneNumber: string): boolean => {
    const cleanNumber = phoneNumber.replace(/[\s\-\(\)]/g, '');
    return /^\+[1-9]\d{1,14}$/.test(cleanNumber);
  };

  const initiateCall = useCallback(async (phoneNumber: string) => {
    if (!validatePhoneNumber(phoneNumber)) {
      setCallData({
        callId: '',
        phoneNumber,
        status: 'error',
        error: 'Invalid phone number format. Please include country code (e.g., +1234567890)'
      });
      return;
    }

    try {
      setCallData({
        callId: '',
        phoneNumber,
        status: 'dialing',
        startTime: new Date()
      });

      const response = await fetch(`${API_BASE_URL}/initiate-call`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ phone_number: phoneNumber }),
      });

      if (!response.ok) {
        throw new Error('Failed to initiate call');
      }

      const result: CallResponse = await response.json();
      
      setCallData(prev => ({
        ...prev!,
        callId: result.call_id,
        status: 'connecting'
      }));

      connectWebSocket(result.call_id);

    } catch (error) {
      setCallData(prev => ({
        ...prev!,
        status: 'error',
        error: error instanceof Error ? error.message : 'Failed to initiate call'
      }));
    }
  }, []);

  const connectWebSocket = useCallback((callId: string) => {
    try {
      const wsUrl = `${WS_BASE_URL}/ws/call/${callId}`;
      websocketRef.current = new WebSocket(wsUrl);

      websocketRef.current.onopen = () => {
        setCallData(prev => prev ? { ...prev, status: 'connected' } : null);
        setIsAudioActive(true);
        initializeAudio();
      };

      websocketRef.current.onmessage = (event) => {
        const data = JSON.parse(event.data);
        if (data.type === 'audio') {
          setIsAudioActive(true);
        }
      };

      websocketRef.current.onclose = () => {
        setCallData(prev => prev ? { ...prev, status: 'ended', endTime: new Date() } : null);
        setIsAudioActive(false);
        cleanupAudio();
      };

      websocketRef.current.onerror = () => {
        setCallData(prev => prev ? { ...prev, status: 'error', error: 'Connection failed' } : null);
        setIsAudioActive(false);
        cleanupAudio();
      };

    } catch (error) {
      setCallData(prev => prev ? { ...prev, status: 'error', error: 'WebSocket connection failed' } : null);
    }
  }, []);

  const initializeAudio = useCallback(() => {
    try {
      audioContextRef.current = new AudioContext();
    } catch (error) {
      console.error('Failed to initialize audio context:', error);
    }
  }, []);

  const cleanupAudio = useCallback(() => {
    if (audioContextRef.current) {
      audioContextRef.current.close();
      audioContextRef.current = null;
    }
  }, []);

  const endCall = useCallback(() => {
    if (websocketRef.current) {
      websocketRef.current.close();
    }
    setCallData(prev => prev ? { ...prev, status: 'ended', endTime: new Date() } : null);
    setIsAudioActive(false);
    cleanupAudio();
  }, [cleanupAudio]);

  const resetCall = useCallback(() => {
    if (websocketRef.current) {
      websocketRef.current.close();
    }
    setCallData(null);
    setIsAudioActive(false);
    cleanupAudio();
  }, [cleanupAudio]);

  return {
    callData,
    isAudioActive,
    initiateCall,
    endCall,
    resetCall,
    validatePhoneNumber
  };
};