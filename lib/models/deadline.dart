import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';


enum DeadlinePriority {
  low,
  medium,
  high,
  critical
}


enum DeadlineStatus {
  pending,
  inProgress,
  completed,
  overdue
}


extension DeadlinePriorityExtension on DeadlinePriority {
  String get name {
    switch (this) {
      case DeadlinePriority.low:
        return 'Low';
      case DeadlinePriority.medium:
        return 'Medium';
      case DeadlinePriority.high:
        return 'High';
      case DeadlinePriority.critical:
        return 'Critical';
    }
  }
  
  Color get color {
    switch (this) {
      case DeadlinePriority.low:
        return Colors.green;
      case DeadlinePriority.medium:
        return Colors.blue;
      case DeadlinePriority.high:
        return Colors.orange;
      case DeadlinePriority.critical:
        return Colors.red;
    }
  }
  
  int get value {
    switch (this) {
      case DeadlinePriority.low:
        return 0;
      case DeadlinePriority.medium:
        return 1;
      case DeadlinePriority.high:
        return 2;
      case DeadlinePriority.critical:
        return 3;
    }
  }
  
  // Get an icon for the priority
  IconData get icon {
    switch (this) {
      case DeadlinePriority.low:
        return Icons.arrow_downward;
      case DeadlinePriority.medium:
        return Icons.remove;
      case DeadlinePriority.high:
        return Icons.arrow_upward;
      case DeadlinePriority.critical:
        return Icons.priority_high;
    }
  }
}


extension DeadlineStatusExtension on DeadlineStatus {
  String get name {
    switch (this) {
      case DeadlineStatus.pending:
        return 'Pending';
      case DeadlineStatus.inProgress:
        return 'In Progress';
      case DeadlineStatus.completed:
        return 'Completed';
      case DeadlineStatus.overdue:
        return 'Overdue';
    }
  }
  
  Color get color {
    switch (this) {
      case DeadlineStatus.pending:
        return Colors.grey;
      case DeadlineStatus.inProgress:
        return Colors.blue;
      case DeadlineStatus.completed:
        return Colors.green;
      case DeadlineStatus.overdue:
        return Colors.red;
    }
  }
  
  IconData get icon {
    switch (this) {
      case DeadlineStatus.pending:
        return Icons.pending_outlined;
      case DeadlineStatus.inProgress:
        return Icons.running_with_errors;
      case DeadlineStatus.completed:
        return Icons.check_circle_outline;
      case DeadlineStatus.overdue:
        return Icons.error_outline;
    }
  }
}

class Deadline {
  String id;
  String title;
  String? description;
  DateTime dueDate;
  DeadlinePriority priority;
  DeadlineStatus status;
  List<String> tags;
  String? courseId;
  String userId;
  DateTime createdAt;
  DateTime? completedAt;
  bool hasReminder;
  List<DateTime> reminderTimes;

  Deadline({
    required this.id,
    required this.title,
    this.description,
    required this.dueDate,
    required this.priority,
    required this.status,
    this.tags = const [],
    this.courseId,
    required this.userId,
    required this.createdAt,
    this.completedAt,
    this.hasReminder = true,
    this.reminderTimes = const [],
  });

 
  int get daysRemaining {
    final now = DateTime.now();
    return dueDate.difference(now).inDays;
  }

 
  int get hoursRemaining {
    final now = DateTime.now();
    return dueDate.difference(now).inHours;
  }

 
  bool get isToday {
    final now = DateTime.now();
    return dueDate.year == now.year && 
           dueDate.month == now.month && 
           dueDate.day == now.day;
  }

  
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return dueDate.year == tomorrow.year && 
           dueDate.month == tomorrow.month && 
           dueDate.day == tomorrow.day;
  }

 
  bool get isOverdue {
    return dueDate.isBefore(DateTime.now()) && status != DeadlineStatus.completed;
  }

 
  bool get isDueSoon {
    final now = DateTime.now();
    final difference = dueDate.difference(now);
    return difference.inHours > 0 && difference.inHours <= 48 && status != DeadlineStatus.completed;
  }

  
  double get progressPercentage {
    switch (status) {
      case DeadlineStatus.completed:
        return 1.0;
      case DeadlineStatus.inProgress:
        return 0.5;
      case DeadlineStatus.pending:
      case DeadlineStatus.overdue:
        return 0.0;
    }
  }

 
  factory Deadline.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
   
    List<DateTime> reminderTimes = [];
    if (data['reminderTimes'] != null) {
      reminderTimes = (data['reminderTimes'] as List)
          .map((timestamp) => (timestamp as Timestamp).toDate())
          .toList();
    }
    
    
    List<String> tags = [];
    if (data['tags'] != null) {
      tags = List<String>.from(data['tags']);
    }
    
    return Deadline(
      id: doc.id,
      title: data['title'] ?? 'Untitled Deadline',
      description: data['description'],
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      priority: DeadlinePriority.values[data['priority'] ?? 0],
      status: DeadlineStatus.values[data['status'] ?? 0],
      tags: tags,
      courseId: data['courseId'],
      userId: data['userId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null 
          ? (data['completedAt'] as Timestamp).toDate() 
          : null,
      hasReminder: data['hasReminder'] ?? true,
      reminderTimes: reminderTimes,
    );
  }

  
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'dueDate': Timestamp.fromDate(dueDate),
      'priority': priority.value,
      'status': status.index,
      'tags': tags,
      'courseId': courseId,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'hasReminder': hasReminder,
      'reminderTimes': reminderTimes.map((dt) => Timestamp.fromDate(dt)).toList(),
    };
  }
  
 
  Deadline copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    DeadlinePriority? priority,
    DeadlineStatus? status,
    List<String>? tags,
    String? courseId,
    String? userId,
    DateTime? createdAt,
    DateTime? completedAt,
    bool? hasReminder,
    List<DateTime>? reminderTimes,
  }) {
    return Deadline(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      tags: tags ?? this.tags,
      courseId: courseId ?? this.courseId,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      hasReminder: hasReminder ?? this.hasReminder,
      reminderTimes: reminderTimes ?? this.reminderTimes,
    );
  }
}
