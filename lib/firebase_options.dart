// File generated manually based on provided google-services.json content.
// This handles the configuration of Firebase for your Android target profile.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for Web. Run flutterfire configure or supply a web config bloc.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCeaQzSjqZhPxio10S-lmqBbkioFTIKDqA',
    appId: '1:385449337240:android:9c1803d88749e1ba170bed',
    messagingSenderId: '385449337240',
    projectId: 'bondhon---social-media-app',
    storageBucket: 'bondhon---social-media-app.appspot.com',
  );

  // Extracted from GoogleService-Info.plist (com.meet.minutes entry)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC3JzNDW-34bTsn36ktEDvu2ryb2m4vsB4',
    appId: '1:385449337240:ios:fd3aea2027c464b8170bed',
    messagingSenderId: '385449337240',
    projectId: 'bondhon---social-media-app',
    storageBucket: 'bondhon---social-media-app.appspot.com',
    iosBundleId: 'com.meet.minutes',
  );
}
