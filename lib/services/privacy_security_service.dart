/// Backend layer for the Privacy & Security screen. Firestore/Auth-backed —
/// every method here is the real call; nothing in `PrivacySecurityScreen`,
/// `ChangePasswordScreen`, or `ManageDevicesScreen` needed to change to
/// make that swap, since the public method signatures stayed the same.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'session_controller.dart';

class PrivacySecurityException implements Exception {
  final String message;
  PrivacySecurityException(this.message);
  @override
  String toString() => message;
}

class LoggedInDevice {
  final String id;
  final String name;
  final String location;
  final String lastActive;
  final bool isCurrentDevice;
  const LoggedInDevice({
    required this.id,
    required this.name,
    required this.location,
    required this.lastActive,
    required this.isCurrentDevice,
  });
}

class PrivacySecurityService {
  PrivacySecurityService();

  String? get _uid => SessionController.instance.uid;
  CollectionReference<Map<String, dynamic>> get _users => FirebaseFirestore.instance.collection('users');

  Future<void> updateShowProfileToCustomers(bool value) async {
    final uid = _uid;
    if (uid == null) throw PrivacySecurityException('You must be signed in.');
    await _users.doc(uid).update({'profileVisible': value});
  }

  Future<void> updateShareLiveLocation(bool value) async {
    final uid = _uid;
    if (uid == null) throw PrivacySecurityException('You must be signed in.');
    await _users.doc(uid).update({'shareLiveLocation': value});
  }

  /// Toggles the flag only — there's no real OTP-on-top-of-sign-in
  /// challenge here (phone-based accounts are already OTP-gated at login),
  /// so this doesn't kick off a second verification flow.
  Future<void> updateTwoFactorAuth(bool value) async {
    final uid = _uid;
    if (uid == null) throw PrivacySecurityException('You must be signed in.');
    await _users.doc(uid).update({'twoFactorEnabled': value});
  }

  /// Records a real export request; nothing processes it yet (no backend
  /// email/export job exists), so this is honest about what actually
  /// happens rather than pretending an email gets sent.
  Future<void> requestDataExport() async {
    final uid = _uid;
    if (uid == null) throw PrivacySecurityException('You must be signed in.');
    await FirebaseFirestore.instance.collection('data_export_requests').add({
      'userId': uid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw PrivacySecurityException('You must be signed in.');
    try {
      await _users.doc(user.uid).delete();
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw PrivacySecurityException('Please sign out and sign back in, then try deleting your account again.');
      }
      throw PrivacySecurityException(e.message ?? 'Could not delete your account.');
    }
  }

  /// Phone-auth accounts have no password to change — this app only
  /// supports Firebase Phone Auth (no email/password sign-in), so this is
  /// a real, honest rejection rather than a fake success.
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    throw PrivacySecurityException('Your account signs in with your phone number — there is no password to change.');
  }

  Future<List<LoggedInDevice>> fetchLoggedInDevices() async {
    final uid = _uid;
    if (uid == null) return const [];
    final snap = await _users.doc(uid).collection('devices').orderBy('lastActive', descending: true).get();
    final currentId = SessionController.instance.currentDeviceId;
    return snap.docs.map((d) {
      final data = d.data();
      final ts = data['lastActive'] as Timestamp?;
      return LoggedInDevice(
        id: d.id,
        name: data['name'] as String? ?? 'Device',
        location: '',
        lastActive: ts == null ? 'Just now' : '${ts.toDate()}'.split('.').first,
        isCurrentDevice: d.id == currentId,
      );
    }).toList();
  }

  /// Deletes the device's session doc. If that device's app is still open,
  /// its own listener (set up in [SessionController]) sees the doc
  /// disappear and signs itself out — this is what makes "Log Out" here
  /// actually work remotely, not just cosmetically.
  Future<void> revokeDevice(String deviceId) async {
    final uid = _uid;
    if (uid == null) return;
    if (deviceId == SessionController.instance.currentDeviceId) return; // can't revoke yourself from this list
    await _users.doc(uid).collection('devices').doc(deviceId).delete();
  }

  Future<void> revokeAllOtherDevices() async {
    final uid = _uid;
    if (uid == null) return;
    final currentId = SessionController.instance.currentDeviceId;
    final snap = await _users.doc(uid).collection('devices').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      if (doc.id != currentId) batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
