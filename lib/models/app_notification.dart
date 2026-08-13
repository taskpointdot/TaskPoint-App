import 'package:cloud_firestore/cloud_firestore.dart';

/// A `users/{uid}/notifications/{id}` Firestore document.
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // 'job' | 'bid' | 'message' | 'wallet' | 'system'
  final String? jobId;
  final bool read;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type = 'system',
    this.jobId,
    this.read = false,
    this.createdAt,
  });

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AppNotification(
      id: doc.id,
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      type: d['type'] as String? ?? 'system',
      jobId: d['jobId'] as String?,
      read: d['read'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
