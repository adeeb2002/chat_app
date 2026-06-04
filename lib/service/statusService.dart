import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import '../model/status.dart';

class StatusService {
  final FirebaseDatabase _db;

  StatusService(this._db);

  // Reference to statuses in database
  DatabaseReference get _statusesRef => _db.ref('statuses');

  // Create a new status
  Future<String> createStatus(Status status) async {
    try {
      final newStatusRef = _statusesRef.child(status.userId).push();
      final statusWithId = status.copyWith(id: newStatusRef.key);
      await newStatusRef.set(statusWithId.toJson());
      return newStatusRef.key!;
    } catch (e) {
      throw Exception('Failed to create status: $e');
    }
  }

  // Get statuses for a specific user
  Stream<List<Status>> getUserStatuses(String userId) {
    return _statusesRef
        .child(userId)
        .onValue
        .map((event) {
      final statuses = <Status>[];
      if (event.snapshot.value != null) {
        final data =
            Map<String, dynamic>.from(event.snapshot.value as Map);
        data.forEach((key, value) {
          final status = Status.fromJson(
              Map<String, dynamic>.from(value as Map)..['id'] = key);
          // Filter out expired statuses
          if (!status.isExpired) {
            statuses.add(status);
          }
        });
      }
      // Sort by timestamp (newest first)
      statuses.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return statuses;
    });
  }

  // Get all statuses from users that current user follows (for simplicity, we'll get all active users' statuses)
  // In a real app, you'd have a following/followers system
  Stream<List<Status>> getAllActiveStatuses() {
    return _statusesRef.onValue.map((event) {
      final statuses = <Status>[];
      if (event.snapshot.value != null) {
        final data =
            Map<String, dynamic>.from(event.snapshot.value as Map);
        data.forEach((userId, userStatuses) {
          if (userStatuses != null) {
            final statusesMap =
                Map<String, dynamic>.from(userStatuses as Map);
            statusesMap.forEach((key, value) {
              final status = Status.fromJson(
                  Map<String, dynamic>.from(value as Map)..['id'] = key);
              // Filter out expired statuses
              if (!status.isExpired) {
                statuses.add(status);
              }
            });
          }
        });
      }
      // Sort by timestamp (newest first)
      statuses.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return statuses;
    });
  }

  // Delete a status
  Future<void> deleteStatus(String userId, String statusId) async {
    try {
      await _statusesRef.child(userId).child(statusId).remove();
    } catch (e) {
      throw Exception('Failed to delete status: $e');
    }
  }

  // Add a view to a status (when someone views it)
  Future<void> addView(String userId, String statusId, String viewerId) async {
    try {
      final statusRef =
          _statusesRef.child(userId).child(statusId).child('views');
      final snapshot = await statusRef.get();
      final views = List<String>.from(snapshot.value as List? ?? []);
      if (!views.contains(viewerId)) {
        views.add(viewerId);
        await statusRef.set(views);
      }
    } catch (e) {
      throw Exception('Failed to add view: $e');
    }
  }

  // Get views for a status
  Future<List<String>> getStatusViews(String userId, String statusId) async {
    try {
      final snapshot = await _statusesRef
          .child(userId)
          .child(statusId)
          .child('views')
          .get();
      return List<String>.from(snapshot.value as List? ?? []);
    } catch (e) {
      throw Exception('Failed to get views: $e');
    }
  }

  // Clean up expired statuses (could be called periodically)
  Future<void> cleanupExpiredStatuses() async {
    try {
      final snapshot = await _statusesRef.get();
      if (snapshot.value != null) {
        final data =
            Map<String, dynamic>.from(snapshot.value as Map);
        data.forEach((userId, userStatuses) {
          if (userStatuses != null) {
            final statusesMap =
                Map<String, dynamic>.from(userStatuses as Map);
            statusesMap.forEach((statusId, statusData) {
              final status = Status.fromJson(
                  Map<String, dynamic>.from(statusData as Map)..['id'] = statusId);
              if (status.isExpired) {
                _statusesRef.child(userId).child(statusId).remove();
              }
            });
          }
        });
      }
    } catch (e) {
      // In production, use a proper logging framework
      // ignore: avoid_print
      print('Error cleaning up expired statuses: $e');
    }
  }
}