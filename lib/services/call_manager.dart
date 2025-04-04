import 'package:flutter/foundation.dart';
import '../webrtc_service.dart';
import 'call_service.dart';


class CallManager {
  
  static final CallManager _instance = CallManager._internal();
  factory CallManager() => _instance;
  CallManager._internal();
  
 
  WebRTCService? _webRTCService;
  final CallService _callService = CallService();
  

  bool _isInCall = false;
  String? _currentGroupId;
  String? _currentUserId;
  

  Function(String message)? onStatusUpdate;
  Function(String userId, dynamic stream)? onStreamUpdate;
  

  bool get isInCall => _isInCall;
  

  Future<WebRTCService> initializeCall({
    required String groupId, 
    required String userId,
    required String userName,
    Function(String message)? statusCallback,
    Function(String userId, dynamic stream)? streamCallback,
  }) async {
    if (_isInCall) {
      throw 'Already in a call. Leave current call before starting a new one.';
    }
    
 
    onStatusUpdate = statusCallback;
    onStreamUpdate = streamCallback;
    

    _webRTCService = WebRTCService(
      groupId: groupId,
      userId: userId,
    );
    
   
    _webRTCService!.onStatusUpdate = _handleStatusUpdate;
    _webRTCService!.onStreamUpdate = _handleStreamUpdate;
    

    try {
      await _webRTCService!.initializeWebRTC();
      
    
      await _callService.startCall(groupId, userId, userName);
      
    
      _isInCall = true;
      _currentGroupId = groupId;
      _currentUserId = userId;
      
   
      await _webRTCService!.joinCall();
      
      return _webRTCService!;
    } catch (e) {
    
      _handleStatusUpdate('Error initializing call: $e');
      await _cleanup();
      rethrow;
    }
  }
  

  Future<void> leaveCall() async {
    if (!_isInCall || _webRTCService == null) {
      _handleStatusUpdate('Not in a call');
      return;
    }
    
    try {
    
      if (_currentGroupId != null && _currentUserId != null) {
        await _callService.leaveCall(_currentGroupId!, _currentUserId!);
        
      
        final callStatus = await _callService.getActiveParticipants(_currentGroupId!);
        if (callStatus['participants'] == null || 
            (callStatus['participants'] as List).isEmpty) {
        
          await _callService.endCall(_currentGroupId!);
        }
      }
      
   
      await _webRTCService?.leaveCall();
    } catch (e) {
      _handleStatusUpdate('Error leaving call: $e');
    } finally {

      await _cleanup();
    }
  }
  
 
  void toggleMute(bool muted) {
    _webRTCService?.toggleMute(muted);
  }
  
  
  Future<void> _cleanup() async {
   
    final service = _webRTCService;
    _webRTCService = null;
    
    if (service != null) {
     
      service.onStatusUpdate = null;
      service.onStreamUpdate = null;
      
      
      try {
        await service.leaveCall();
        
       
        if (_currentGroupId != null && _currentUserId != null) {
          final callStatus = await _callService.getActiveParticipants(_currentGroupId!);
          if (callStatus['participants'] == null || 
              (callStatus['participants'] as List).isEmpty) {
            await _callService.endCall(_currentGroupId!);
          }
        }
      } catch (e) {
        debugPrint('Error during WebRTC cleanup: $e');
      }
    }
    
    
    _isInCall = false;
    _currentGroupId = null;
    _currentUserId = null;
  }
  
  
  void _handleStatusUpdate(String message) {
    debugPrint('Call Manager: $message');
    final callback = onStatusUpdate;
    if (callback != null) {
      callback(message);
    }
  }
  
 
  void _handleStreamUpdate(String userId, dynamic stream) {
    final callback = onStreamUpdate;
    if (callback != null) {
      callback(userId, stream);
    }
  }
}
