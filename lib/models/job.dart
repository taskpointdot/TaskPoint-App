import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';

enum JobStatus { posted, negotiating, accepted, inProgress, completed, cancelled }

JobStatus jobStatusFromString(String? value) => switch (value) {
      'negotiating' => JobStatus.negotiating,
      'accepted' => JobStatus.accepted,
      'in_progress' => JobStatus.inProgress,
      'completed' => JobStatus.completed,
      'cancelled' => JobStatus.cancelled,
      _ => JobStatus.posted,
    };

String jobStatusToString(JobStatus s) => switch (s) {
      JobStatus.posted => 'posted',
      JobStatus.negotiating => 'negotiating',
      JobStatus.accepted => 'accepted',
      JobStatus.inProgress => 'in_progress',
      JobStatus.completed => 'completed',
      JobStatus.cancelled => 'cancelled',
    };

/// A `jobs/{jobId}` Firestore document.
class Job {
  final String id;
  final String seekerId;
  final String? categoryId;
  final String categoryName;
  final String description;
  final double budget;
  final JobStatus status;
  final GeoPoint? location;
  final String? address;
  final String? acceptedWorkerId;
  final String? acceptedWorkerName;
  final double? acceptedPrice;
  final List<String> beforePhotoUrls;
  final List<String> afterPhotoUrls;
  final DateTime? createdAt;
  final DateTime? completedAt;

  const Job({
    required this.id,
    required this.seekerId,
    this.categoryId,
    required this.categoryName,
    required this.description,
    required this.budget,
    this.status = JobStatus.posted,
    this.location,
    this.address,
    this.acceptedWorkerId,
    this.acceptedWorkerName,
    this.acceptedPrice,
    this.beforePhotoUrls = const [],
    this.afterPhotoUrls = const [],
    this.createdAt,
    this.completedAt,
  });

  bool get isActive => status != JobStatus.completed && status != JobStatus.cancelled;

  IconData get categoryIcon => categoryIconFor(categoryName);

  factory Job.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Job(
      id: doc.id,
      seekerId: d['seekerId'] as String? ?? '',
      categoryId: d['categoryId'] as String?,
      categoryName: d['categoryName'] as String? ?? '',
      description: d['description'] as String? ?? '',
      budget: (d['budget'] as num?)?.toDouble() ?? 0,
      status: jobStatusFromString(d['status'] as String?),
      location: d['location'] as GeoPoint?,
      address: d['address'] as String?,
      acceptedWorkerId: d['acceptedWorkerId'] as String?,
      acceptedWorkerName: d['acceptedWorkerName'] as String?,
      acceptedPrice: (d['acceptedPrice'] as num?)?.toDouble(),
      beforePhotoUrls: List<String>.from(d['beforePhotoUrls'] as List? ?? const []),
      afterPhotoUrls: List<String>.from(d['afterPhotoUrls'] as List? ?? const []),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      completedAt: (d['completedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// A `jobs/{jobId}/bids/{bidId}` Firestore document.
enum BidStatus { pending, accepted, rejected, countered }

BidStatus bidStatusFromString(String? value) => switch (value) {
      'accepted' => BidStatus.accepted,
      'rejected' => BidStatus.rejected,
      'countered' => BidStatus.countered,
      _ => BidStatus.pending,
    };

class Bid {
  final String id;
  final String jobId;
  final String workerId;
  final String workerName;
  final double price;
  final String message;
  final BidStatus status;
  final double workerRating;
  final int workerRatingCount;
  final bool workerOnline;
  final bool workerCnicVerified;
  final DateTime? createdAt;

  const Bid({
    required this.id,
    required this.jobId,
    required this.workerId,
    required this.workerName,
    required this.price,
    this.message = '',
    this.status = BidStatus.pending,
    this.workerRating = 0,
    this.workerRatingCount = 0,
    this.workerOnline = false,
    this.workerCnicVerified = false,
    this.createdAt,
  });

  factory Bid.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc, String jobId) {
    final d = doc.data() ?? {};
    return Bid(
      id: doc.id,
      jobId: jobId,
      workerId: d['workerId'] as String? ?? '',
      workerName: d['workerName'] as String? ?? '',
      price: (d['price'] as num?)?.toDouble() ?? 0,
      message: d['message'] as String? ?? '',
      status: bidStatusFromString(d['status'] as String?),
      workerRating: (d['workerRating'] as num?)?.toDouble() ?? 0,
      workerRatingCount: (d['workerRatingCount'] as num?)?.toInt() ?? 0,
      workerOnline: d['workerOnline'] as bool? ?? false,
      workerCnicVerified: d['workerCnicVerified'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Maps a category name to an icon. Categories themselves live in
/// Firestore (`categories/{id}`) with an `iconKey`; this is the client-side
/// lookup since `IconData` can't be stored in a document. Keyed by the
/// English category name so job/bid docs (which store `categoryName`, not
/// an icon) can still render a matching icon.
IconData categoryIconFor(String categoryNameOrKey) {
  switch (categoryNameOrKey.toLowerCase()) {
    case 'plumber':
    case 'plumbing':
      return Symbols.plumbing_rounded;
    case 'electrician':
    case 'electrical':
      return Symbols.bolt_rounded;
    case 'carpenter':
    case 'carpentry':
      return Symbols.carpenter_rounded;
    case 'painter':
    case 'painting':
      return Symbols.palette_rounded;
    case 'mason':
      return Symbols.layers_rounded;
    case 'cleaner':
    case 'cleaning':
      return Symbols.mop_rounded;
    case 'ac repair':
      return Symbols.ac_unit_rounded;
    case 'appliance repair':
      return Symbols.build_circle_rounded;
    case 'gardener':
      return Symbols.yard_rounded;
    case 'mover/shifting':
    case 'mover':
      return Symbols.local_shipping_rounded;
    case 'pest control':
      return Symbols.pest_control_rounded;
    case 'car wash':
      return Symbols.local_car_wash_rounded;
    default:
      return Symbols.handyman_rounded;
  }
}
