import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionServiceProvider =
    Provider<SessionService>((ref) => SessionService());

class SessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> startSession(String userId) async {
    final sessionRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .doc('active');
    await sessionRef.set({
      'startedAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
      'isActive': true,
    }, SetOptions(merge: true));
  }

  Future<void> touchSession(String userId) async {
    final sessionRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .doc('active');
    await sessionRef.set({
      'lastActiveAt': FieldValue.serverTimestamp(),
      'isActive': true,
    }, SetOptions(merge: true));
  }

  Future<void> endSession(String userId) async {
    final sessionRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .doc('active');
    await sessionRef.set({
      'endedAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
      'isActive': false,
    }, SetOptions(merge: true));
  }
}
