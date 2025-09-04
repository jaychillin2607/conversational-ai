export type CallState = 
  | 'idle'
  | 'dialing'  
  | 'connecting'
  | 'connected'
  | 'ended'
  | 'error';

export interface CallData {
  callId: string;
  phoneNumber: string;
  status: CallState;
  startTime?: Date;
  endTime?: Date;
  error?: string;
}

export interface CallResponse {
  call_id: string;
  status: string;
  message: string;
}

export interface CallStatusResponse {
  phone_number: string;
  twilio_sid: string;
  status: string;
}