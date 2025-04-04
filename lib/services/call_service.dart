import 'package:cloud_firestore/cloud_firestore.dart';

class CallService {
  final _firestore = FirebaseFirestore.instance;

  
  Future<String> _getUserName(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
  
        return data['name'] ?? data['displayName'] ?? 'Unknown';
      }
    } catch (e) {
      print('Error fetching user name: $e');
    }
    return 'Unknown';
  }

  Future<void> startCall(String groupId, String userId, String userName) async {
    try {
     
      if (userName == 'Unknown') {
        userName = await _getUserName(userId);
      }
      
     
      final doc = await _firestore.collection('group_calls').doc(groupId).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final List<dynamic> currentParticipants = data['participants'] ?? [];
        
      
        final alreadyJoined = currentParticipants.any(
          (p) => p['userId'] == userId
        );
        
        if (alreadyJoined) {
          
          await _updateParticipantTimestamp(groupId, userId);
          return;
        }
        
       
        await doc.reference.update({
          'isActive': true,
          'lastUpdated': FieldValue.serverTimestamp(),
          'participants': FieldValue.arrayUnion([{
            'userId': userId,
            'userName': userName,
            'joinedAt': DateTime.now().toIso8601String(),
          }]),
        });
      } else {
       
        await _firestore.collection('group_calls').doc(groupId).set({
          'isActive': true,
          'startedBy': userId,
          'startedAt': FieldValue.serverTimestamp(),
          'participants': [{
            'userId': userId,
            'userName': userName,
            'joinedAt': DateTime.now().toIso8601String(),
          }],
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error starting call: $e');
      throw 'Failed to start call: $e';
    }
  }

  Future<void> joinCall(String groupId, String userId, String userName) async {
    try {
      
      if (userName == 'Unknown') {
        userName = await _getUserName(userId);
      }
      
     
      final docRef = _firestore.collection('group_calls').doc(groupId);
      final doc = await docRef.get();
      
     
      if (!doc.exists) {
        return startCall(groupId, userId, userName);
      }
      
      final data = doc.data()!;
      final List<dynamic> currentParticipants = data['participants'] ?? [];
      
     
      final alreadyJoined = currentParticipants.any(
        (p) => p['userId'] == userId
      );
      
      if (alreadyJoined) {
       
        await _updateParticipantTimestamp(groupId, userId);
        return;
      }
      
     
      await docRef.update({
        'isActive': true,
        'participants': FieldValue.arrayUnion([{
          'userId': userId,
          'userName': userName,
          'joinedAt': DateTime.now().toIso8601String(),
        }]),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error joining call: $e');
      throw 'Failed to join call: $e';
    }
  }
  
  
  Future<void> _updateParticipantTimestamp(String groupId, String userId) async {
    try {
      final docRef = _firestore.collection('group_calls').doc(groupId);
      final doc = await docRef.get();
      
      if (!doc.exists) return;
      
      final data = doc.data()!;
      final List<Map<String, dynamic>> participants = 
          List<Map<String, dynamic>>.from(data['participants'] ?? []);
      
     
      for (var i = 0; i < participants.length; i++) {
        if (participants[i]['userId'] == userId) {
          participants[i] = {
            ...participants[i],
            'lastActive': DateTime.now().toIso8601String(),
          };
          break;
        }
      }
      
      await docRef.update({
        'participants': participants,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating participant timestamp: $e');
    }
  }

  Future<void> leaveCall(String groupId, String userId) async {
    try {
      final doc = await _firestore.collection('group_calls').doc(groupId).get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final participants = List<Map<String, dynamic>>.from(data['participants'] ?? []);
      
     
      participants.removeWhere((p) => p['userId'] == userId);
      
     
      final now = FieldValue.serverTimestamp();
      
      if (participants.isEmpty) {
      
        await doc.reference.update({
          'isActive': false,
          'participants': [],
          'endedAt': now,
          'lastUpdated': now,
          'lastUserLeft': userId,  
        });
      } else {
        await doc.reference.update({
          'participants': participants,
          'lastUpdated': now,
          'lastUserLeft': userId, 
        });
      }
    } catch (e) {
      print('Error leaving call: $e');
    }
  }

 
  Future<void> endCall(String groupId) async {
    try {
      final doc = _firestore.collection('group_calls').doc(groupId);
      await doc.update({
        'isActive': false,
        'participants': [],
        'endedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error ending call: $e');
    }
  }

  Stream<DocumentSnapshot> getCallStatus(String groupId) {
    
    _initializeCallDocument(groupId);
    
    
    return _firestore.collection('group_calls').doc(groupId).snapshots();
  }

  Future<void> _initializeCallDocument(String groupId) async {
    try {
      final docRef = _firestore.collection('group_calls').doc(groupId);
     
      if (!(await docRef.get()).exists) {
        await docRef.set({
          'isActive': false,
          'participants': [],
          'lastUpdated': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error initializing call document: $e');
    }
  }
  
  
  Future<Map<String, dynamic>> getActiveParticipants(String groupId) async {
    try {
      final doc = await _firestore.collection('group_calls').doc(groupId).get();
      if (!doc.exists) {
        return {'error': 'No active call'};
      }
      
      final data = doc.data()!;
      return {
        'isActive': data['isActive'] ?? false,
        'participants': data['participants'] ?? [],
      };
    } catch (e) {
      print('Error getting participants: $e');
      return {'error': e.toString()};
    }
  }
  
  
  Future<void> cleanupStaleCall(String groupId) async {
    try {
      final doc = await _firestore.collection('group_calls').doc(groupId).get();
      if (!doc.exists) return;
      
      final data = doc.data()!;
      final bool isActive = data['isActive'] ?? false;
      final List participants = data['participants'] ?? [];
      
     
      if (isActive && participants.isEmpty) {
        print('Found stale call in group $groupId. Cleaning up...');
        await endCall(groupId);
      }
    } catch (e) {
      print('Error cleaning up stale call: $e');
    }
  }
}
