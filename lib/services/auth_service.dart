import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'session_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SessionService _sessionService = SessionService();

  // 🔹 Current Firebase user
  User? get currentUser => _auth.currentUser;

  // 🔹 Sign up with email + password + username
  Future<User?> signup(String email, String password, String username) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user != null) {
        final newUser = UserModel(
          uid: user.uid,
          username: username,
          email: email,
          fullName: '',
          createdAt: DateTime.now(),
          lastSeen: DateTime.now(),
          status: "offline", // Set initial status to offline
        );

        // Save profile in Firestore
        await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Signup failed");
    }
  }

  // 🔹 Login with email + password
  Future<User?> login(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (cred.user != null) {
        await _firestore.collection('users').doc(cred.user!.uid).update({
          'status': 'online',
          'lastSeen': FieldValue.serverTimestamp(),
        });
        await _sessionService.startSession(cred.user!.uid);
      }
      return cred.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Login failed");
    }
  }

  // 🔹 Fetch user profile from Firestore
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception("Failed to fetch user profile: $e");
    }
  }

  // 🔹 Update user profile
  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).update(user.toMap());
    } catch (e) {
      throw Exception("Failed to update profile: $e");
    }
  }

  // 🔹 Logout
  Future<void> logout() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'status': 'offline',
          'lastSeen': FieldValue.serverTimestamp(),
        });
        await _sessionService.endSession(user.uid);
      } catch (e) {
        debugPrint('AuthService: Error updating user status to offline: $e');
      }
    }
    await _auth.signOut();
  }

  // 🔹 Update FCM Token
  Future<void> updateFcmToken(String uid, String fcmToken) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .set({'fcmToken': fcmToken}, SetOptions(merge: true));
    } catch (e) {
      throw Exception("Failed to update FCM token: $e");
    }
  }
}
