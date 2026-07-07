// STUB — Replace with the real output of `flutterfire configure`
// after connecting Firebase to this project.
//
// Steps:
//   1. Install FlutterFire CLI:  dart pub global activate flutterfire_cli
//   2. Run from flutter_app/:    flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
//   3. That overwrites this file with real values.
//
// Until then, the app will throw at Firebase.initializeApp() — that's expected.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
            'LexBot is Android-only. Run `flutterfire configure` to fill in real values.');
    }
  }

  // TODO: Replace all placeholder values with your real Firebase config.

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCezS9naRCgDeVReCm_jRkWbrAM2i-rm4A',
    appId: '1:803590597031:android:91b68e69a1431c47d76e82',
    messagingSenderId: '803590597031',
    projectId: 'lexbot-b93de',
    storageBucket: 'lexbot-b93de.firebasestorage.app',
  );
}
