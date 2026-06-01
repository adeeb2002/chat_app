import 'package:ChatApp/model/ReplyToStatus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../service/statusService.dart';
import '../model/status.dart';

// StatusService provider
final statusServiceProvider = Provider<StatusService>((ref) {
  final db = FirebaseDatabase.instance;
  return StatusService(db);
});

// Provider to get statuses for a specific user (e.g., current user's own statuses)
final userStatusesProvider = StreamProvider.family<List<Status>, String>((ref, userId) {
  final statusService = ref.watch(statusServiceProvider);
  return statusService.getUserStatuses(userId);
});

// Provider to get all active statuses (for home screen to show stories from everyone)
final allStatusesProvider = StreamProvider<List<Status>>((ref) {
  final statusService = ref.watch(statusServiceProvider);
  return statusService.getAllActiveStatuses();
});

// Provider for creating a new status (returns the statusId)
final statusCreationProvider = FutureProvider.family<String, Status>((ref, status) async {
  final statusService = ref.watch(statusServiceProvider);
  return await statusService.createStatus(status);
});
// حذف القصة
final deleteStatusProvider = FutureProvider.family<void, String>((ref, statusId) async {
  final db = FirebaseDatabase.instance;
  await db.ref('statuses').child(statusId).remove();
});


// Parameters for status deletion
class StatusDeletionParams {
  final String userId;
  final String statusId;

  StatusDeletionParams({
    required this.userId,
    required this.statusId,
  });
}

// Provider for adding a view to a status
final statusViewProvider = FutureProvider.family<void, StatusViewParams>((ref, params) async {
  final statusService = ref.watch(statusServiceProvider);
  await statusService.addView(params.userId, params.statusId, params.viewerId);
});


// ✅ جلب الردود على قصة معينة
final statusRepliesProvider = FutureProvider.family<List<StatusReply>, String>((ref, statusId) async {
  final db = FirebaseDatabase.instance;
  final snapshot = await db.ref('status_replies').child(statusId).orderByChild('timestamp').get();
  
  if (!snapshot.exists) return [];
  
  final replies = <StatusReply>[];
  final data = snapshot.value as Map<dynamic, dynamic>;
  
  for (var entry in data.entries) {
    replies.add(StatusReply.fromMap(entry.key.toString(), Map.from(entry.value)));
  }
  
  return replies;
});

// ✅ إضافة رد على القصة (بديل آخر)
final addStatusReplyProvider = FutureProvider.family<void, StatusReply>((ref, reply) async {
  final db = FirebaseDatabase.instance;
  await db.ref('status_replies').child(reply.statusId).child(reply.id).set(reply.toMap());
});

// Parameters for adding a view
class StatusViewParams {
  final String userId;
  final String statusId;
  final String viewerId;

  StatusViewParams({
    required this.userId,
    required this.statusId,
    required this.viewerId,
  });
}

// Provider for getting views of a status
final statusViewsProvider = FutureProvider.family<List<String>, StatusViewsParams>((ref, params) async {
  final statusService = ref.watch(statusServiceProvider);
  return await statusService.getStatusViews(params.userId, params.statusId);
});

// Parameters for getting views
class StatusViewsParams {
  final String userId;
  final String statusId;

  StatusViewsParams({
    required this.userId,
    required this.statusId,
  });
}