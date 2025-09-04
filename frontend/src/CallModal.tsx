import React, { useState, useEffect } from 'react';
import { Phone, PhoneOff, X, Loader2, AlertCircle, CheckCircle } from 'lucide-react';
import { CallData } from './types';

interface CallModalProps {
  isOpen: boolean;
  onClose: () => void;
  callData: CallData | null;
  isAudioActive: boolean;
  onInitiateCall: (phoneNumber: string) => void;
  onEndCall: () => void;
  onResetCall: () => void;
  validatePhoneNumber: (phoneNumber: string) => boolean;
}

export const CallModal: React.FC<CallModalProps> = ({
  isOpen,
  onClose,
  callData,
  isAudioActive,
  onInitiateCall,
  onEndCall,
  onResetCall,
  validatePhoneNumber
}) => {
  const [phoneNumber, setPhoneNumber] = useState('');
  const [inputError, setInputError] = useState('');

  useEffect(() => {
    if (callData?.status === 'ended' || callData?.status === 'error') {
      const timer = setTimeout(() => {
        if (callData.status === 'ended') {
          handleClose();
        }
      }, 3000);
      return () => clearTimeout(timer);
    }
  }, [callData?.status]);

  const handleClose = () => {
    onResetCall();
    onClose();
    setPhoneNumber('');
    setInputError('');
  };

  const handlePhoneNumberChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setPhoneNumber(value);
    setInputError('');
  };

  const handleInitiateCall = () => {
    if (!validatePhoneNumber(phoneNumber)) {
      setInputError('Invalid phone number format. Please include country code (e.g., +1234567890)');
      return;
    }
    onInitiateCall(phoneNumber);
  };

  const getStatusDisplay = () => {
    switch (callData?.status) {
      case 'dialing':
        return { icon: <Loader2 className="animate-spin" />, text: 'Dialing...', color: 'text-blue-500' };
      case 'connecting':
        return { icon: <Loader2 className="animate-spin" />, text: 'Connecting...', color: 'text-yellow-500' };
      case 'connected':
        return { icon: <Phone />, text: 'Connected', color: 'text-green-500' };
      case 'ended':
        return { icon: <CheckCircle />, text: 'Call Ended', color: 'text-gray-500' };
      case 'error':
        return { icon: <AlertCircle />, text: 'Call Failed', color: 'text-red-500' };
      default:
        return null;
    }
  };

  const renderCallDuration = () => {
    if (!callData?.startTime) return null;
    
    const endTime = callData.endTime || new Date();
    const duration = Math.floor((endTime.getTime() - callData.startTime.getTime()) / 1000);
    const minutes = Math.floor(duration / 60);
    const seconds = duration % 60;
    
    return (
      <div className="text-sm text-gray-500">
        Duration: {minutes}:{seconds.toString().padStart(2, '0')}
      </div>
    );
  };

  const AudioVisualization = () => {
    if (!isAudioActive) return null;
    
    return (
      <div className="flex items-center justify-center space-x-1 my-4">
        {[...Array(5)].map((_, i) => (
          <div
            key={i}
            className="bg-green-500 rounded-full animate-pulse"
            style={{
              width: '4px',
              height: `${Math.random() * 20 + 10}px`,
              animationDelay: `${i * 100}ms`,
              animationDuration: '1s'
            }}
          />
        ))}
      </div>
    );
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg p-6 w-full max-w-md mx-4 relative">
        <button
          onClick={handleClose}
          className="absolute top-4 right-4 text-gray-400 hover:text-gray-600"
        >
          <X size={24} />
        </button>

        <div className="text-center">
          <h2 className="text-xl font-semibold mb-6">Make a Call</h2>

          {!callData && (
            <>
              <div className="mb-4">
                <input
                  type="tel"
                  value={phoneNumber}
                  onChange={handlePhoneNumberChange}
                  placeholder="+1234567890"
                  className="w-full p-3 border border-gray-300 rounded-lg text-lg text-center focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                {inputError && (
                  <p className="text-red-500 text-sm mt-2">{inputError}</p>
                )}
                <p className="text-gray-500 text-xs mt-2">
                  Include country code (e.g., +1 for US, +91 for India)
                </p>
              </div>
              <button
                onClick={handleInitiateCall}
                disabled={!phoneNumber.trim()}
                className="bg-green-500 hover:bg-green-600 disabled:bg-gray-300 text-white rounded-full p-4 transition-colors"
              >
                <Phone size={24} />
              </button>
            </>
          )}

          {callData && (
            <>
              <div className="mb-6">
                <div className="text-lg font-medium mb-2">{callData.phoneNumber}</div>
                {(() => {
                  const status = getStatusDisplay();
                  return status ? (
                    <div className={`flex items-center justify-center space-x-2 ${status.color}`}>
                      {status.icon}
                      <span>{status.text}</span>
                    </div>
                  ) : null;
                })()}
              </div>

              <AudioVisualization />

              {renderCallDuration()}

              {callData.error && (
                <div className="text-red-500 text-sm mb-4 p-2 bg-red-50 rounded">
                  {callData.error}
                </div>
              )}

              <div className="flex justify-center space-x-4 mt-6">
                {(callData.status === 'connected' || callData.status === 'connecting') && (
                  <button
                    onClick={onEndCall}
                    className="bg-red-500 hover:bg-red-600 text-white rounded-full p-4 transition-colors"
                  >
                    <PhoneOff size={24} />
                  </button>
                )}

                {(callData.status === 'ended' || callData.status === 'error') && (
                  <button
                    onClick={handleClose}
                    className="bg-gray-500 hover:bg-gray-600 text-white px-6 py-2 rounded-lg transition-colors"
                  >
                    Close
                  </button>
                )}
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
};