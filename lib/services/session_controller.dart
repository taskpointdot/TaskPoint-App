import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';
import 'auth_service.dart';
import 'categories_service.dart';

String _platformDeviceName() {
  if (kIsWeb) return 'Web Browser';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android Device',
    TargetPlatform.iOS => 'iPhone',
    TargetPlatform.windows => 'Windows PC',
    TargetPlatform.macOS => 'Mac',
    TargetPlatform.linux => 'Linux PC',
    _ => 'Device',
  };
}

enum SessionStatus { loading, signedOut, signedIn }

/// App-wide session/auth state, following the same singleton-`ChangeNotifier`
/// pattern as [AppSettingsController] — no `provider`/`riverpod` package is
/// used anywhere else in this app, so this doesn't introduce one either.
///
/// Holds the live-streamed `users/{uid}` document for whoever is currently
/// signed in, so any screen can read `SessionController.instance.user`
/// (or listen for changes) instead of re-fetching it.
class SessionController extends ChangeNotifier {
  SessionController._() {
    _authSub = AuthService.instance.authStateChanges.listen(_onAuthChanged);
  }
  static final SessionController instance = SessionController._();

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _deviceSub;

  SessionStatus status = SessionStatus.loading;
  AppUser? user;
  String? currentDeviceId;

  /// Set just before an admin-suspended account is forcibly signed out, so
  /// the screen that lands afterwards can explain why instead of silently
  /// bouncing the user back to onboarding.
  String? lastSuspensionReason;

  String? get uid => AuthService.instance.currentUser?.uid;

  void _onAuthChanged(User? firebaseUser) {
    _userSub?.cancel();
    _deviceSub?.cancel();
    currentDeviceId = null;
    if (firebaseUser == null) {
      status = SessionStatus.signedOut;
      user = null;
      notifyListeners();
      return;
    }
    _userSub = FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).snapshots().listen((doc) {
      if (!doc.exists) return; // ensureUserDocument() is still writing it
      final loaded = AppUser.fromDoc(doc);
      // A moderator suspending this account from the admin dashboard takes
      // effect immediately, on whatever device is open — same live-document
      // mechanism as the remote device revoke above, rather than waiting for
      // the user to next restart the app.
      if (loaded.suspended) {
        lastSuspensionReason = loaded.suspensionReason;
        signOut();
        return;
      }
      user = loaded;
      status = SessionStatus.signedIn;
      notifyListeners();
    });
    _registerDevice(firebaseUser.uid);
    // Fire-and-forget: no-ops after the first successful seed anywhere,
    // guarded server-side by firestore.rules, not just this client check.
    CategoriesService.instance.seedIfEmpty();
  }

  /// Records this app session as a "logged-in device"
  /// (`users/{uid}/devices/{id}`) and listens for it being remotely
  /// revoked from the Manage Devices screen — the only realistic way to do
  /// "remote logout" from a phone-auth-only app with no Admin SDK backend.
  Future<void> _registerDevice(String uid) async {
    final ref = await FirebaseFirestore.instance.collection('users').doc(uid).collection('devices').add({
      'name': _platformDeviceName(),
      'lastActive': FieldValue.serverTimestamp(),
    });
    currentDeviceId = ref.id;
    var everSeen = false;
    _deviceSub = ref.snapshots().listen((snap) {
      if (snap.exists) {
        everSeen = true;
        return;
      }
      if (everSeen) signOut();
    });
  }

  /// The route the app should be showing right now, based on how far this
  /// user has gotten through onboarding. Used by [SplashScreen] and by
  /// [SessionController]-aware redirects elsewhere.
  String get startRoute {
    if (status != SessionStatus.signedIn || user == null) return '/onboarding';
    final u = user!;
    if (u.role == null) return '/role-selection';
    if (u.cnicStatus == CnicStatus.unsubmitted) return '/cnic-verification';
    return u.role == UserRole.worker ? '/worker-home' : '/home';
  }

  Future<void> setRole(UserRole role) async {
    final id = uid;
    if (id == null) return;
    await FirebaseFirestore.instance.collection('users').doc(id).update({'role': role.name});
  }

  Future<void> updateProfile({String? name, String? email}) async {
    final id = uid;
    if (id == null) return;
    await FirebaseFirestore.instance.collection('users').doc(id).update({
      if (name != null) 'name': name,
      if (email != null) 'email': email,
    });
  }

  Future<void> addSkill(String skill) async {
    final id = uid;
    if (id == null) return;
    await FirebaseFirestore.instance.collection('users').doc(id).update({
      'skills': FieldValue.arrayUnion([skill]),
    });
  }

  Future<void> removeSkill(String skill) async {
    final id = uid;
    if (id == null) return;
    await FirebaseFirestore.instance.collection('users').doc(id).update({
      'skills': FieldValue.arrayRemove([skill]),
    });
  }

  Future<void> updateServiceRadius(double km) async {
    final id = uid;
    if (id == null) return;
    await FirebaseFirestore.instance.collection('users').doc(id).update({'serviceRadiusKm': km});
  }

  Future<void> signOut() => AuthService.instance.signOut();

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    _deviceSub?.cancel();
    super.dispose();
  }
}
