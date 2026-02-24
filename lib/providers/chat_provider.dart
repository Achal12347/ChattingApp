import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group_model.dart';
import '../services/chat_preferences_service.dart';
import '../services/chat_service.dart';
import '../services/relationship_service.dart';
import 'auth_provider.dart';
import 'message_provider.dart';
import 'relationship_provider.dart';

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

final chatsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('chats')
      .where('participants', arrayContains: user.uid)
      .orderBy('lastMessageAt', descending: true)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
      );
});

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

    final snapshot = await FirebaseFirestore.instance
        .collection('groups')
        .where('participants', arrayContains: _userId)
        .orderBy('lastMessageAt', descending: true)
        .get();

    state = snapshot.docs
        .map((doc) => GroupModel.fromMap({'id': doc.id, ...doc.data()}))
        .toList();
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
      'participants': FieldValue.arrayUnion([userId])
    });
    await _loadGroups();
  }

  Future<void> leaveGroup(String groupId, String userId) async {
    final groupRef =
        FirebaseFirestore.instance.collection('groups').doc(groupId);
    await groupRef.update({
      'participants': FieldValue.arrayRemove([userId])
    });
    await _loadGroups();
  }

  Future<void> addGroupAdmin(String groupId, String userId) async {
    final groupRef =
        FirebaseFirestore.instance.collection('groups').doc(groupId);
    await groupRef.update({
      'admins': FieldValue.arrayUnion([userId])
    });
    await _loadGroups();
  }

  Future<void> removeGroupAdmin(String groupId, String userId) async {
    final groupRef =
        FirebaseFirestore.instance.collection('groups').doc(groupId);
    await groupRef.update({
      'admins': FieldValue.arrayRemove([userId])
    });
    await _loadGroups();
  }

  Future<void> muteGroup(String groupId, String userId) async {
    final groupRef =
        FirebaseFirestore.instance.collection('groups').doc(groupId);
    await groupRef.update({'mutedUsers.$userId': true});
    await _loadGroups();
  }

  Future<void> unmuteGroup(String groupId, String userId) async {
    final groupRef =
        FirebaseFirestore.instance.collection('groups').doc(groupId);
    await groupRef.update({'mutedUsers.$userId': false});
    await _loadGroups();
  }

  Future<void> archiveGroup(String groupId) async {
    final groupRef =
        FirebaseFirestore.instance.collection('groups').doc(groupId);
    await groupRef.update({'isArchived': true});
    await _loadGroups();
  }

  Future<void> unarchiveGroup(String groupId) async {
    final groupRef =
        FirebaseFirestore.instance.collection('groups').doc(groupId);
    await groupRef.update({'isArchived': false});
    await _loadGroups();
  }

  bool isGroupAdmin(String groupId, String userId) {
    final group = state.firstWhere(
      (g) => g.id == groupId,
      orElse: () => GroupModel(
        id: '',
        name: '',
        description: '',
        adminId: '',
        participants: const [],
        admins: const [],
        createdAt: DateTime.now(),
        lastMessage: '',
        lastMessageAt: DateTime.now(),
      ),
    );
    return group.admins.contains(userId);
  }

  bool isGroupMuted(String groupId, String userId) {
    final group = state.firstWhere(
      (g) => g.id == groupId,
      orElse: () => GroupModel(
        id: '',
        name: '',
        description: '',
        adminId: '',
        participants: const [],
        admins: const [],
        createdAt: DateTime.now(),
        lastMessage: '',
        lastMessageAt: DateTime.now(),
      ),
    );
    return group.mutedUsers[userId] ?? false;
  }
}

final chatPreferencesServiceProvider = Provider<ChatPreferencesService>((ref) {
  return ChatPreferencesService();
});

final chatPreferencesProvider =
    StateNotifierProvider<ChatPreferencesNotifier, ChatPreferences>((ref) {
  return ChatPreferencesNotifier(ref.watch(chatPreferencesServiceProvider));
});

class ChatPreferencesNotifier extends StateNotifier<ChatPreferences> {
  final ChatPreferencesService _service;

  ChatPreferencesNotifier(this._service) : super(const ChatPreferences()) {
    _load();
  }

  Future<void> _load() async {
    state = await _service.load();
  }

  Future<void> _persist() async {
    await _service.save(state);
  }

  bool isPinned(String chatId) => state.pinnedChats.contains(chatId);

  bool isArchived(String chatId) => state.archivedChats.contains(chatId);

  bool isMuted(String chatId) => state.mutedChats.contains(chatId);

  Future<void> togglePinned(String chatId) async {
    final updated = [...state.pinnedChats];
    if (updated.contains(chatId)) {
      updated.remove(chatId);
    } else {
      updated.add(chatId);
    }
    state = state.copyWith(pinnedChats: updated);
    await _persist();
  }

  Future<void> toggleArchived(String chatId) async {
    final updatedArchived = [...state.archivedChats];
    final updatedPinned = [...state.pinnedChats];

    if (updatedArchived.contains(chatId)) {
      updatedArchived.remove(chatId);
    } else {
      updatedArchived.add(chatId);
      updatedPinned.remove(chatId);
    }

    state = state.copyWith(
      archivedChats: updatedArchived,
      pinnedChats: updatedPinned,
    );
    await _persist();
  }

  Future<void> toggleMuted(String chatId) async {
    final updated = [...state.mutedChats];
    if (updated.contains(chatId)) {
      updated.remove(chatId);
    } else {
      updated.add(chatId);
    }
    state = state.copyWith(mutedChats: updated);
    await _persist();
  }

  Future<void> clearAll() async {
    state = const ChatPreferences();
    await _persist();
  }
}

final pinnedChatsProvider = Provider<List<String>>((ref) {
  return ref.watch(chatPreferencesProvider).pinnedChats;
});

final archivedChatsProvider = Provider<List<String>>((ref) {
  return ref.watch(chatPreferencesProvider).archivedChats;
});

final mutedChatsProvider = Provider<List<String>>((ref) {
  return ref.watch(chatPreferencesProvider).mutedChats;
});

final blockedUsersProvider =
    StateNotifierProvider<BlockedUsersNotifier, List<String>>((ref) {
  final relationshipService = ref.watch(relationshipServiceProvider);
  return BlockedUsersNotifier(relationshipService);
});

final isBlockedByProvider =
    FutureProvider.family<bool, String>((ref, blockerId) async {
  final relationshipService = ref.watch(relationshipServiceProvider);
  return relationshipService.isCurrentUserBlockedBy(blockerId);
});

class BlockedUsersNotifier extends StateNotifier<List<String>> {
  final RelationshipService _relationshipService;

  BlockedUsersNotifier(this._relationshipService) : super([]) {
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    state = await _relationshipService.getBlockedUsers();
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

  bool isUserBlocked(String userId) => state.contains(userId);

  Future<String?> getBlockReason(String userId) async {
    return _relationshipService.getBlockReason(userId);
  }
}
