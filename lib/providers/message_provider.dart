import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../database/app_database.dart';
import '../models/message_model.dart';
import '../services/firebase_storage_service.dart';

import 'auth_provider.dart';
import 'chat_provider.dart';

// Provider for the AppDatabase instance
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

// Messages stream provider for a specific chat
final messagesProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, chatId) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    print('messagesProvider: user is null, returning empty stream');
    return Stream.value([]);
  }

  print(
      'messagesProvider: subscribing to messages for chatId=$chatId from local DB');

  final db = ref.watch(appDatabaseProvider);
  return db.watchChat(chatId).map((driftMessages) {
    final messages =
        driftMessages.map((msg) => MessageModel.fromDrift(msg)).toList();
    print(
        'messagesProvider: received ${messages.length} messages for chatId=$chatId from local DB');
    for (final msg in messages) {
      print(
          'messagesProvider: message id=${msg.id}, content=${msg.content}, sender=${msg.senderId}');
    }
    return messages;
  });
});

// Group messages stream provider for a specific group
final groupMessagesProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, groupId) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .collection('messages')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => MessageModel.fromMap(doc.data()))
          .toList());
});

// Send group message provider
final sendGroupMessageProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, params) async {
  final chatService = ref.watch(chatServiceProvider);
  final groupId = params['groupId'] as String;
  final senderId = params['senderId'] as String;
  final content = params['content'] as String;

  await chatService.sendGroupMessage(
    groupId: groupId,
    senderId: senderId,
    content: content,
  );
});

// Send message provider
final sendMessageProvider =
    FutureProvider.family<bool, Map<String, dynamic>>((ref, params) async {
  final chatService = ref.watch(chatServiceProvider);
  final chatId = params['chatId'] as String;
  final senderId = params['senderId'] as String;
  final receiverId = params['receiverId'] as String;
  final content = params['content'] as String;

  await chatService.sendMessage(
    chatId: chatId,
    senderId: senderId,
    receiverId: receiverId,
    content: content,
  );
  return true;
});

// Send media message provider
final sendMediaMessageProvider =
    FutureProvider.family<bool, Map<String, dynamic>>((ref, params) async {
  final chatService = ref.watch(chatServiceProvider);
  final chatId = params['chatId'] as String;
  final senderId = params['senderId'] as String;
  final receiverId = params['receiverId'] as String;
  final mediaUrl = params['mediaUrl'] as String;
  final mediaType = params['mediaType'] as String;
  final caption = params['caption'] as String?;

  await chatService.sendMediaMessage(
    chatId: chatId,
    senderId: senderId,
    receiverId: receiverId,
    mediaUrl: mediaUrl,
    mediaType: mediaType,
    caption: caption,
  );
  return true;
});

// Mark message as read
final markAsReadProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, params) async {
  final chatId = params['chatId'] as String;
  final messageId = params['messageId'] as String;
  final user = ref.watch(authStateProvider).value;
  if (user == null) return;

  // Update in Firestore
  await FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .doc(messageId)
      .update({
    'isRead': true,
    'readAt': FieldValue.serverTimestamp(),
  });
});

// Delete message
final deleteMessageProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, params) async {
  final chatId = params['chatId'] as String;
  final messageId = params['messageId'] as String;
  final deleteForEveryone = params['deleteForEveryone'] as bool;

  if (deleteForEveryone) {
    // Delete from Firestore
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .delete();
  } else {
    // Mark as deleted for current user (would need user-specific logic)
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'isDeleted': true,
    });
  }
});

// Add reaction to message
final addReactionProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, params) async {
  final chatId = params['chatId'] as String;
  final messageId = params['messageId'] as String;
  final emoji = params['emoji'] as String;

  final messageRef = FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .doc(messageId);
  await messageRef.update({
    'reactions': FieldValue.arrayUnion([emoji]),
  });
});

// Firebase Storage Service Provider
final firebaseStorageServiceProvider = Provider<FirebaseStorageService>((ref) {
  return FirebaseStorageService();
});
