import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CanteenModel {
  final String id;
  final String name;
  final int availableSeats;
  final int totalSeats;
  final DateTime lastUpdated;
  final String updatedBy;

  CanteenModel({
    required this.id,
    required this.name,
    required this.availableSeats,
    required this.totalSeats,
    required this.lastUpdated,
    required this.updatedBy,
  });

  double get availabilityPercentage => (availableSeats / totalSeats) * 100;

  double get occupancyRate => (totalSeats - availableSeats) / totalSeats;

  String get availabilityStatus {
    if (availabilityPercentage >= 70) {
      return "Available";
    } else if (availabilityPercentage >= 30) {
      return "Moderate";
    } else {
      return "Crowded";
    }
  }

  Color get statusColor {
    if (availabilityPercentage >= 70) {
      return Colors.green;
    } else if (availabilityPercentage >= 30) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  factory CanteenModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CanteenModel(
      id: doc.id,
      name: data['name'] ?? '',
      availableSeats: data['availableSeats'] ?? 0,
      totalSeats: data['totalSeats'] ?? 100,
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
      updatedBy: data['updatedBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'availableSeats': availableSeats,
      'totalSeats': totalSeats,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'updatedBy': updatedBy,
    };
  }

  CanteenModel copyWith({
    String? id,
    String? name,
    int? availableSeats,
    int? totalSeats,
    DateTime? lastUpdated,
    String? updatedBy,
  }) {
    return CanteenModel(
      id: id ?? this.id,
      name: name ?? this.name,
      availableSeats: availableSeats ?? this.availableSeats,
      totalSeats: totalSeats ?? this.totalSeats,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
