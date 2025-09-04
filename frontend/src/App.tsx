import  { useState } from 'react';
import { Phone, Bot, Zap } from 'lucide-react';
import { CallModal } from './CallModal';
import { useCall } from './useCall';

function App() {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const {
    callData,
    isAudioActive,
    initiateCall,
    endCall,
    resetCall,
    validatePhoneNumber
  } = useCall();

  const openModal = () => setIsModalOpen(true);
  const closeModal = () => setIsModalOpen(false);

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
      <div className="text-center max-w-2xl mx-auto">
        <div className="mb-8">
          <div className="flex justify-center mb-4">
            <div className="bg-white rounded-full p-6 shadow-lg">
              <Bot size={48} className="text-blue-600" />
            </div>
          </div>
          <h1 className="text-4xl font-bold text-gray-800 mb-4">
            AI Voice Assistant
          </h1>
          <p className="text-xl text-gray-600 mb-8">
            Make instant voice calls powered by advanced AI technology
          </p>
        </div>

        <div className="bg-white rounded-xl shadow-xl p-8 mb-8">
          <button
            onClick={openModal}
            className="bg-blue-600 hover:bg-blue-700 text-white font-semibold py-4 px-8 rounded-full text-lg flex items-center space-x-3 mx-auto transition-all duration-200 transform hover:scale-105 shadow-lg"
          >
            <Phone size={24} />
            <span>Make a Call</span>
          </button>
        </div>

        <div className="grid md:grid-cols-3 gap-6 mb-8">
          <div className="bg-white rounded-lg p-6 shadow-md">
            <div className="text-blue-600 mb-3">
              <Phone size={32} className="mx-auto" />
            </div>
            <h3 className="font-semibold text-gray-800 mb-2">Instant Connection</h3>
            <p className="text-gray-600 text-sm">
              Enter any phone number and connect instantly to our AI assistant
            </p>
          </div>
          
          <div className="bg-white rounded-lg p-6 shadow-md">
            <div className="text-blue-600 mb-3">
              <Bot size={32} className="mx-auto" />
            </div>
            <h3 className="font-semibold text-gray-800 mb-2">Natural Conversation</h3>
            <p className="text-gray-600 text-sm">
              Have engaging conversations with our advanced AI voice assistant
            </p>
          </div>
          
          <div className="bg-white rounded-lg p-6 shadow-md">
            <div className="text-blue-600 mb-3">
              <Zap size={32} className="mx-auto" />
            </div>
            <h3 className="font-semibold text-gray-800 mb-2">Real-time Response</h3>
            <p className="text-gray-600 text-sm">
              Experience lightning-fast responses with minimal latency
            </p>
          </div>
        </div>

        <div className="text-center">
          <p className="text-gray-500 text-sm">
            Powered by AWS Nova Sonic • Twilio Voice • Modern Web Technologies
          </p>
        </div>

        <CallModal
          isOpen={isModalOpen}
          onClose={closeModal}
          callData={callData}
          isAudioActive={isAudioActive}
          onInitiateCall={initiateCall}
          onEndCall={endCall}
          onResetCall={resetCall}
          validatePhoneNumber={validatePhoneNumber}
        />
      </div>
    </div>
  );
}

export default App;