// File generated by FlutterFire CLI.
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB8rCCOBN1x2sC5VBnAEE_EhOBiCaC518A',
    appId: '1:522563222655:android:7c2bf6e418303bf243d34a',
    messagingSenderId: '522563222655',
    projectId: 'dcomic-93209',
    databaseURL: 'https://dcomic-93209-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'dcomic-93209.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDzVZW34AMDmTRo4bfUSEoB_r9KWYm9aVg',
    appId: '1:522563222655:ios:1da9bfe1c6049b0a43d34a',
    messagingSenderId: '522563222655',
    projectId: 'dcomic-93209',
    databaseURL: 'https://dcomic-93209-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'dcomic-93209.appspot.com',
    iosClientId: '522563222655-mrva14d6a637isfb57mn6e2apaelc45s.apps.googleusercontent.com',
    iosBundleId: 'top.hanerx.dcomic',
  );
}
