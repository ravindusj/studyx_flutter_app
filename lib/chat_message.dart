import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType {
  text,
  voiceNote,
  attachment,
}

class ChatMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String content;
  final MessageType type;
  final String? attachmentUrl;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.type,
    this.attachmentUrl,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'type': type.toString(),
      'attachmentUrl': attachmentUrl,
      'timestamp': timestamp,
    };
  }

  static ChatMessage fromMap(String id, Map<String, dynamic> map) {
    return ChatMessage(
      id: id,
      groupId: map['groupId'],
      senderId: map['senderId'],
      senderName: map['senderName'],
      content: map['content'],
      type: MessageType.values.firstWhere(
        (e) => e.toString() == map['type'],
      ),
      attachmentUrl: map['attachmentUrl'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}