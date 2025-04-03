class Note {
  String? id;
  String title;
  String content;
  DateTime createdAt;
  DateTime updatedAt;
  String userID;

  Note({
    this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.userID,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'userID': userID,
    };
  }

  factory Note.fromMap(String id, Map<String, dynamic> map) {
    return Note(
      id: id,
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
      userID: map['userID'] ?? '',
    );
  }
  
  static DateTime _parseDateTime(dynamic timestamp) {
    if (timestamp is DateTime) {
      return timestamp;
    } else if (timestamp is String) {
      return DateTime.parse(timestamp);
    } else if (timestamp != null) {
      try {
        return timestamp.toDate();
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }
}
