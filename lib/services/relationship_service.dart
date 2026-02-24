import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/unblock_request_model.dart';

class RelationshipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ Set relationship with another user
  Future<void> setRelationship(String targetUserId, String tag) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final relationshipDoc = _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('relationships')
        .doc(targetUserId);

    final docSnapshot = await relationshipDoc.get();
    if (docSnapshot.exists) {
      // Update existing
      await relationshipDoc.update({
        'tag': tag,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Create new
      await relationshipDoc.set({
        'tag': tag,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// ✅ Get relationship with another user
  Future<String?> getRelationship(String targetUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    final relationshipDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('relationships')
        .doc(targetUserId)
        .get();

    return relationshipDoc.data()?['tag'] as String?;
  }

  /// ✅ Get all relationships
  Future<Map<String, String>> getAllRelationships() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return {};

    final relationshipsSnapshot = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('relationships')
        .get();

    final relationships = <String, String>{};
    for (final doc in relationshipsSnapshot.docs) {
      relationships[doc.id] = doc.data()['tag'] as String;
    }

    return relationships;
  }

  /// ✅ Remove relationship
  Future<void> removeRelationship(String targetUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('relationships')
        .doc(targetUserId)
        .delete();
  }

  /// ✅ Block user
  Future<void> blockUser(String targetUserId, String reason) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await _firestore.collection('users').doc(currentUser.uid).update({
      'blockedUsers': FieldValue.arrayUnion([targetUserId]),
      'blockReasons.$targetUserId': reason,
    });
  }

  /// ✅ Unblock user
  Future<void> unblockUser(String targetUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await _firestore.collection('users').doc(currentUser.uid).update({
      'blockedUsers': FieldValue.arrayRemove([targetUserId]),
      'blockReasons.$targetUserId': FieldValue.delete(),
    });
  }

  /// ✅ Check if user is blocked
  Future<bool> isUserBlocked(String targetUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    final userDoc =
        await _firestore.collection('users').doc(currentUser.uid).get();
    final blockedUsers = userDoc.data()?['blockedUsers'] as List<dynamic>?;

    return blockedUsers?.contains(targetUserId) ?? false;
  }

  /// ✅ Check if current user is blocked by another user
  Future<bool> isCurrentUserBlockedBy(String blockerId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    final blockerDoc =
        await _firestore.collection('users').doc(blockerId).get();
    final blockedUsers = blockerDoc.data()?['blockedUsers'] as List<dynamic>?;

    return blockedUsers?.contains(currentUser.uid) ?? false;
  }

  /// ✅ Get blocked users
  Future<List<String>> getBlockedUsers() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    final userDoc =
        await _firestore.collection('users').doc(currentUser.uid).get();
    final blockedUsers = userDoc.data()?['blockedUsers'] as List<dynamic>?;

    return blockedUsers?.map((user) => user as String).toList() ?? [];
  }

  /// ✅ Get block reason
  Future<String?> getBlockReason(String blockedUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    final userDoc =
        await _firestore.collection('users').doc(currentUser.uid).get();
    final blockReasons =
        userDoc.data()?['blockReasons'] as Map<String, dynamic>?;

    return blockReasons?[blockedUserId] as String?;
  }

  /// ✅ Send unblock request
  Future<void> sendUnblockRequest(String toUserId, {String? message}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final requestRef = _firestore.collection('unblockRequests').doc();
    final newRequest = UnblockRequestModel(
      id: requestRef.id,
      fromUserId: currentUser.uid,
      toUserId: toUserId,
      message: message,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await requestRef.set(newRequest.toMap());
  }

  /// ✅ Get unblock requests
  Future<List<UnblockRequestModel>> getUnblockRequests() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    final querySnapshot = await _firestore
        .collection('unblockRequests')
        .where('toUserId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .get();

    return querySnapshot.docs
        .map((doc) => UnblockRequestModel.fromMap(doc.data()))
        .toList();
  }

  /// ✅ Accept unblock request
  Future<void> acceptUnblockRequest(String requestId) async {
    final requestDoc = _firestore.collection('unblockRequests').doc(requestId);
    final requestSnapshot = await requestDoc.get();
    final requestData = requestSnapshot.data();

    if (requestData != null) {
      final fromUserId = requestData['fromUserId'];
      await unblockUser(fromUserId);
      await requestDoc.update({'status': 'accepted'});
    }
  }

  /// ✅ Reject unblock request
  Future<void> rejectUnblockRequest(String requestId) async {
    await _firestore
        .collection('unblockRequests')
        .doc(requestId)
        .update({'status': 'rejected'});
  }

  /// ✅ Check unblock request limit
  Future<bool> checkUnblockRequestLimit(String toUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    final relationship = await getRelationshipTag(toUserId, currentUser.uid);
    final limit = {
          'friend': 2,
          'best_friend': 4,
          'family': 999, // unlimited
        }[relationship] ??
        1;

    final querySnapshot = await _firestore
        .collection('unblockRequests')
        .where('fromUserId', isEqualTo: currentUser.uid)
        .where('toUserId', isEqualTo: toUserId)
        .get();

    return querySnapshot.docs.length < limit;
  }

  /// Set relationship tag
  Future<void> setRelationshipTag(
    String currentUserId,
    String otherUserId,
    String tag,
  ) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('relationships')
        .doc(otherUserId)
        .set({
      'tag': tag,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Fetch relationship tag
  Future<String?> getRelationshipTag(
      String currentUserId, String otherUserId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('relationships')
        .doc(otherUserId)
        .get();

    return doc.exists ? doc['tag'] as String : null;
  }

  /// Get username for a user ID
  Future<String?> getUsername(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data()?['username'] as String? ?? 'Unknown User';
    } catch (e) {
      return 'User: $userId';
    }
  }
}
