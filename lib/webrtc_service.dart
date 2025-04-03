import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class WebRTCService {
  final String groupId;
  final String userId;
  Map<String, RTCPeerConnection> peerConnections = {};
  Map<String, MediaStream> remoteStreams = {};
  MediaStream? localStream;
  StreamSubscription? _signalSubscription;
  bool _isInitialized = false;
  
  final _signalCollection = FirebaseFirestore.instance.collection('signals');
  
  Function(String userId, MediaStream? stream)? onStreamUpdate;
  
  Function(String message)? onStatusUpdate;
  
  final Map<String, List<RTCIceCandidate>> _pendingCandidates = {};
  
  final Map<String, DateTime> _connectionStartTimes = {};
  
  final Map<String, Timer> _connectionQualityTimers = {};
  bool _useAcceleratedConnection = false;
  
  bool _hasShownIndexWarning = false;
  
  final Map<String, String> _peerConnectionStates = {};
  
  WebRTCService({required this.groupId, required this.userId});

  Future<void> initializeWebRTC() async {
    if (_isInitialized) {
      _handleStatusUpdate("WebRTC already initialized");
      return;
    }
    
    try {
      _handleStatusUpdate("Requesting microphone access...");
      
      final Map<String, dynamic> mediaConstraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          'channelCount': 1,
          'sampleRate': 16000,
        },
        'video': false
      };

      _handleStatusUpdate("Getting user media...");
      localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      
      if (localStream == null) {
        _handleStatusUpdate("Failed to get local stream");
        throw "Failed to get local stream";
      }
      
      _handleStatusUpdate("Audio stream obtained successfully");

      await _signalSubscription?.cancel();
      
      _handleStatusUpdate("Setting up signal listeners...");
      
      await _setupSignalingListener();

      _isInitialized = true;
      _handleStatusUpdate("WebRTC initialized successfully");
      
      _cleanupOldSignals();
      
    } catch (e) {
      _handleStatusUpdate("Error initializing WebRTC: $e");
      throw "Error initializing WebRTC: $e";
    }
  }

  Future<void> _setupSignalingListener() async {
    try {
      final twoMinutesAgo = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(minutes: 2))
      );
      
      _signalSubscription = _signalCollection
          .where('groupId', isEqualTo: groupId)
          .where('timestamp', isGreaterThan: twoMinutesAgo)
          .orderBy('timestamp', descending: false)
          .snapshots()
          .listen((snapshot) {
            _processBatchSignalingMessages(snapshot);
          }, onError: (e) {
            final errorString = e.toString().toLowerCase();
            if (errorString.contains('index') && errorString.contains('requires')) {
              _handleIndexError();
              _setupSimpleSignalingListener();
            } else {
              _handleStatusUpdate("Error in signal subscription: $e");
            }
          });
    } catch (e) {
      _handleStatusUpdate("Error setting up signaling listener: $e");
      _setupSimpleSignalingListener();
    }
  }
  
  void _handleIndexError() {
    if (!_hasShownIndexWarning) {
      _hasShownIndexWarning = true;
      _handleStatusUpdate("""
INDEX REQUIRED: This app needs a Firebase index for optimal performance.
Please create the index by visiting the link shown in the error message, or
contact the app administrator. Using a simpler query as fallback.""");
    }
  }
  
  void _setupSimpleSignalingListener() {
    try {
      _handleStatusUpdate("Setting up simple signal listener (fallback)...");
      
      _signalSubscription = _signalCollection
          .where('groupId', isEqualTo: groupId)
          .snapshots()
          .listen((snapshot) {
            _processBatchSignalingMessages(snapshot);
          }, onError: (e) {
            _handleStatusUpdate("Error in fallback signal subscription: $e");
          });
    } catch (e) {
      _handleStatusUpdate("Failed to set up fallback signaling: $e");
    }
  }
  
  void _processBatchSignalingMessages(QuerySnapshot snapshot) {
    final candidateMessages = <Map<String, dynamic>>[];
    final offerMessages = <Map<String, dynamic>>[];
    final answerMessages = <Map<String, dynamic>>[];
    final joinMessages = <Map<String, dynamic>>[];
    final leaveMessages = <Map<String, dynamic>>[];
    
    for (var change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added) {
        final data = change.doc.data() as Map<String, dynamic>;
        
        if (data['from'] == userId) continue;
        
        final String? to = data['to'];
        if (to != null && to != userId) continue;
        
        final type = data['type'];
        
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final messageTime = timestamp.toDate();
          final twoMinutesAgo = DateTime.now().subtract(const Duration(minutes: 2));
          if (messageTime.isBefore(twoMinutesAgo)) {
            continue;
          }
        }
        
        switch (type) {
          case 'candidate':
            candidateMessages.add(data);
            break;
          case 'offer':
            offerMessages.add(data);
            break;
          case 'answer':
            answerMessages.add(data);
            break;
          case 'join':
            joinMessages.add(data);
            break;
          case 'leave':
            leaveMessages.add(data);
            break;
        }
      }
    }
    
    for (var msg in joinMessages) {
      handleSignalingMessage(msg);
    }
    
    for (var msg in offerMessages) {
      handleSignalingMessage(msg);
    }
    
    for (var msg in answerMessages) {
      handleSignalingMessage(msg);
    }
    
    for (var msg in candidateMessages) {
      handleSignalingMessage(msg);
    }
    
    for (var msg in leaveMessages) {
      handleSignalingMessage(msg);
    }
  }

  Future<void> _cleanupOldSignals() async {
    try {
      final cutoffTime = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(minutes: 10))
      );
      
      try {
        final oldSignals = await _signalCollection
            .where('groupId', isEqualTo: groupId)
            .where('timestamp', isLessThan: cutoffTime)
            .get();
        
        await _deleteOldSignals(oldSignals.docs);
      } catch (e) {
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('index') && errorString.contains('requires')) {
          _handleIndexError();
          final allGroupSignals = await _signalCollection
              .where('groupId', isEqualTo: groupId)
              .get();
          
          final oldDocs = allGroupSignals.docs.where((doc) {
            final data = doc.data();
            final timestamp = data['timestamp'] as Timestamp?;
            if (timestamp == null) return true;
            return timestamp.toDate().isBefore(cutoffTime.toDate());
          }).toList();
          
          await _deleteOldSignals(oldDocs);
        } else {
          _handleStatusUpdate("Error cleaning up old signals: $e");
        }
      }
    } catch (e) {
      _handleStatusUpdate("Error cleaning up old signals: $e");
    }
  }
  
  Future<void> _deleteOldSignals(List<QueryDocumentSnapshot> docs) async {
    if (docs.isNotEmpty) {
      _handleStatusUpdate("Cleaning up ${docs.length} old signal messages");
      
      final batch = FirebaseFirestore.instance.batch();
      int count = 0;
      
      for (var doc in docs) {
        batch.delete(doc.reference);
        count++;
        
        if (count >= 500) {
          await batch.commit();
          count = 0;
        }
      }
      
      if (count > 0) {
        await batch.commit();
      }
    }
  }

  Future<RTCPeerConnection> _createPeerConnection(String remoteUserId) async {
    _handleStatusUpdate("Creating peer connection for $remoteUserId...");
    
    _connectionStartTimes[remoteUserId] = DateTime.now();
    
    final Map<String, dynamic> configuration = {
      'iceServers': [
        {
          'urls': [
            'stun:stun1.l.google.com:19302',
            'stun:stun2.l.google.com:19302',
            'stun:stun.l.google.com:19302',
            'stun:stun3.l.google.com:19302',
            'stun:stun4.l.google.com:19302'
          ]
        },
        {
          'urls': [
            'turn:relay.metered.ca:80',
          ],
          'username': 'b984a7f67cf7d5fb21b7c79e',
          'credential': 'kdfWK/DXzGVN0w92'
        },
        {
          'urls': [
            'turn:relay.metered.ca:443',
          ],
          'username': 'b984a7f67cf7d5fb21b7c79e',
          'credential': 'kdfWK/DXzGVN0w92'
        },
        {
          'urls': [
            'turn:relay.metered.ca:443?transport=tcp',
          ],
          'username': 'b984a7f67cf7d5fb21b7c79e',
          'credential': 'kdfWK/DXzGVN0w92'
        }
      ],
      'sdpSemantics': 'unified-plan',
      'iceTransportPolicy': _useAcceleratedConnection ? 'relay' : 'all',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
      'iceCandidatePoolSize': 2
    };

    final pc = await createPeerConnection(configuration);
    
    pc.onIceConnectionState = (state) {
      _handleStatusUpdate("ICE connection state with $remoteUserId: $state");
      
      final stateStr = state.toString()
        .replaceAll('RTCIceConnectionState.RTCIceConnectionState', '');
      _peerConnectionStates[remoteUserId] = stateStr;
      
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          final startTime = _connectionStartTimes[remoteUserId];
          if (startTime != null) {
            final connectionTimeMs = DateTime.now().difference(startTime).inMilliseconds;
            _handleStatusUpdate("Connected to $remoteUserId in $connectionTimeMs ms");
          }
          
          _safelyUpdateStreamStatus(remoteUserId, remoteStreams[remoteUserId]);
          
          _startConnectionQualityMonitoring(remoteUserId, pc);
          break;
          
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _handleStatusUpdate("Connection failed with $remoteUserId, attempting to reconnect");
          _fastReconnectPeer(remoteUserId);
          break;
          
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          _handleStatusUpdate("Connection disconnected with $remoteUserId, waiting for recovery...");
          Future.delayed(const Duration(seconds: 3), () {
            if (peerConnections[remoteUserId]?.iceConnectionState == 
                RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
              _reconnectPeer(remoteUserId);
            }
          });
          break;
          
        default:
          break;
      }
    };
    
    pc.onConnectionState = (state) {
      _handleStatusUpdate("Connection state with $remoteUserId: $state");
      
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _handleStatusUpdate("Successfully connected to $remoteUserId");
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _handleStatusUpdate("Connection failed with $remoteUserId, attempting to reconnect");
        _fastReconnectPeer(remoteUserId);
      }
    };
    
    pc.onTrack = (RTCTrackEvent event) {
      _handleStatusUpdate("Received track from $remoteUserId: ${event.track.kind}");
      
      if (event.streams.isNotEmpty) {
        final stream = event.streams[0];
        remoteStreams[remoteUserId] = stream;
        
        _handleStatusUpdate("Notifying UI about remote stream from $remoteUserId");
        _safelyUpdateStreamStatus(remoteUserId, stream);
      }
    };

    if (localStream != null) {
      final audioTracks = localStream!.getAudioTracks();
      
      if (audioTracks.isNotEmpty) {
        _handleStatusUpdate("Adding ${audioTracks.length} audio track(s) to connection");
        
        for (var track in audioTracks) {
          _handleStatusUpdate("Adding track: ${track.id} of kind ${track.kind}");
          pc.addTrack(track, localStream!);
        }
      } else {
        _handleStatusUpdate("No audio tracks available to add!");
      }
    } else {
      _handleStatusUpdate("No local stream available!");
    }

    final pendingLocalCandidates = <RTCIceCandidate>[];
    Timer? candidateBatchTimer;
    
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      pendingLocalCandidates.add(candidate);
      
      if (candidate.candidate?.toLowerCase().contains('host') ?? false) {
        _sendIceCandidateSignal(remoteUserId, candidate);
      } else {
        candidateBatchTimer?.cancel();
        candidateBatchTimer = Timer(const Duration(milliseconds: 200), () {
          if (pendingLocalCandidates.isNotEmpty) {
            _handleStatusUpdate("Sending ${pendingLocalCandidates.length} batched ICE candidates to $remoteUserId");
            
            for (var batchCandidate in pendingLocalCandidates) {
              _sendIceCandidateSignal(remoteUserId, batchCandidate);
            }
            
            pendingLocalCandidates.clear();
          }
        });
      }
    };

    if (_pendingCandidates.containsKey(remoteUserId)) {
      _processPendingCandidates(remoteUserId, pc);
    }

    return pc;
  }
  
  void _sendIceCandidateSignal(String remoteUserId, RTCIceCandidate candidate) {
    _sendSignalingMessage({
      'type': 'candidate',
      'candidate': candidate.toMap(),
      'from': userId,
      'to': remoteUserId,
      'groupId': groupId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _startConnectionQualityMonitoring(String remoteUserId, RTCPeerConnection pc) {
    _connectionQualityTimers[remoteUserId]?.cancel();
    
    _connectionQualityTimers[remoteUserId] = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!peerConnections.containsKey(remoteUserId)) {
        timer.cancel();
        return;
      }
      
      pc.getStats().then((stats) {
        var packetsLost = 0;
        var packetsReceived = 0;
        var audioLevel = 0.0;
        var roundTripTimeMs = 0;
        
        for (var stat in stats) {
          final values = stat.values;
          
          if (values['type'] == 'inbound-rtp' && values['kind'] == 'audio') {
            packetsLost = (values['packetsLost'] as num?)?.toInt() ?? 0;
            packetsReceived = (values['packetsReceived'] as num?)?.toInt() ?? 0;
          }
          
          if (values['type'] == 'track' && values['kind'] == 'audio') {
            audioLevel = (values['audioLevel'] as num?)?.toDouble() ?? 0.0;
          }
          
          if (values['type'] == 'candidate-pair' && values['state'] == 'succeeded') {
            roundTripTimeMs = (values['currentRoundTripTime'] as num?)?.toInt() ?? 0;
          }
        }
        
        final totalExpected = packetsReceived + packetsLost;
        var lossPercentage = 0.0;
        if (totalExpected > 0) {
          lossPercentage = (packetsLost / totalExpected) * 100;
        }
        
        if (lossPercentage > 5 || roundTripTimeMs > 300) {
          _handleStatusUpdate("Connection quality with $remoteUserId: " "packet loss ${lossPercentage.toStringAsFixed(1)}%, " +
                             "RTT ${roundTripTimeMs}ms");
          
          if (lossPercentage > 20 || roundTripTimeMs > 1000) {
            _handleStatusUpdate("Poor connection quality with $remoteUserId, attempting to reconnect");
            _reconnectPeer(remoteUserId);
          }
        }
      }).catchError((e) {
        _handleStatusUpdate("Error getting connection stats: $e");
      });
    });
  }
  
  Future<void> _fastReconnectPeer(String remoteUserId) async {
    try {
      _handleStatusUpdate("Fast reconnecting with $remoteUserId...");
      
      final oldPc = peerConnections[remoteUserId];
      if (oldPc == null) {
        _handleStatusUpdate("No connection to reconnect for $remoteUserId");
        return;
      }
      
      try {
        final offerOptions = {
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': false,
          'iceRestart': true
        };
        
        final offer = await oldPc.createOffer(offerOptions);
        await oldPc.setLocalDescription(offer);
        
        _handleStatusUpdate("Sent ICE restart offer to $remoteUserId");
        await _sendSignalingMessage({
          'type': 'offer',
          'from': userId,
          'to': remoteUserId,
          'groupId': groupId,
          'sdp': offer.toMap(),
          'iceRestart': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        Future.delayed(const Duration(seconds: 5), () {
          if (peerConnections[remoteUserId]?.iceConnectionState == 
              RTCIceConnectionState.RTCIceConnectionStateFailed) {
            _handleStatusUpdate("ICE restart failed, trying full reconnection");
            _reconnectPeer(remoteUserId);
          }
        });
      } catch (e) {
        _handleStatusUpdate("Error during ICE restart: $e");
        _reconnectPeer(remoteUserId);
      }
    } catch (e) {
      _handleStatusUpdate("Error during fast reconnection: $e");
    }
  }

  Future<void> _reconnectPeer(String remoteUserId) async {
    try {
      _handleStatusUpdate("Attempting to reconnect with $remoteUserId...");
      
      if (remoteStreams.containsKey(remoteUserId)) {
        _handleStatusUpdate("Detected active stream, delaying reconnection");
        await Future.delayed(const Duration(seconds: 2));
      }
      
      final oldPc = peerConnections[remoteUserId];
      if (oldPc != null) {
        oldPc.onIceCandidate = null;
        oldPc.onIceConnectionState = null;
        oldPc.onConnectionState = null;
        oldPc.onTrack = null;
        
        await oldPc.close();
      }
      
      _connectionQualityTimers[remoteUserId]?.cancel();
      _connectionQualityTimers.remove(remoteUserId);
      
      peerConnections.remove(remoteUserId);
      final oldStream = remoteStreams.remove(remoteUserId);
      
      if (oldStream != null) {
        _safelyUpdateStreamStatus(remoteUserId, null);
      }
      
      final newPc = await _createPeerConnection(remoteUserId);
      peerConnections[remoteUserId] = newPc;
      
      final offerOptions = {
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false
      };
      
      final offer = await newPc.createOffer(offerOptions);
      await newPc.setLocalDescription(offer);
      
      _handleStatusUpdate("Sending new connection offer to $remoteUserId");
      await _sendSignalingMessage({
        'type': 'offer',
        'from': userId,
        'to': remoteUserId,
        'groupId': groupId,
        'sdp': offer.toMap(),
        'isReconnect': true,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _handleStatusUpdate("Error reconnecting to $remoteUserId: $e");
    }
  }

  Future<void> _processPendingCandidates(String peerId, [RTCPeerConnection? pc]) async {
    final candidates = _pendingCandidates[peerId];
    if (candidates == null || candidates.isEmpty) return;
    
    final connection = pc ?? peerConnections[peerId];
    if (connection == null) return;
    
    _handleStatusUpdate("Processing ${candidates.length} pending ICE candidates for $peerId");
    
    final hostCandidates = candidates.where(
      (c) => c.candidate?.toLowerCase().contains('host') ?? false
    ).toList();
    
    final srflxCandidates = candidates.where(
      (c) => c.candidate?.toLowerCase().contains('srflx') ?? false
    ).toList();
    
    final relayCandidates = candidates.where(
      (c) => c.candidate?.toLowerCase().contains('relay') ?? false
    ).toList();
    
    final otherCandidates = candidates.where((c) => 
      !(c.candidate?.toLowerCase().contains('host') ?? false) &&
      !(c.candidate?.toLowerCase().contains('srflx') ?? false) &&
      !(c.candidate?.toLowerCase().contains('relay') ?? false)
    ).toList();
    
    for (var candidate in [...hostCandidates, ...srflxCandidates, ...relayCandidates, ...otherCandidates]) {
      try {
        await connection.addCandidate(candidate);
      } catch (e) {
        _handleStatusUpdate("Error adding pending ICE candidate: $e");
      }
    }
    
    _pendingCandidates.remove(peerId);
  }

  Future<void> joinCall() async {
    try {
      _handleStatusUpdate("Joining call...");
      
      if (!_isInitialized) {
        await initializeWebRTC();
      }

      _safelyUpdateStreamStatus(userId, localStream);
      
      await _findExistingParticipants();
      
      _handleStatusUpdate("Announcing presence to group...");
      await _sendSignalingMessage({
        'type': 'join',
        'from': userId,
        'groupId': groupId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      _handleStatusUpdate("Join call process completed");
      
      Timer.periodic(const Duration(minutes: 5), (timer) {
        if (!_isInitialized) {
          timer.cancel();
          return;
        }
        _refreshConnections();
      });
      
    } catch (e) {
      _handleStatusUpdate("Error joining call: $e");
      rethrow;
    }
  }

  Future<void> _refreshConnections() async {
    if (!_isInitialized) return;
    
    _handleStatusUpdate("Performing periodic connection check");
    
    for (var entry in peerConnections.entries) {
      final peerId = entry.key;
      final pc = entry.value;
      
      if (pc.iceConnectionState == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          pc.iceConnectionState == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _handleStatusUpdate("Found stale connection to $peerId during refresh check");
        await _reconnectPeer(peerId);
      }
    }
    
    try {
      await _findExistingParticipants();
    } catch (e) {
      _handleStatusUpdate("Error refreshing participants: $e");
    }
  }

  Future<void> _findExistingParticipants() async {
    try {
      _handleStatusUpdate("Looking for existing participants...");
      
      final callDoc = await FirebaseFirestore.instance
          .collection('group_calls')
          .doc(groupId)
          .get();
          
      if (!callDoc.exists) {
        _handleStatusUpdate("No active call found");
        return;
      }
      
      final callData = callDoc.data() as Map<String, dynamic>;
      final participants = List<Map<String, dynamic>>.from(callData['participants'] ?? []);
      
      final otherParticipants = participants.where((p) => p['userId'] != userId).toList();
      
      if (otherParticipants.isEmpty) {
        _handleStatusUpdate("No other participants found");
        return;
      }
      
      _handleStatusUpdate("Found ${otherParticipants.length} other participants");
      
      for (var i = 0; i < otherParticipants.length; i++) {
        final participant = otherParticipants[i];
        final peerId = participant['userId'] as String;
        
        if (peerConnections.containsKey(peerId) &&
            peerConnections[peerId]!.iceConnectionState == 
            RTCIceConnectionState.RTCIceConnectionStateConnected) {
          _handleStatusUpdate("Already connected to $peerId");
          continue;
        }
        
        _handleStatusUpdate("Creating connection to existing participant: $peerId");
        final pc = await _createPeerConnection(peerId);
        peerConnections[peerId] = pc;
        
        final offerOptions = {
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': false
        };
        
        final offer = await pc.createOffer(offerOptions);
        await pc.setLocalDescription(offer);
        
        await _sendSignalingMessage({
          'type': 'offer',
          'from': userId,
          'to': peerId,
          'groupId': groupId,
          'sdp': offer.toMap(),
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
    } catch (e) {
      _handleStatusUpdate("Error finding participants: $e");
    }
  }

  Future<void> leaveCall() async {
    try {
      _handleStatusUpdate("Leaving call...");
      
      await _signalSubscription?.cancel();
      _signalSubscription = null;
      
      try {
        await _sendSignalingMessage({
          'type': 'leave',
          'from': userId,
          'groupId': groupId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('Error sending leave message: $e');
      }

      for (var peerId in peerConnections.keys.toList()) {
        try {
          final pc = peerConnections[peerId];
          if (pc != null) {
            await pc.close();
          }
        } catch (e) {
          print('Error closing connection to $peerId: $e');
        }
      }
      peerConnections.clear();
      
      remoteStreams.clear();
      
      if (localStream != null) {
        try {
          for (var track in localStream!.getTracks()) {
            track.stop();
          }
        } catch (e) {
          print('Error stopping local tracks: $e');
        }
        localStream = null;
      }
      
      _isInitialized = false;
      _handleStatusUpdate("Successfully left call");
      
    } catch (e) {
      print('Error in leaveCall: $e');
      throw 'Failed to leave call cleanly: $e';
    }
  }

  Future<void> handleSignalingMessage(Map<String, dynamic> message) async {
    try {
      final type = message['type'];
      final from = message['from'];
      
      switch (type) {
        case 'join':
          _handleStatusUpdate("$from is joining the call. Creating connection...");
          
          final pc = await _createPeerConnection(from);
          peerConnections[from] = pc;
          
          final offerOptions = {
            'offerToReceiveAudio': true,
            'offerToReceiveVideo': false
          };
          
          final offer = await pc.createOffer(offerOptions);
          await pc.setLocalDescription(offer);
          
          _handleStatusUpdate("Sending offer to $from");
          await _sendSignalingMessage({
            'type': 'offer',
            'from': userId,
            'to': from,
            'groupId': groupId,
            'sdp': offer.toMap(),
            'timestamp': FieldValue.serverTimestamp(),
          });
          break;
          
        case 'offer':
          if (message['to'] == userId) {
            _handleStatusUpdate("Received offer from $from");
            
            var pc = peerConnections[from];
            if (pc == null) {
              pc = await _createPeerConnection(from);
              peerConnections[from] = pc;
            }
            
            final connectionState = pc.connectionState;
            _handleStatusUpdate("Connection state before setting offer: $connectionState");
            
            final rtcSessionDescription = RTCSessionDescription(
              message['sdp']['sdp'],
              message['sdp']['type'],
            );
            
            try {
              await pc.setRemoteDescription(rtcSessionDescription);
              _handleStatusUpdate("Set remote description from $from");
              
              final answerOptions = {
                'offerToReceiveAudio': true,
                'offerToReceiveVideo': false
              };
              
              final answer = await pc.createAnswer(answerOptions);
              await pc.setLocalDescription(answer);
              
              _handleStatusUpdate("Sending answer to $from");
              await _sendSignalingMessage({
                'type': 'answer',
                'from': userId,
                'to': from,
                'groupId': groupId,
                'sdp': answer.toMap(),
                'timestamp': FieldValue.serverTimestamp(),
              });
              
              _safelyUpdateStreamStatus(from, null);
            } catch (e) {
              _handleStatusUpdate("Error setting remote offer description: $e");
              _reconnectPeer(from);
            }
          }
          break;
          
        case 'answer':
          if (message['to'] == userId) {
            _handleStatusUpdate("Received answer from $from");
            
            final pc = peerConnections[from];
            if (pc != null) {
              final signalingState = pc.signalingState;
              _handleStatusUpdate("Signaling state before setting answer: $signalingState");
              
              if (signalingState != 'stable') {
                try {
                  final rtcSessionDescription = RTCSessionDescription(
                    message['sdp']['sdp'],
                    message['sdp']['type'],
                  );
                  
                  await pc.setRemoteDescription(rtcSessionDescription);
                  _handleStatusUpdate("Set remote description from answer by $from");
                  
                  _safelyUpdateStreamStatus(from, null);
                } catch (e) {
                  _handleStatusUpdate("Error setting remote answer description: $e");
                  _reconnectPeer(from);
                }
              } else {
                _handleStatusUpdate("Ignoring answer - connection not in correct state");
              }
            } else {
              _handleStatusUpdate("Warning: Received answer but no connection exists for $from");
            }
          }
          break;
          
        case 'candidate':
          if (message['to'] == userId) {
            final pc = peerConnections[from];
            
            if (pc != null) {
              if (pc.signalingState != 'closed') {
                final candidateMap = message['candidate'];
                final candidate = RTCIceCandidate(
                  candidateMap['candidate'],
                  candidateMap['sdpMid'],
                  candidateMap['sdpMLineIndex'],
                );
                
                _handleStatusUpdate("Adding ICE candidate from $from");
                try {
                  await pc.addCandidate(candidate);
                } catch (e) {
                  _handleStatusUpdate("Error adding ICE candidate: $e");
                }
              } else {
                _handleStatusUpdate("Ignoring ICE candidate - connection closed");
              }
            } else {
              _handleStatusUpdate("Received candidate but no connection exists yet. Creating one for $from");
              final pc = await _createPeerConnection(from);
              peerConnections[from] = pc;
              
              if (pc.signalingState != 'closed') {
                final candidateMap = message['candidate'];
                final candidate = RTCIceCandidate(
                  candidateMap['candidate'],
                  candidateMap['sdpMid'],
                  candidateMap['sdpMLineIndex'],
                );
                
                try {
                  await pc.addCandidate(candidate);
                } catch (e) {
                  _handleStatusUpdate("Error adding ICE candidate to new connection: $e");
                }
              }
              
              _safelyUpdateStreamStatus(from, null);
            }
          }
          break;
          
        case 'leave':
          _handleStatusUpdate("$from is leaving the call");
          
          final pc = peerConnections.remove(from);
          if (pc != null) {
            await pc.close();
          }
          
          remoteStreams.remove(from);
          _safelyUpdateStreamStatus(from, null);
          break;
      }
    } catch (e) {
      _handleStatusUpdate("Error handling signaling message: $e");
    }
  }

  Future<void> _sendSignalingMessage(Map<String, dynamic> message) async {
    try {
      await _signalCollection.add(message);
    } catch (e) {
      _handleStatusUpdate("Error sending signaling message: $e");
    }
  }

  void toggleMute(bool muted) {
    if (localStream == null) return;
    
    for (var track in localStream!.getAudioTracks()) {
      track.enabled = !muted;
    }
    
    _handleStatusUpdate(muted ? "Microphone muted" : "Microphone unmuted");
  }
  
  void setVolume(double volume) {
    _handleStatusUpdate("Changing volume to $volume");
  }

  void _handleStatusUpdate(String message) {
    print("WebRTC Status: $message");
    
    final callback = onStatusUpdate;
    if (callback != null) {
      callback(message);
    }
  }

  void _safelyUpdateStreamStatus(String userId, dynamic stream) {
    final callback = onStreamUpdate;
    if (callback != null) {
      callback(userId, stream);
    }
  }
  
  String? getConnectionState(String userId) {
    try {
      if (_peerConnectionStates.containsKey(userId)) {
        return _peerConnectionStates[userId];
      }
      
      final pc = peerConnections[userId];
      if (pc != null) {
        return pc.iceConnectionState.toString()
          .replaceAll('RTCIceConnectionState.RTCIceConnectionState', '');
      }
    } catch (e) {
      _handleStatusUpdate("Error getting connection state: $e");
    }
    
    return null;
  }
  
  bool hasPeerConnection(String userId) {
    return peerConnections.containsKey(userId);
  }
  
  bool hasRemoteStream(String userId) {
    return remoteStreams.containsKey(userId);
  }
  
  Future<void> reconnectPeer(String userId) async {
    try {
      if (!peerConnections.containsKey(userId)) {
        _handleStatusUpdate("No connection to reconnect for $userId, creating new one");
        final pc = await _createPeerConnection(userId);
        peerConnections[userId] = pc;
        
        final offerOptions = {
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': false
        };
        
        final offer = await pc.createOffer(offerOptions);
        await pc.setLocalDescription(offer);
        
        await _sendSignalingMessage({
          'type': 'offer',
          'from': this.userId,
          'to': userId,
          'groupId': groupId,
          'sdp': offer.toMap(),
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        await _reconnectPeer(userId);
      }
    } catch (e) {
      _handleStatusUpdate("Error in public reconnectPeer: $e");
    }
  }
}