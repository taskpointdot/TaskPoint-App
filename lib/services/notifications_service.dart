import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_notification.dart';

/// Real-time, in-app notifications only (`users/{uid}/notifications`) — no
/// FCM/push wiring, since nothing in this app's scope can trigger a push
/// send while the app is closed. Any signed-in user can create a
/// notification for someone else (e.g. a bid notifying the seeker); only
/// the owner can read/mark-read/delete their own.
class NotificationsService {
  NotificationsService._();
  static final NotificationsService instance = NotificationsService._();

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications');

  Stream<List<AppNotification>> watch(String uid) {
    return _col(uid).orderBy('createdAt', descending: true).limit(50).snapshots().map(
          (s) => s.docs.map(AppNotification.fromDoc).toList(),
        );
  }

  Stream<int> watchUnreadCount(String uid) {
    return _col(uid).where('read', isEqualTo: false).snapshots().map((s) => s.docs.length);
  }

  Future<void> send({required String uid, required String title, required String body, String type = 'system', String? jobId}) {
    return _col(uid).add({
      'title': title,
      'body': body,
      'type': type,
      'jobId': jobId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markRead(String uid, String notificationId) => _col(uid).doc(notificationId).update({'read': true});

  Future<void> markAllRead(String uid) async {
    final unread = await _col(uid).where('read', isEqualTo: false).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
