import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/group_model.dart';

final groupServiceProvider = Provider<GroupService>((ref) => GroupService());

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<GroupModel?> createGroup(
      String name, List<String> participantIds) async {
    try {
      final groupId = const Uuid().v4();
      final group = GroupModel(
        id: groupId,
        name: name,
        participants: participantIds,
        admins: [participantIds.first],
        adminId: participantIds.first,
        createdAt: DateTime.now(),
        lastMessage: '',
        lastMessageAt: DateTime.now(),
      );

      await _firestore
          .collection('groups')
          .doc(groupId)
          .set(group.toMap());

      return group;
    } catch (e) {
      print('Error creating group: $e');
      return null;
    }
  }

  /// Generate invite link for a group
  Future<String> generateInviteLink(String groupId) async {
    final inviteCode = const Uuid().v4().substring(0, 8).toUpperCase();

    // Store invite code in Firestore
    await _firestore.collection('group_invites').doc(inviteCode).set({
      'groupId': groupId,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt':
          DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      'isActive': true,
    });

    return inviteCode;
  }

  /// Join group using invite code
  Future<GroupModel?> joinGroupWithInvite(
      String inviteCode, String userId) async {
    try {
      // Get invite document
      final inviteDoc =
          await _firestore.collection('group_invites').doc(inviteCode).get();

      if (!inviteDoc.exists) {
        throw Exception('Invalid invite code');
      }

      final inviteData = inviteDoc.data()!;
      final groupId = inviteData['groupId'] as String;
      final isActive = inviteData['isActive'] as bool;
      final expiresAt = DateTime.parse(inviteData['expiresAt'] as String);

      // Check if invite is still valid
      if (!isActive || DateTime.now().isAfter(expiresAt)) {
        throw Exception('Invite code has expired');
      }

      // Get group document
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();

      if (!groupDoc.exists) {
        throw Exception('Group not found');
      }

      final groupData = groupDoc.data()!;
      final participants = List<String>.from(groupData['participants'] ?? []);

      // Check if user is already a member
      if (participants.contains(userId)) {
        throw Exception('You are already a member of this group');
      }

      // Add user to group
      participants.add(userId);
      await _firestore.collection('groups').doc(groupId).update({
        'participants': participants,
      });

      // Return updated group model
      return GroupModel.fromMap({
        ...groupData,
        'participants': participants,
      });
    } catch (e) {
      throw Exception('Failed to join group: $e');
    }
  }

  /// Get group details by ID
  Future<GroupModel?> getGroupById(String groupId) async {
    try {
      final doc = await _firestore.collection('groups').doc(groupId).get();
      if (doc.exists) {
        return GroupModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get group: $e');
    }
  }

  /// Add member to group (admin only)
  Future<void> addMemberToGroup(
      String groupId, String adminId, String newMemberId) async {
    final group = await getGroupById(groupId);
    if (group == null) {
      throw Exception('Group not found');
    }

    if (!group.admins.contains(adminId)) {
      throw Exception('Only admins can add members');
    }

    if (group.participants.contains(newMemberId)) {
      throw Exception('User is already a member');
    }

    final updatedParticipants = [...group.participants, newMemberId];
    await _firestore.collection('groups').doc(groupId).update({
      'participants': updatedParticipants,
    });
  }

  /// Remove member from group (admin only)
  Future<void> removeMemberFromGroup(
      String groupId, String adminId, String memberId) async {
    final group = await getGroupById(groupId);
    if (group == null) {
      throw Exception('Group not found');
    }

    if (!group.admins.contains(adminId)) {
      throw Exception('Only admins can remove members');
    }

    if (group.adminId == memberId) {
      throw Exception('Cannot remove group creator');
    }

    final updatedParticipants =
        group.participants.where((id) => id != memberId).toList();
    await _firestore.collection('groups').doc(groupId).update({
      'participants': updatedParticipants,
    });
  }

  /// Make user admin (admin only)
  Future<void> makeAdmin(
      String groupId, String adminId, String newAdminId) async {
    final group = await getGroupById(groupId);
    if (group == null) {
      throw Exception('Group not found');
    }

    if (!group.admins.contains(adminId)) {
      throw Exception('Only admins can promote members');
    }

    if (!group.participants.contains(newAdminId)) {
      throw Exception('User must be a member first');
    }

    final updatedAdmins = [...group.admins, newAdminId];
    await _firestore.collection('groups').doc(groupId).update({
      'admins': updatedAdmins,
    });
  }

  /// Remove admin privileges (group creator only)
  Future<void> removeAdmin(
      String groupId, String creatorId, String adminId) async {
    final group = await getGroupById(groupId);
    if (group == null) {
      throw Exception('Group not found');
    }

    if (group.adminId != creatorId) {
      throw Exception('Only group creator can remove admin privileges');
    }

    if (adminId == creatorId) {
      throw Exception('Cannot remove your own admin privileges');
    }

    final updatedAdmins = group.admins.where((id) => id != adminId).toList();
    await _firestore.collection('groups').doc(groupId).update({
      'admins': updatedAdmins,
    });
  }

  /// Leave group
  Future<void> leaveGroup(String groupId, String userId) async {
    final group = await getGroupById(groupId);
    if (group == null) {
      throw Exception('Group not found');
    }

    if (group.adminId == userId) {
      throw Exception('Group creator cannot leave the group');
    }

    final updatedParticipants =
        group.participants.where((id) => id != userId).toList();
    final updatedAdmins = group.admins.where((id) => id != userId).toList();

    await _firestore.collection('groups').doc(groupId).update({
      'participants': updatedParticipants,
      'admins': updatedAdmins,
    });
  }

  /// Delete group (creator only)
  Future<void> deleteGroup(String groupId, String userId) async {
    final group = await getGroupById(groupId);
    if (group == null) {
      throw Exception('Group not found');
    }

    if (group.adminId != userId) {
      throw Exception('Only group creator can delete the group');
    }

    // Delete group document
    await _firestore.collection('groups').doc(groupId).delete();

    // Delete all messages in the group
    final messagesSnapshot = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .get();

    for (final doc in messagesSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete invite links
    final invitesSnapshot = await _firestore
        .collection('group_invites')
        .where('groupId', isEqualTo: groupId)
        .get();

    for (final doc in invitesSnapshot.docs) {
      await doc.reference.delete();
    }
  }
}
