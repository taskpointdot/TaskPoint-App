import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/job.dart';
import 'geo_utils.dart';
import 'notifications_service.dart';

class JobsException implements Exception {
  final String message;
  JobsException(this.message);
  @override
  String toString() => message;
}

/// Firestore-backed job/bid operations. One method per operation, same
/// shape as the app's existing fake-backend services (e.g.
/// WorkerProfileActionsService) — screens call these instead of touching
/// `FirebaseFirestore.instance` directly.
class JobsService {
  JobsService._();
  static final JobsService instance = JobsService._();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _jobs => _db.collection('jobs');

  Future<String> postJob({
    required String seekerId,
    String? categoryId,
    required String categoryName,
    required String description,
    required double budget,
    GeoPoint? location,
    String? address,
  }) async {
    final doc = await _jobs.add({
      'seekerId': seekerId,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'description': description,
      'budget': budget,
      'status': 'posted',
      'location': location,
      'address': address,
      'beforePhotoUrls': <String>[],
      'afterPhotoUrls': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Stream<Job> watchJob(String jobId) => _jobs.doc(jobId).snapshots().map(Job.fromDoc);

  Future<Job?> getJob(String jobId) async {
    final doc = await _jobs.doc(jobId).get();
    return doc.exists ? Job.fromDoc(doc) : null;
  }

  /// Jobs posted by a given seeker, most recent first.
  Stream<List<Job>> watchJobsBySeeker(String seekerId) {
    return _jobs
        .where('seekerId', isEqualTo: seekerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Job.fromDoc).toList());
  }

  /// Jobs accepted by a given worker, most recent first.
  Stream<List<Job>> watchJobsByWorker(String workerId) {
    return _jobs
        .where('acceptedWorkerId', isEqualTo: workerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Job.fromDoc).toList());
  }

  /// Open jobs (status == 'posted'), optionally filtered to within
  /// [radiusKm] of [near]. No native geo-query — pulls the most recent
  /// `limit` open jobs and filters client-side with Haversine distance,
  /// which is accurate enough at this app's data volume.
  Stream<List<Job>> watchNearbyOpenJobs({GeoPoint? near, double radiusKm = 5, int limit = 50}) {
    return _jobs
        .where('status', isEqualTo: 'posted')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) {
      final jobs = s.docs.map(Job.fromDoc).toList();
      if (near == null) return jobs;
      return jobs.where((j) => j.location == null || distanceKm(near, j.location!) <= radiusKm).toList();
    });
  }

  Future<void> updateStatus(String jobId, JobStatus status) => _jobs.doc(jobId).update({'status': jobStatusToString(status)});

  /// Uploads a before/after completion photo to
  /// `job_photos/{jobId}/{before|after}.jpg` and returns its download URL.
  Future<String> uploadJobPhoto({required String jobId, required String side, required Uint8List bytes}) async {
    final ref = FirebaseStorage.instance.ref('job_photos/$jobId/$side.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<void> markCompleted(String jobId, {List<String> beforePhotoUrls = const [], List<String> afterPhotoUrls = const []}) {
    return _jobs.doc(jobId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      if (beforePhotoUrls.isNotEmpty) 'beforePhotoUrls': beforePhotoUrls,
      if (afterPhotoUrls.isNotEmpty) 'afterPhotoUrls': afterPhotoUrls,
    });
  }

  Future<void> cancelJob(String jobId) => _jobs.doc(jobId).update({'status': 'cancelled'});

  // --- Bids ---

  CollectionReference<Map<String, dynamic>> _bids(String jobId) => _jobs.doc(jobId).collection('bids');

  Stream<List<Bid>> watchBids(String jobId) {
    return _bids(jobId).orderBy('createdAt', descending: true).snapshots().map(
          (s) => s.docs.map((d) => Bid.fromDoc(d, jobId)).toList(),
        );
  }

  Future<void> placeBid({
    required String jobId,
    required String workerId,
    required String workerName,
    required double price,
    String message = '',
    double workerRating = 0,
    int workerRatingCount = 0,
    bool workerOnline = false,
    bool workerCnicVerified = false,
  }) async {
    await _bids(jobId).add({
      'workerId': workerId,
      'workerName': workerName,
      'price': price,
      'message': message,
      'status': 'pending',
      'workerRating': workerRating,
      'workerRatingCount': workerRatingCount,
      'workerOnline': workerOnline,
      'workerCnicVerified': workerCnicVerified,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _jobs.doc(jobId).update({'status': 'negotiating'});
    final job = await getJob(jobId);
    if (job != null) {
      await NotificationsService.instance.send(
        uid: job.seekerId,
        title: 'New bid received',
        body: '$workerName offered Rs. ${price.toStringAsFixed(0)} for "${job.categoryName}"',
        type: 'bid',
        jobId: jobId,
      );
    }
  }

  /// Accepts one bid, rejects the rest, and marks the job accepted.
  Future<void> acceptBid({required String jobId, required Bid bid}) async {
    final batch = _db.batch();
    final bidsSnap = await _bids(jobId).get();
    for (final doc in bidsSnap.docs) {
      batch.update(doc.reference, {'status': doc.id == bid.id ? 'accepted' : 'rejected'});
    }
    batch.update(_jobs.doc(jobId), {
      'status': 'accepted',
      'acceptedWorkerId': bid.workerId,
      'acceptedWorkerName': bid.workerName,
      'acceptedPrice': bid.price,
    });
    await batch.commit();
    await NotificationsService.instance.send(
      uid: bid.workerId,
      title: 'Bid accepted',
      body: 'Your offer of Rs. ${bid.price.toStringAsFixed(0)} was accepted',
      type: 'job',
      jobId: jobId,
    );
  }

  Future<void> counterBid({required String jobId, required String bidId, required double newPrice}) async {
    await _bids(jobId).doc(bidId).update({'status': 'countered', 'price': newPrice});
  }

  Future<int> countCompletedJobsForWorker(String workerId) async {
    final snap = await _jobs.where('acceptedWorkerId', isEqualTo: workerId).where('status', isEqualTo: 'completed').count().get();
    return snap.count ?? 0;
  }
}
