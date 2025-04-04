import 'package:cloud_firestore/cloud_firestore.dart';

class ChatGroup {
  final String id;
  final String name;
  final String creatorId;
  final List<String> members;
  final String inviteCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatGroup({
    required this.id,
    required this.name,
    required this.creatorId,
    required this.members,
    required this.inviteCode,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'creatorId': creatorId,
      'members': members,
      'inviteCode': inviteCode,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  static ChatGroup fromMap(String id, Map<String, dynamic> map) {
    return ChatGroup(
      id: id,
      name: map['name'],
      creatorId: map['creatorId'],
      members: List<String>.from(map['members']),
      inviteCode: map['inviteCode'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  ChatGroup copyWith({
    String? id,
    String? name,
    String? creatorId,
    List<String>? members,
    String? inviteCode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      creatorId: creatorId ?? this.creatorId,
      members: members ?? this.members,
      inviteCode: inviteCode ?? this.inviteCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}