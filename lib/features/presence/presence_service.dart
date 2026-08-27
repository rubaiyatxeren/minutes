import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

/// Keeps `users/{uid}.isOnline` / `.lastSeen` in sync with the app's actual
/// lifecycle state.
///
/// Previously `isOnline` was only ever flipped on explicit sign-in/sign-out
/// (see AuthService), so someone who backgrounded the app — or had it
/// killed by the OS — stayed "Online" forever from everyone else's point of
/// view. Hooking WidgetsBindingObserver fixes that: resumed -> online,
/// anything else (paused/inactive/hidden/detached) -> offline with a fresh
/// lastSeen timestamp for "Last seen 3m ago" to work off of.
class PresenceService with WidgetsBindingObserver {
  final _db = FirebaseFirestore.instance;
  bool _attached = false;

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  void attach() {
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
    setOnline();
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    WidgetsBinding.instance.removeObserver(this);
    setOffline();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setOnline();
    } else {
      // paused, inactive, hidden, or detached — treat all as "not actively
      // using the app right now".
      setOffline();
    }
  }

  void setOnline() {
    _userDoc?.set({
      'isOnline': true,
      'lastSeen': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  void setOffline() {
    _userDoc?.set({
      'isOnline': false,
      'lastSeen': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }
}
