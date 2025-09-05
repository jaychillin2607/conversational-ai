import { useState, useRef, useCallback, useEffect } from 'react';
import { CallData, CallResponse, CallStatusResponse } from './types';

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';
const WS_BASE_URL = API_BASE_URL.replace('http', 'ws');

export const useCall = () => {
  const [callData, setCallData] = useState<CallData | null>(null);
  const [isAudioActive, setIsAudioActive] = useState(false);
  const websocketRef = useRef<WebSocket | null>(null);
  const audioContextRef = useRef<AudioContext | null>(null);
  const statusPollingRef = useRef<number | null>(null);

  const validatePhoneNumber = (phoneNumber: string): boolean => {
    const cleanNumber = phoneNumber.replace(/[\s\-\(\)]/g, '');
    return /^\+[1-9]\d{1,14}$/.test(cleanNumber);
  };

  // Status polling function
  const pollCallStatus = useCallback(async (callId: string) => {
    try {
      const response = await fetch(`${API_BASE_URL}/call/${callId}/status`);
      
      if (!response.ok) {
        // Call not found or error - stop polling
        if (statusPollingRef.current) {
          clearInterval(statusPollingRef.current);
          statusPollingRef.current = null;
        }
        return;
      }

      const status: CallStatusResponse = await response.json();
      
      // Update call data based on server status
      setCallData(prev => {
        if (!prev) return null;
        
        // If server says call ended but frontend doesn't know yet
        if (status.status === 'ended' && prev.status !== 'ended') {
          console.log('Call ended detected via status polling');
          setIsAudioActive(false);
          cleanupAudio();
          
          // Stop polling since call is ended
          if (statusPollingRef.current) {
            clearInterval(statusPollingRef.current);
            statusPollingRef.current = null;
          }
          
          return {
            ...prev,
            status: 'ended',
            endTime: new Date()
          };
        }
        
        // Update other status changes
        if (status.status !== prev.status) {
          return {
            ...prev,
            status: status.status as any
          };
        }
        
        return prev;
      });

    } catch (error) {
      console.error('Failed to poll call status:', error);
    }
  }, []);

  // Start status polling
  const startStatusPolling = useCallback((callId: string) => {
    // Clear any existing polling
    if (statusPollingRef.current) {
      clearInterval(statusPollingRef.current);
    }

    // Poll every 2 seconds
    statusPollingRef.current = setInterval(() => {
      pollCallStatus(callId);
    }, 1000);

    console.log('Started status polling for call:', callId);
  }, [pollCallStatus]);

  // Stop status polling
  const stopStatusPolling = useCallback(() => {
    if (statusPollingRef.current) {
      clearInterval(statusPollingRef.current);
      statusPollingRef.current = null;
      console.log('Stopped status polling');
    }
  }, []);

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

      // Start polling call status
      startStatusPolling(result.call_id);

      connectWebSocket(result.call_id);

    } catch (error) {
      setCallData(prev => ({
        ...prev!,
        status: 'error',
        error: error instanceof Error ? error.message : 'Failed to initiate call'
      }));
    }
  }, [startStatusPolling]);

  const connectWebSocket = useCallback((callId: string) => {
    try {
      const wsUrl = `${WS_BASE_URL}/ws/call/${callId}`;
      websocketRef.current = new WebSocket(wsUrl);

      websocketRef.current.onopen = () => {
        console.log('WebSocket connected');
        setCallData(prev => prev ? { ...prev, status: 'connected' } : null);
        setIsAudioActive(true);
        initializeAudio();
      };

      websocketRef.current.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          if (data.type === 'audio') {
            setIsAudioActive(true);
          }
        } catch (error) {
          // Handle non-JSON messages
          console.log('Received non-JSON WebSocket message');
        }
      };

      websocketRef.current.onclose = (event) => {
        console.log('WebSocket closed:', event.code, event.reason);
        setCallData(prev => {
          if (prev && prev.status !== 'ended') {
            return { ...prev, status: 'ended', endTime: new Date() };
          }
          return prev;
        });
        setIsAudioActive(false);
        cleanupAudio();
        stopStatusPolling(); // Stop polling when WebSocket closes
      };

      websocketRef.current.onerror = (error) => {
        console.error('WebSocket error:', error);
        setCallData(prev => prev ? { ...prev, status: 'error', error: 'Connection failed' } : null);
        setIsAudioActive(false);
        cleanupAudio();
        stopStatusPolling(); // Stop polling on error
      };

    } catch (error) {
      setCallData(prev => prev ? { ...prev, status: 'error', error: 'WebSocket connection failed' } : null);
      stopStatusPolling();
    }
  }, [stopStatusPolling]);

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
    console.log('Manually ending call');
    
    if (websocketRef.current) {
      websocketRef.current.close();
    }
    
    setCallData(prev => prev ? { ...prev, status: 'ended', endTime: new Date() } : null);
    setIsAudioActive(false);
    cleanupAudio();
    stopStatusPolling();
  }, [cleanupAudio, stopStatusPolling]);

  const resetCall = useCallback(() => {
    console.log('Resetting call');
    
    if (websocketRef.current) {
      websocketRef.current.close();
    }
    
    setCallData(null);
    setIsAudioActive(false);
    cleanupAudio();
    stopStatusPolling();
  }, [cleanupAudio, stopStatusPolling]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      stopStatusPolling();
      cleanupAudio();
      if (websocketRef.current) {
        websocketRef.current.close();
      }
    };
  }, [stopStatusPolling, cleanupAudio]);

  return {
    callData,
    isAudioActive,
    initiateCall,
    endCall,
    resetCall,
    validatePhoneNumber
  };
};