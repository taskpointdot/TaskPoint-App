import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review.dart';

class WorkerRatingSummary {
  final double average;
  final int count;
  const WorkerRatingSummary({required this.average, required this.count});
}

/// Reviews are append-only (`reviews/{id}`) and a worker's rating is
/// computed on demand from an aggregate query, rather than rolled up into
/// a `rating` field on the worker's own `users/{uid}` doc. That rollup
/// would need the *reviewer* (not the worker) to write to the worker's user
/// document, which Firestore security rules can't safely allow without a
/// Cloud Function (out of scope here) — so this reads the true source of
/// truth (the reviews themselves) instead of trusting a cached counter.
class ReviewsService {
  ReviewsService._();
  static final ReviewsService instance = ReviewsService._();

  final _db = FirebaseFirestore.instance;

  Stream<Review?> watchForJob(String jobId) {
    return _db.collection('reviews').where('jobId', isEqualTo: jobId).limit(1).snapshots().map(
          (s) => s.docs.isEmpty ? null : Review.fromDoc(s.docs.first),
        );
  }

  Stream<List<Review>> watchForWorker(String workerId) {
    return _db
        .collection('reviews')
        .where('workerId', isEqualTo: workerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Review.fromDoc).toList());
  }

  Future<WorkerRatingSummary> fetchRatingSummary(String workerId) async {
    final query = _db.collection('reviews').where('workerId', isEqualTo: workerId);
    final countSnap = await query.count().get();
    final count = countSnap.count ?? 0;
    if (count == 0) return const WorkerRatingSummary(average: 0, count: 0);
    final avgSnap = await query.aggregate(average('rating')).get();
    return WorkerRatingSummary(average: avgSnap.getAverage('rating') ?? 0, count: count);
  }

  Future<void> submitReview({
    required String jobId,
    required String workerId,
    required String seekerId,
    required String seekerName,
    required int rating,
    String comment = '',
  }) {
    return _db.collection('reviews').add({
      'jobId': jobId,
      'workerId': workerId,
      'seekerId': seekerId,
      'seekerName': seekerName,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
