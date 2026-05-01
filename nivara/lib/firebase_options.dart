// PLACEHOLDER — run `scripts/setup-firebase.sh` in your terminal to regenerate
// with real Firebase project values via `flutterfire configure`.
// DO NOT commit this file with placeholder values to production.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Replace with real values from `flutterfire configure`.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_WITH_REAL_VALUE',
    appId: 'REPLACE_WITH_REAL_VALUE',
    messagingSenderId: 'REPLACE_WITH_REAL_VALUE',
    projectId: 'nivara-app',
    authDomain: 'nivara-app.firebaseapp.com',
    storageBucket: 'nivara-app.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_WITH_REAL_VALUE',
    appId: 'REPLACE_WITH_REAL_VALUE',
    messagingSenderId: 'REPLACE_WITH_REAL_VALUE',
    projectId: 'nivara-app',
    storageBucket: 'nivara-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_REAL_VALUE',
    appId: 'REPLACE_WITH_REAL_VALUE',
    messagingSenderId: 'REPLACE_WITH_REAL_VALUE',
    projectId: 'nivara-app',
    storageBucket: 'nivara-app.firebasestorage.app',
    iosClientId: 'REPLACE_WITH_REAL_VALUE',
    iosBundleId: 'com.example.nivara',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'REPLACE_WITH_REAL_VALUE',
    appId: 'REPLACE_WITH_REAL_VALUE',
    messagingSenderId: 'REPLACE_WITH_REAL_VALUE',
    projectId: 'nivara-app',
    storageBucket: 'nivara-app.firebasestorage.app',
    iosClientId: 'REPLACE_WITH_REAL_VALUE',
    iosBundleId: 'com.example.nivara',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'REPLACE_WITH_REAL_VALUE',
    appId: 'REPLACE_WITH_REAL_VALUE',
    messagingSenderId: 'REPLACE_WITH_REAL_VALUE',
    projectId: 'nivara-app',
    authDomain: 'nivara-app.firebaseapp.com',
    storageBucket: 'nivara-app.firebasestorage.app',
  );
}
