import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_model.dart';
import '../services/chat_service.dart';
import '../services/relationship_service.dart';
import 'auth_provider.dart';
import 'message_provider.dart';
import 'relationship_provider.dart';

// ignore: unused_import

// ChatService provider
final chatServiceProvider = Provider<ChatService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ChatService(db);
});

final userChatsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('chats')
      .where('participants', arrayContains: uid)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
});

// Chats stream provider
final chatsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('chats')
      .where('participants', arrayContains: user.uid)
      .orderBy('lastMessageAt', descending: true)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
});

// Groups provider
final groupsProvider =
    StateNotifierProvider<GroupsNotifier, List<GroupModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  return GroupsNotifier(user?.uid);
});

class GroupsNotifier extends StateNotifier<List<GroupModel>> {
  final String? _userId;

  GroupsNotifier(this._userId) : super([]) {
    if (_userId != null) {
      _loadGroups();
    }
  }

  Future<void> _loadGroups() async {
    if (_userId == null) return;
    // Load groups from Firestore, filtered by membership
    final snapshot = await FirebaseFirestore.instance
        .collection('groups')
        .where('participants', arrayContains: _userId)
        .orderBy('lastMessageAt', descending: true)
        .get();
    final groups = snapshot.docs
        .map((doc) => GroupModel.fromMap({'id': doc.id, ...doc.data()}))
        .toList();
    state = groups;
  }

  Future<void> createGroup(GroupModel group) async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(group.id)
        .set(group.toMap());
    state = [...state, group];
  }

  Future<void> joinGroup(String groupId, String userId) async {
    final groupRef =
        FirebaseFirestore.instance.collection('groups').doc(groupId);
    await groupRef.update({
      'participants': FieldValue.arrayUnion([userId]),
    });
    // Refresh groups
    await _loadGroups();
  }

  Future<void> leaveGroup(String groupId, String userId) async {
    final groupRef =
        FirebaseFirestore.instance.collection('groups').doc(groupId);
    await groupRef.update({
      'participants': FieldValue.arrayRemove([userId]),
    });
    // Refresh groups
    await _loadGroups();
  }

  Future<void> addGroupAdmin(String groupId, String userId) async {
    final groupRef =
        FirebaseFirestore.instance.collection('groups').doc(groupId);
    await groupRef.update({
      'admins': FieldValue.arrayUnion([userId]),
    });
    // Refresh groups
    await _loadGroups();
  }

  Future<void> removeGroupAdmin(String groupId, String userId) async {
    final groupRef =
        FirebaseFirestore.instance.collection('groups').doc(groupId);
    await groupRef.update({
      'admins': FieldValue.arrayRemove([userId]),
    });
    // Refresh groups
    await _loadGroups();
  }

  Future<void> muteGroup(String groupId, String userId) async {
    final groupRef =
        FirebaseFirestore.instance.collection('groups').doc(groupId);
    await groupRef.update({
      'mutedUsers.$userId': true,
    });
    // Refresh groups
    await _loadGroups();
  }

  Future<void> unmuteGroup(String groupId, String userId) async {
    final groupRef =
        FirebaseFirestore.instance.collection('groups').doc(groupId);
    await groupRef.update({
      'mutedUsers.$userId': false,
    });
    // Refresh groups
    await _loadGroups();
  }

  Future<void> archiveGroup(String groupId) async {
    final groupRef =
        FirebaseFirestore.instance.collection('groups').doc(groupId);
    await groupRef.update({
      'isArchived': true,
    });
    // Refresh groups
    await _loadGroups();
  }

  Future<void> unarchiveGroup(String groupId) async {
    final groupRef =
        FirebaseFirestore.instance.collection('groups').doc(groupId);
    await groupRef.update({
      'isArchived': false,
    });
    // Refresh groups
    await _loadGroups();
  }

  bool isGroupAdmin(String groupId, String userId) {
    final group = state.firstWhere((g) => g.id == groupId,
        orElse: () => GroupModel(
              id: '',
              name: '',
              description: '',
              adminId: '',
              participants: [],
              admins: [],
              createdAt: DateTime.now(),
              lastMessage: '',
              lastMessageAt: DateTime.now(),
            ));
    return group.admins.contains(userId);
  }

  bool isGroupMuted(String groupId, String userId) {
    final group = state.firstWhere((g) => g.id == groupId,
        orElse: () => GroupModel(
              id: '',
              name: '',
              description: '',
              adminId: '',
              participants: [],
              admins: [],
              createdAt: DateTime.now(),
              lastMessage: '',
              lastMessageAt: DateTime.now(),
            ));
    return group.mutedUsers[userId] ?? false;
  }
}

// Pinned chats provider
final pinnedChatsProvider =
    StateNotifierProvider<PinnedChatsNotifier, List<String>>((ref) {
  return PinnedChatsNotifier();
});

class PinnedChatsNotifier extends StateNotifier<List<String>> {
  PinnedChatsNotifier() : super([]);

  void pinChat(String chatId) {
    if (!state.contains(chatId)) {
      state = [...state, chatId];
    }
  }

  void unpinChat(String chatId) {
    state = state.where((id) => id != chatId).toList();
  }
}

// Archived chats provider
final archivedChatsProvider =
    StateNotifierProvider<ArchivedChatsNotifier, List<String>>((ref) {
  return ArchivedChatsNotifier();
});

class ArchivedChatsNotifier extends StateNotifier<List<String>> {
  ArchivedChatsNotifier() : super([]);

  void archiveChat(String chatId) {
    if (!state.contains(chatId)) {
      state = [...state, chatId];
    }
  }

  void unarchiveChat(String chatId) {
    state = state.where((id) => id != chatId).toList();
  }
}

// Blocked users provider
final blockedUsersProvider =
    StateNotifierProvider<BlockedUsersNotifier, List<String>>((ref) {
  final relationshipService = ref.watch(relationshipServiceProvider);
  return BlockedUsersNotifier(relationshipService);
});

// Is current user blocked by another user provider
final isBlockedByProvider =
    FutureProvider.family<bool, String>((ref, blockerId) async {
  final relationshipService = ref.watch(relationshipServiceProvider);
  return await relationshipService.isCurrentUserBlockedBy(blockerId);
});

class BlockedUsersNotifier extends StateNotifier<List<String>> {
  final RelationshipService _relationshipService;

  BlockedUsersNotifier(this._relationshipService) : super([]) {
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    final blockedUsers = await _relationshipService.getBlockedUsers();
    state = blockedUsers;
  }

  Future<void> blockUser(String userId, String reason) async {
    await _relationshipService.blockUser(userId, reason);
    if (!state.contains(userId)) {
      state = [...state, userId];
    }
  }

  Future<void> unblockUser(String userId) async {
    await _relationshipService.unblockUser(userId);
    state = state.where((id) => id != userId).toList();
  }

  bool isUserBlocked(String userId) {
    return state.contains(userId);
  }

  Future<String?> getBlockReason(String userId) async {
    return await _relationshipService.getBlockReason(userId);
  }
}
