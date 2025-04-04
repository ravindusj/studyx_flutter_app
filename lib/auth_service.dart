import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    signInOption: SignInOption.standard,
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserCredential?> signUpWithEmail(
    String email,
    String password,
    String name,
  ) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      await userCredential.user?.updateDisplayName(name);

      if (userCredential.user == null || userCredential.user!.uid.isEmpty) {
        debugPrint('Warning: User created but UID is empty');
        return userCredential;
      }

      final uid = userCredential.user!.uid;
      debugPrint('Creating user document with UID: $uid');

      try {
        await _firestore.collection('users').doc(uid).set({
          'displayName': name,
          'name': name,
          'email': email,
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
          'lastSignIn': FieldValue.serverTimestamp(),
        });

        debugPrint('User document successfully created');

        final docSnapshot = await _firestore.collection('users').doc(uid).get();
        if (!docSnapshot.exists) {
          debugPrint(
            'Warning: Document was created but not found on verification',
          );
        }
      } catch (e) {
        debugPrint('Error creating user document: $e');

        try {
          await _firestore.collection('users').add({
            'displayName': name,
            'name': name,
            'email': email,
            'uid': uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          debugPrint('Created user document with auto-generated ID');
        } catch (fallbackError) {
          debugPrint('Fallback creation also failed: $fallbackError');
        }
      }

      await userCredential.user?.reload();
      return userCredential;
    } catch (e) {
      debugPrint('Error in signUpWithEmail: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await _ensureUserDocumentExists(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      debugPrint('Error in signInWithEmail: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint("User cancelled Google Sign In");
        return null;
      }

      try {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final UserCredential userCredential = await _auth.signInWithCredential(
          credential,
        );

        if (userCredential.user != null) {
          final uid = userCredential.user!.uid;

          try {
            await _firestore.collection('users').doc(uid).set({
              'displayName': googleUser.displayName ?? 'Google User',
              'name': googleUser.displayName ?? 'Google User',
              'email': googleUser.email,
              'uid': uid,
              'photoURL': googleUser.photoUrl,
              'lastSignIn': FieldValue.serverTimestamp(),
              'createdAt': FieldValue.serverTimestamp(),
              'provider': 'google',
            }, SetOptions(merge: true));

            debugPrint('Google user document created/updated successfully');
          } catch (e) {
            debugPrint('Error creating Google user document: $e');
            await _ensureUserDocumentExists(userCredential.user!);
          }
        }

        return userCredential;
      } catch (e) {
        debugPrint('Firebase authentication error: $e');
        return null;
      }
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      return null;
    }
  }

  Future<void> _ensureUserDocumentExists(User user) async {
    try {
      final uid = user.uid;
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        debugPrint('User document missing. Creating now.');

        final String displayName =
            user.displayName ?? user.email?.split('@').first ?? 'User';

        await _firestore.collection('users').doc(uid).set({
          'displayName': displayName,
          'name': displayName,
          'email': user.email,
          'uid': uid,
          'photoURL': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'lastSignIn': FieldValue.serverTimestamp(),
        });

        debugPrint('Created missing user document');
      } else {
        await _firestore.collection('users').doc(uid).update({
          'lastSignIn': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error ensuring user document exists: $e');

      try {
        await _firestore.collection('users').add({
          'displayName':
              user.displayName ?? user.email?.split('@').first ?? 'User',
          'name': user.displayName ?? user.email?.split('@').first ?? 'User',
          'email': user.email,
          'uid': user.uid,
          'photoURL': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'lastSignIn': FieldValue.serverTimestamp(),
        });
        debugPrint('Created document with auto ID as fallback');
      } catch (fallbackError) {
        debugPrint('All document creation attempts failed: $fallbackError');
      }
    }
  }

  Future<void> migrateExistingUser(User user) async {
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists ||
          userDoc.data()?['displayName'] == null ||
          userDoc.data()?['name'] == null) {
        final String userName =
            user.displayName ??
            userDoc.data()?['displayName'] ??
            userDoc.data()?['name'] ??
            'Unknown';

        await _firestore.collection('users').doc(user.uid).set({
          'displayName': userName,
          'name': userName,
          'email': user.email,
          'uid': user.uid,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error migrating user: $e');
    }
  }

  Future<String> getUserName(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;

        return data['name'] ?? data['displayName'] ?? 'Unknown';
      }

      final authUser = await _auth.userChanges().firstWhere(
        (user) => user?.uid == userId,
        orElse: () => null,
      );

      if (authUser != null && authUser.displayName != null) {
        return authUser.displayName!;
      }

      return 'Unknown';
    } catch (e) {
      print('Error getting user name: $e');
      return 'Unknown';
    }
  }

  Future<Map<String, String>> getUserNames(List<String> userIds) async {
    try {
      final result = <String, String>{};

      for (int i = 0; i < userIds.length; i += 10) {
        final end = (i + 10 < userIds.length) ? i + 10 : userIds.length;
        final batchIds = userIds.sublist(i, end);

        final querySnapshot =
            await _firestore
                .collection('users')
                .where(FieldPath.documentId, whereIn: batchIds)
                .get();

        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          final name = data['name'] ?? data['displayName'] ?? 'Unknown';
          result[doc.id] = name;
        }
      }

      for (final id in userIds) {
        if (!result.containsKey(id)) {
          result[id] = 'Unknown';
        }
      }

      return result;
    } catch (e) {
      print('Error getting user names: $e');
      return {for (var id in userIds) id: 'Unknown'};
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  Future<void> verifyCurrentUserDocument() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _ensureUserDocumentExists(currentUser);
  }
}
