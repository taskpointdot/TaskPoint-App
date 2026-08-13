import 'package:cloud_firestore/cloud_firestore.dart';

/// A `reviews/{id}` Firestore document.
class Review {
  final String id;
  final String jobId;
  final String workerId;
  final String seekerId;
  final String seekerName;
  final int rating;
  final String comment;
  final DateTime? createdAt;

  const Review({
    required this.id,
    required this.jobId,
    required this.workerId,
    required this.seekerId,
    this.seekerName = '',
    required this.rating,
    this.comment = '',
    this.createdAt,
  });

  factory Review.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Review(
      id: doc.id,
      jobId: d['jobId'] as String? ?? '',
      workerId: d['workerId'] as String? ?? '',
      seekerId: d['seekerId'] as String? ?? '',
      seekerName: d['seekerName'] as String? ?? '',
      rating: (d['rating'] as num?)?.toInt() ?? 0,
      comment: d['comment'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
