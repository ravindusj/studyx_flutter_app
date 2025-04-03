import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return android;
    } else {
      return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBmVnl8e5CWdvFssG6XQdMDSjHXLoG_0B0',  
    appId: '1:586254831344:android:19c9b0e5376a34e82dbc35',   
    messagingSenderId: '586254831344',
    projectId: 'studyx-app-74d6f',  
    storageBucket: 'studyx-app-74d6f.firebasestorage.app', 
  );
}