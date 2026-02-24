import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appLifecycleServiceProvider = Provider<AppLifecycleService>((ref) {
  return AppLifecycleService();
});

class AppLifecycleService with WidgetsBindingObserver {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  void init() {
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final user = _auth.currentUser;
    if (user == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _updateUserStatus(user.uid, isOnline: true);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _updateUserStatus(user.uid, isOnline: false);
        break;
      case AppLifecycleState.hidden:
        // TODO: Handle this case.
        break;
    }
  }

  Future<void> _updateUserStatus(String uid, {required bool isOnline}) async {
    try {
      final userDocRef = _firestore.collection('users').doc(uid);
      final updateData = {
        'status': isOnline ? 'online' : 'offline',
        'lastSeen': FieldValue.serverTimestamp(),
      };
      await userDocRef.update(updateData);
    } catch (e) {
      debugPrint("Error updating user status: $e");
    }
  }
}
