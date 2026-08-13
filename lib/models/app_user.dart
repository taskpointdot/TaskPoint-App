import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { seeker, worker }

enum CnicStatus { unsubmitted, pending, verified, rejected }

UserRole userRoleFromString(String? value) => value == 'worker' ? UserRole.worker : UserRole.seeker;

CnicStatus cnicStatusFromString(String? value) => switch (value) {
      'pending' => CnicStatus.pending,
      'verified' => CnicStatus.verified,
      'rejected' => CnicStatus.rejected,
      _ => CnicStatus.unsubmitted,
    };

/// Mirrors a `users/{uid}` Firestore document. Streamed live by
/// [SessionController] so every screen sees the same up-to-date profile.
class AppUser {
  final String uid;
  final String phone;
  final String name;
  final String email;
  final UserRole? role;
  final String? photoUrl;
  final CnicStatus cnicStatus;
  final String? cnicFrontUrl;
  final String? cnicBackUrl;
  final double walletBalance;
  final GeoPoint? location;
  final bool isOnline;
  final List<String> blockedUserIds;
  final bool profileVisible;
  final bool shareLiveLocation;
  final bool twoFactorEnabled;
  final List<String> skills;
  final double serviceRadiusKm;

  /// Set by a moderator from the admin dashboard's Users module. When true
  /// [SessionController] signs this device straight back out — see the
  /// listener there.
  final bool suspended;
  final String? suspensionReason;

  /// Why a CNIC submission was turned down, written by the admin
  /// dashboard's CNIC Verifications module so the user can be told what to
  /// re-shoot rather than just seeing "rejected".
  final String? cnicRejectionReason;
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    required this.phone,
    required this.name,
    this.email = '',
    required this.role,
    this.photoUrl,
    this.cnicStatus = CnicStatus.unsubmitted,
    this.cnicFrontUrl,
    this.cnicBackUrl,
    this.walletBalance = 0,
    this.location,
    this.isOnline = false,
    this.blockedUserIds = const [],
    this.profileVisible = true,
    this.shareLiveLocation = true,
    this.twoFactorEnabled = false,
    this.skills = const [],
    this.serviceRadiusKm = 5,
    this.suspended = false,
    this.suspensionReason,
    this.cnicRejectionReason,
    this.createdAt,
  });

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AppUser(
      uid: doc.id,
      phone: d['phone'] as String? ?? '',
      name: d['name'] as String? ?? '',
      email: d['email'] as String? ?? '',
      role: d['role'] == null ? null : userRoleFromString(d['role'] as String?),
      photoUrl: d['photoUrl'] as String?,
      cnicStatus: cnicStatusFromString(d['cnicStatus'] as String?),
      cnicFrontUrl: d['cnicFrontUrl'] as String?,
      cnicBackUrl: d['cnicBackUrl'] as String?,
      walletBalance: (d['walletBalance'] as num?)?.toDouble() ?? 0,
      location: d['location'] as GeoPoint?,
      isOnline: d['isOnline'] as bool? ?? false,
      blockedUserIds: List<String>.from(d['blockedUserIds'] as List? ?? const []),
      profileVisible: d['profileVisible'] as bool? ?? true,
      shareLiveLocation: d['shareLiveLocation'] as bool? ?? true,
      twoFactorEnabled: d['twoFactorEnabled'] as bool? ?? false,
      skills: List<String>.from(d['skills'] as List? ?? const []),
      serviceRadiusKm: (d['serviceRadiusKm'] as num?)?.toDouble() ?? 5,
      suspended: d['suspended'] as bool? ?? false,
      suspensionReason: d['suspensionReason'] as String?,
      cnicRejectionReason: d['cnicRejectionReason'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
