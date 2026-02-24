import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../models/message_model.dart';
import '../services/firebase_storage_service.dart';
import 'auth_provider.dart';
import 'chat_provider.dart';

final appDatabaseProvider =
    Provider<AppDatabase>((ref) => AppDatabase.instance);

final messagesProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, chatId) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);

  final db = ref.watch(appDatabaseProvider);
  return db.watchChat(chatId).map((driftMessages) {
    return driftMessages.map(MessageModel.fromDrift).toList();
  });
});

final groupMessagesProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, groupId) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);

  return FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .collection('messages')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) =>
                MessageModel.fromMap({'chatId': groupId, ...doc.data()}))
            .toList(),
      );
});

final pendingMessageCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchPendingMessageCount();
});

final sendGroupMessageProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, params) async {
  final chatService = ref.watch(chatServiceProvider);
  await chatService.sendGroupMessage(
    groupId: params['groupId'] as String,
    senderId: params['senderId'] as String,
    content: (params['content'] as String?) ?? '',
    mediaUrl: params['mediaUrl'] as String?,
    mediaType: params['mediaType'] as String?,
    replyToMessageId: params['replyToMessageId'] as String?,
  );
});

final sendMessageProvider =
    FutureProvider.family<bool, Map<String, dynamic>>((ref, params) async {
  final chatService = ref.watch(chatServiceProvider);
  await chatService.sendMessage(
    chatId: params['chatId'] as String,
    senderId: params['senderId'] as String,
    receiverId: params['receiverId'] as String,
    content: params['content'] as String,
    replyToMessageId: params['replyToMessageId'] as String?,
  );
  return true;
});

final sendMediaMessageProvider =
    FutureProvider.family<bool, Map<String, dynamic>>((ref, params) async {
  final chatService = ref.watch(chatServiceProvider);
  await chatService.sendMediaMessage(
    chatId: params['chatId'] as String,
    senderId: params['senderId'] as String,
    receiverId: params['receiverId'] as String,
    mediaUrl: params['mediaUrl'] as String,
    mediaType: params['mediaType'] as String,
    caption: params['caption'] as String?,
    replyToMessageId: params['replyToMessageId'] as String?,
  );
  return true;
});

final markAsReadProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, params) async {
  final chatService = ref.watch(chatServiceProvider);
  await chatService.markMessageAsRead(
    params['chatId'] as String,
    params['messageId'] as String,
  );
});

final deleteMessageProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, params) async {
  final chatService = ref.watch(chatServiceProvider);
  await chatService.deleteMessage(
    params['chatId'] as String,
    params['messageId'] as String,
    params['deleteForEveryone'] as bool,
  );
});

final addReactionProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, params) async {
  final chatService = ref.watch(chatServiceProvider);
  final isGroupChat = (params['isGroupChat'] as bool?) ?? false;

  if (isGroupChat) {
    await chatService.addGroupReaction(
      params['chatId'] as String,
      params['messageId'] as String,
      params['emoji'] as String,
    );
    return;
  }

  await chatService.addReaction(
    params['chatId'] as String,
    params['messageId'] as String,
    params['emoji'] as String,
  );
});

final firebaseStorageServiceProvider = Provider<FirebaseStorageService>((ref) {
  return FirebaseStorageService();
});
