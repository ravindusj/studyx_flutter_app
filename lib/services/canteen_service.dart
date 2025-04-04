import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/canteen_model.dart';
import 'package:flutter/material.dart';
import 'notification_service.dart';

class CanteenService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<CanteenModel> _demoCanteens = [];
  bool _useDemo = false;
  final NotificationService _notificationService = NotificationService();

  final Map<String, double> _previousAvailability = {};

  Future<void> initializeCanteens() async {
    try {
      final canteensSnapshot = await _firestore.collection('canteens').get();
      _useDemo = false;

      if (canteensSnapshot.docs.isEmpty) {
        await _createUniversityCanteens();
        debugPrint('Created university canteens in Firestore');
      } else {
        debugPrint(
          'Found ${canteensSnapshot.docs.length} canteens in Firestore',
        );
      }
    } catch (e) {
      debugPrint('Using demo data: $e');
      _useDemo = true;

      if (_demoCanteens.isEmpty) {
        final now = DateTime.now();
        _demoCanteens.addAll([
          CanteenModel(
            id: 'edge-canteen',
            name: 'Edge Canteen',
            availableSeats: 150,
            totalSeats: 250,
            lastUpdated: now,
            updatedBy: 'system',
          ),
          CanteenModel(
            id: 'audi-canteen',
            name: 'Audi Canteen',
            availableSeats: 30,
            totalSeats: 80,
            lastUpdated: now,
            updatedBy: 'system',
          ),
          CanteenModel(
            id: 'hostel-canteen',
            name: 'Hostel Canteen',
            availableSeats: 60,
            totalSeats: 120,
            lastUpdated: now,
            updatedBy: 'system',
          ),
        ]);
      }
    }
  }

  Future<void> _createUniversityCanteens() async {
    final batch = _firestore.batch();
    final now = Timestamp.now();

    final edgeCanteenRef = _firestore
        .collection('canteens')
        .doc('edge-canteen');
    batch.set(edgeCanteenRef, {
      'name': 'Edge Canteen',
      'availableSeats': 150,
      'totalSeats': 250,
      'lastUpdated': now,
      'updatedBy': 'system',
    });

    final audiCanteenRef = _firestore
        .collection('canteens')
        .doc('audi-canteen');
    batch.set(audiCanteenRef, {
      'name': 'Audi Canteen',
      'availableSeats': 30,
      'totalSeats': 80,
      'lastUpdated': now,
      'updatedBy': 'system',
    });

    final hostelCanteenRef = _firestore
        .collection('canteens')
        .doc('hostel-canteen');
    batch.set(hostelCanteenRef, {
      'name': 'Hostel Canteen',
      'availableSeats': 60,
      'totalSeats': 120,
      'lastUpdated': now,
      'updatedBy': 'system',
    });

    try {
      await batch.commit();
      debugPrint('University canteens initialized successfully in Firestore');
    } catch (e) {
      debugPrint('Error initializing university canteens: $e');
      throw e;
    }
  }

  Stream<List<CanteenModel>> getCanteens() {
    if (_useDemo) {
      return Stream.value(_demoCanteens);
    } else {
      return _firestore.collection('canteens').snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => CanteenModel.fromFirestore(doc))
            .toList();
      });
    }
  }

  Future<bool> updateCanteenAvailability(
    String canteenId,
    double availabilityPercentage,
    String userId,
  ) async {
    final oldAvailability = _previousAvailability[canteenId];

    _previousAvailability[canteenId] = availabilityPercentage;

    if (_useDemo) {
      final index = _demoCanteens.indexWhere((c) => c.id == canteenId);
      if (index != -1) {
        int availableSeats =
            ((availabilityPercentage / 100) * _demoCanteens[index].totalSeats)
                .round();

        _demoCanteens[index] = _demoCanteens[index].copyWith(
          availableSeats: availableSeats,
          lastUpdated: DateTime.now(),
          updatedBy: userId,
        );

        _demoCanteens.replaceRange(0, _demoCanteens.length, [..._demoCanteens]);
      }

      if (oldAvailability != null &&
          _shouldNotify(oldAvailability, availabilityPercentage)) {
        final canteen = _demoCanteens.firstWhere(
          (c) => c.id == canteenId,
          orElse:
              () => CanteenModel(
                id: canteenId,
                name: canteenId
                    .replaceAll('-', ' ')
                    .split(' ')
                    .map(
                      (word) =>
                          word.substring(0, 1).toUpperCase() +
                          word.substring(1),
                    )
                    .join(' '),
                availableSeats: 0,
                totalSeats: 100,
                lastUpdated: DateTime.now(),
                updatedBy: 'system',
              ),
        );

        _sendAvailabilityNotification(
          canteen.id,
          canteen.name,
          availabilityPercentage,
        );
      }

      return false;
    } else {
      try {
        final canteenDoc =
            await _firestore.collection('canteens').doc(canteenId).get();

        if (!canteenDoc.exists) {
          throw FirebaseException(
            plugin: 'firestore',
            code: 'not-found',
            message: 'Canteen document not found',
          );
        }

        final data = canteenDoc.data() as Map<String, dynamic>;
        final totalSeats = data['totalSeats'] ?? 100;

        int availableSeats =
            ((availabilityPercentage / 100) * totalSeats).round();

        final updateData = {
          'availableSeats': availableSeats,
          'lastUpdated': FieldValue.serverTimestamp(),
          'updatedBy': userId,
        };

        debugPrint(
          'Updating canteen $canteenId with ${availabilityPercentage.toStringAsFixed(1)}% availability (seats: $availableSeats/$totalSeats)',
        );

        await _firestore
            .collection('canteens')
            .doc(canteenId)
            .update(updateData);

        if (oldAvailability != null &&
            _shouldNotify(oldAvailability, availabilityPercentage)) {
          final data = canteenDoc.data() as Map<String, dynamic>;
          final name = data['name'] ?? 'Unknown Canteen';

          _sendAvailabilityNotification(
            canteenId,
            name,
            availabilityPercentage,
          );
        }

        debugPrint('Successfully updated canteen $canteenId in Firestore');
        return true;
      } catch (e) {
        debugPrint('Error updating canteen in Firestore: $e');

        if (e is FirebaseException && e.code == 'not-found') {
          try {
            debugPrint('Canteen not found, creating a new document');
            final totalSeats = 100;
            final availableSeats =
                ((availabilityPercentage / 100) * totalSeats).round();

            await _firestore.collection('canteens').doc(canteenId).set({
              'name': canteenId
                  .replaceAll('-', ' ')
                  .split(' ')
                  .map(
                    (word) =>
                        word.substring(0, 1).toUpperCase() + word.substring(1),
                  )
                  .join(' '),
              'availableSeats': availableSeats,
              'totalSeats': totalSeats,
              'lastUpdated': FieldValue.serverTimestamp(),
              'updatedBy': userId,
            });
            return true;
          } catch (e2) {
            debugPrint('Error creating canteen: $e2');
          }
        }

        _useDemo = true;
        return updateCanteenAvailability(
          canteenId,
          availabilityPercentage,
          userId,
        );
      }
    }
  }

  bool _shouldNotify(double oldAvailability, double newAvailability) {
    const List<double> thresholds = [30, 70];

    for (final threshold in thresholds) {
      if (oldAvailability > threshold && newAvailability <= threshold) {
        return true;
      }

      if (oldAvailability < threshold && newAvailability >= threshold) {
        return true;
      }
    }

    return false;
  }

  Future<void> _sendAvailabilityNotification(
    String canteenId,
    String canteenName,
    double availabilityPercentage,
  ) async {
    try {
      await _notificationService.sendCanteenNotification(
        canteenId: canteenId,
        canteenName: canteenName,
        availability: availabilityPercentage,
      );
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  Future<bool> isFirestoreAvailable() async {
    try {
      await _firestore.collection('canteens').limit(1).get();
      return true;
    } catch (e) {
      debugPrint('Firestore not available: $e');
      return false;
    }
  }
}
