import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool get isSignedIn => _auth.currentUser != null;

  Future<void> _upsertUserDoc(
    User user, {
    String? name,
    bool anon = false,
  }) async {
    await _db.collection('users').doc(user.uid).set({
      'name': name ?? user.displayName ?? (anon ? 'Guest' : 'User'),
      'email': user.email ?? '',
      'photoUrl': user.photoURL,
      'isAnonymous': anon,
      'lastSeen': DateTime.now().toIso8601String(),
      'isOnline': true,
    }, SetOptions(merge: true));
  }

  Future<UserCredential> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await cred.user?.updateDisplayName(name);

    if (cred.user != null) {
      await _upsertUserDoc(
        cred.user!,
        name: name,
      );
    }

    return cred;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (cred.user != null) {
      await _upsertUserDoc(cred.user!);
    }

    return cred;
  }

  // GOOGLE LOGIN
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser =
          await _googleSignIn.signIn();

      // User pressed back/cancelled Google login.
      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential =
          GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential cred =
          await _auth.signInWithCredential(credential);

      if (cred.user != null) {
        await _upsertUserDoc(
          cred.user!,
          name: googleUser.displayName,
        );
      }

      return cred;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'Firebase Google login error: ${e.code}: ${e.message}',
      );
      rethrow;
    } catch (e) {
      debugPrint('Google login error: $e');
      rethrow;
    }
  }

  Future<UserCredential> signInAnonymously({
    String guestName = 'Guest',
  }) async {
    final cred = await _auth.signInAnonymously();

    await cred.user?.updateDisplayName(guestName);

    if (cred.user != null) {
      await _upsertUserDoc(
        cred.user!,
        name: guestName,
        anon: true,
      );
    }

    return cred;
  }

  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;

    if (uid != null) {
      await _db.collection('users').doc(uid).update({
        'isOnline': false,
        'lastSeen': DateTime.now().toIso8601String(),
      });
    }

    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    await _auth.signOut();

    notifyListeners();
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(
      email: email,
    );
  }

  Future<void> updateProfile({
    String? name,
    String? photoUrl,
  }) async {
    final user = _auth.currentUser;

    if (user == null) return;

    if (name != null && name.trim().isNotEmpty) {
      await user.updateDisplayName(name.trim());
    }

    if (photoUrl != null) {
      await user.updatePhotoURL(photoUrl);
    }

    await user.reload();

    await _db.collection('users').doc(user.uid).set({
      if (name != null && name.trim().isNotEmpty)
        'name': name.trim(),
      if (photoUrl != null)
        'photoUrl': photoUrl,
      'lastSeen': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));

    // The rest of the app never reads `users/{uid}` live for a person's
    // name/photo inside a chat — every chat doc keeps its own denormalized
    // copy (`participantNames.$uid` / `participantPhotos.$uid`) captured
    // at the moment the chat was created, purely so the chat list/inbox
    // doesn't need an extra read per participant. That's exactly why a
    // profile photo/name change wasn't showing up anywhere except (after
    // a full app restart) your own device: nothing was pushing the new
    // values into those existing chat docs. This does that now, for every
    // chat you're part of, so every other participant's chat list, chat
    // inbox, and group member list picks up the change live over the
    // Firestore listeners they already have open.
    if ((name != null && name.trim().isNotEmpty) || photoUrl != null) {
      await _propagateProfileToChats(
        uid: user.uid,
        name: name?.trim(),
        photoUrl: photoUrl,
      );
    }

    notifyListeners();
  }

  /// Patches every chat doc this user participates in with their latest
  /// name/photo. Batched in chunks of 400 writes (Firestore's batch limit
  /// is 500; 400 leaves headroom since each chat contributes up to 2
  /// field updates) so this still works for accounts with a very large
  /// number of chats.
  Future<void> _propagateProfileToChats({
    required String uid,
    String? name,
    String? photoUrl,
  }) async {
    final chats = await _db
        .collection('chats')
        .where('participantIds', arrayContains: uid)
        .get();

    if (chats.docs.isEmpty) return;

    const chunkSize = 200; // 200 docs * up to 2 field writes = 400 writes
    for (var i = 0; i < chats.docs.length; i += chunkSize) {
      final chunk = chats.docs.skip(i).take(chunkSize);
      final batch = _db.batch();
      for (final doc in chunk) {
        final updates = <String, dynamic>{};
        if (name != null) updates['participantNames.$uid'] = name;
        if (photoUrl != null) updates['participantPhotos.$uid'] = photoUrl;
        if (updates.isNotEmpty) batch.update(doc.reference, updates);
      }
      await batch.commit();
    }
  }
}