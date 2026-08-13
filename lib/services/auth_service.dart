import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

/// Thin wrapper around Firebase Phone Auth. Screens don't talk to
/// `FirebaseAuth.instance` directly — they go through this so the OTP flow
/// has one place that knows how `verifyPhoneNumber`/`signInWithCredential`
/// actually work.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Starts the phone-OTP flow. [phone] must be in E.164 form (e.g.
  /// `+923451234567`). [codeSent] fires once Firebase has dispatched the SMS
  /// with a `verificationId` to pass to [confirmOtp]. [onAutoVerified] fires
  /// if the device auto-detects the SMS (Android only) and completes sign-in
  /// without the user typing anything.
  Future<void> sendOtp({
    required String phone,
    required void Function(String verificationId) codeSent,
    required void Function(UserCredential credential) onAutoVerified,
    required void Function(String message) onFailed,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        final result = await _auth.signInWithCredential(credential);
        onAutoVerified(result);
      },
      verificationFailed: (FirebaseAuthException e) {
        onFailed(e.message ?? 'Could not send verification code.');
      },
      codeSent: (String verificationId, int? resendToken) {
        codeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<UserCredential> confirmOtp({required String verificationId, required String smsCode}) async {
    final credential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
    try {
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Invalid verification code.');
    }
  }

  /// Creates the `users/{uid}` document on first sign-in if it doesn't exist
  /// yet, so every downstream screen can rely on the doc always being there.
  Future<void> ensureUserDocument({required String uid, required String phone}) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'phone': phone,
      'name': '',
      'role': null,
      'cnicStatus': 'unsubmitted',
      'walletBalance': 0,
      'isOnline': false,
      'blockedUserIds': <String>[],
      'profileVisible': true,
      'shareLiveLocation': true,
      'twoFactorEnabled': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw AuthException('No password is set on this account.');
    }
    try {
      await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: email, password: password));
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Current password is incorrect.');
    }
  }

  Future<void> signOut() => _auth.signOut();
}
