/// Backend layer for the actions in the worker profile's "⋮" menu
/// (Share Profile / Report Worker / Block Worker), and for fetching the
/// worker's own `users/{uid}` doc for display. Firestore/Auth-backed —
/// block/report state is read from the *current* signed-in user's doc via
/// [SessionController], not cached locally, so it survives app restarts.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import 'session_controller.dart';

class WorkerProfileActionException implements Exception {
  final String message;
  WorkerProfileActionException(this.message);
  @override
  String toString() => message;
}

enum ReportReason { inappropriateBehavior, poorWorkQuality, priceDispute, safetyConcern, other }

extension ReportReasonLabel on ReportReason {
  String get label => switch (this) {
        ReportReason.inappropriateBehavior => 'Inappropriate behavior',
        ReportReason.poorWorkQuality => 'Poor work quality',
        ReportReason.priceDispute => 'Price dispute',
        ReportReason.safetyConcern => 'Safety concern',
        ReportReason.other => 'Other',
      };
}

class WorkerProfileActionsService {
  WorkerProfileActionsService();

  final _db = FirebaseFirestore.instance;

  bool isBlocked(String workerId) => SessionController.instance.user?.blockedUserIds.contains(workerId) ?? false;

  // Reported state isn't persisted anywhere readable by the reporter today
  // (reports/{id} is write-only for non-owners per firestore.rules) — kept
  // as a local flag for the current screen session only, so a user can't
  // spam-submit the same report twice in one sitting.
  final Set<String> _reportedThisSession = {};
  bool hasReported(String workerId) => _reportedThisSession.contains(workerId);

  Future<AppUser?> fetchWorker(String workerId) async {
    final doc = await _db.collection('users').doc(workerId).get();
    return doc.exists ? AppUser.fromDoc(doc) : null;
  }

  Future<String> generateShareLink(String workerId) async => 'https://taskpoint.app/w/$workerId';

  Future<void> reportWorker(String workerId, {required ReportReason reason, String details = ''}) async {
    final uid = SessionController.instance.uid;
    if (uid == null) throw WorkerProfileActionException('You must be signed in to report a worker.');
    await _db.collection('reports').add({
      'reporterId': uid,
      'targetUserId': workerId,
      'reason': reason.name,
      'details': details,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
    _reportedThisSession.add(workerId);
  }

  Future<void> blockWorker(String workerId) async {
    final uid = SessionController.instance.uid;
    if (uid == null) throw WorkerProfileActionException('You must be signed in to block a worker.');
    await _db.collection('users').doc(uid).update({
      'blockedUserIds': FieldValue.arrayUnion([workerId]),
    });
  }

  Future<void> unblockWorker(String workerId) async {
    final uid = SessionController.instance.uid;
    if (uid == null) throw WorkerProfileActionException('You must be signed in to unblock a worker.');
    await _db.collection('users').doc(uid).update({
      'blockedUserIds': FieldValue.arrayRemove([workerId]),
    });
  }
}
