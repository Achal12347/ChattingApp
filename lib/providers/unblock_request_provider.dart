import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/unblock_request_model.dart';
import '../services/relationship_service.dart';

final unblockRequestProvider = ChangeNotifierProvider((ref) {
  return UnblockRequestProvider();
});

// Stream provider for real-time unblock requests
final unblockRequestsStreamProvider =
    StreamProvider<List<UnblockRequestModel>>((ref) {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('unblockRequests')
      .where('toUserId', isEqualTo: currentUser.uid)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => UnblockRequestModel.fromMap(doc.data()))
          .toList());
});

class UnblockRequestProvider with ChangeNotifier {
  final RelationshipService _relationshipService = RelationshipService();
  List<UnblockRequestModel> _unblockRequests = [];

  List<UnblockRequestModel> get unblockRequests => _unblockRequests;

  Future<void> fetchUnblockRequests() async {
    _unblockRequests = await _relationshipService.getUnblockRequests();
    notifyListeners();
  }

  Future<void> acceptUnblockRequest(String requestId) async {
    await _relationshipService.acceptUnblockRequest(requestId);
    _unblockRequests.removeWhere((request) => request.id == requestId);
    notifyListeners();
  }

  Future<void> rejectUnblockRequest(String requestId) async {
    await _relationshipService.rejectUnblockRequest(requestId);
    _unblockRequests.removeWhere((request) => request.id == requestId);
    notifyListeners();
  }

  Future<void> sendUnblockRequest(String toUserId, {String? message}) async {
    await _relationshipService.sendUnblockRequest(toUserId, message: message);
  }

  Future<bool> checkUnblockRequestLimit(String toUserId) async {
    return await _relationshipService.checkUnblockRequestLimit(toUserId);
  }
}
