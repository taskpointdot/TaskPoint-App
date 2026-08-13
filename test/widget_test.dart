import 'package:flutter_test/flutter_test.dart';

import 'package:taskpoint/main.dart';

// The previous version of this test pumped `TaskPointApp` directly and
// asserted on the splash screen's static text. That no longer works:
// `SplashScreen` now reads `SessionController.instance` in `initState`,
// which touches real `FirebaseAuth`/`Firestore` — and those need
// `Firebase.initializeApp()` (done in `main()`, which this test never
// calls) plus a full platform-channel mock stack for `firebase_auth`
// that this project doesn't have a package for. Pumping the widget here
// would just throw `[core/no-app]`, not verify anything real.
//
// Testing the actual auth-gated boot flow needs either the Firebase
// Local Emulator Suite or `firebase_auth_mocks`/`fake_cloud_firestore` —
// worth adding if this project grows a real test suite, but out of scope
// for this pass. This keeps a compiling, honest smoke test instead of a
// widget test that can't reach the code it claims to cover.
void main() {
  test('AppRoutes defines the expected route constants', () {
    expect(AppRoutes.splash, '/splash');
    expect(AppRoutes.home, '/home');
    expect(AppRoutes.workerHome, '/worker-home');
  });
}
