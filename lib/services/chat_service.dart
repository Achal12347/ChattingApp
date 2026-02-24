import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'connectivity_service.dart';
import 'mood_service.dart';
import 'notification_service.dart';
import 'relationship_service.dart';

class ChatService {
  final FirebaseFirestore _firestore;
  final AppDatabase db;
  final ConnectivityService _connectivityService = ConnectivityService();
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _activeSyncs = {};

  ChatService([AppDatabase? database, FirebaseFirestore? firestore])
      : db = database ?? AppDatabase.instance,
        _firestore = firestore ?? FirebaseFirestore.instance {
    _initializeConnectivity();
  }

  void _initializeConnectivity() {
    _connectivityService.initialize();
    _connectivityService.onlineStream.listen((isOnline) {
      if (isOnline) {
        _syncPendingMessages();
      }
    });
  }

  Future<void> sendGroupMessage({
    required String groupId,
    required String senderId,
    required String content,
    String? mediaUrl,
    String? mediaType,
    String? replyToMessageId,
  }) async {
    final uuid = const Uuid().v4();
    final moodService = MoodService();
    final mood = moodService.analyzeMood(content);
    final isUrgent = content.trim().isNotEmpty &&
        moodService.shouldSendUrgentNotification(mood);

    await db.insertMessage(
      MessagesCompanion.insert(
        id: uuid,
        chatId: groupId,
        senderId: senderId,
        receiverId: '',
        content: content,
        mediaUrl: Value(mediaUrl),
        mediaType: Value(mediaType),
        replyToMessageId: Value(replyToMessageId),
        reactionsJson: const Value('[]'),
        isUrgent: Value(isUrgent),
      ),
    );

    if (!isOnline) {
      developer.log('Group message queued offline: $uuid', name: 'ChatService');
      return;
    }

    try {
      await _syncSingleGroupMessage(
        groupId: groupId,
        messageId: uuid,
        senderId: senderId,
        content: content,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        replyToMessageId: replyToMessageId,
        isUrgent: isUrgent,
        reactions: const [],
      );

      await db.markSynced(uuid);

      if (isUrgent) {
        await NotificationService().sendUrgentNotification(
            'Urgent Group Message', moodService.getMoodNotification(mood));
      }
    } catch (e) {
      developer.log('Failed to sync group message $uuid: $e',
          name: 'ChatService');
    }
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String content,
    String? replyToMessageId,
  }) async {
    if (senderId.isEmpty || receiverId.isEmpty) {
      debugPrint(
          'ChatService: sendMessage skipped because sender or receiver is empty');
      return;
    }

    final isBlocked =
        await RelationshipService().isCurrentUserBlockedBy(receiverId);
    if (isBlocked) {
      debugPrint('ChatService: sender $senderId is blocked by $receiverId');
      return;
    }

    final uuid = const Uuid().v4();
    final moodService = MoodService();
    final mood = moodService.analyzeMood(content);
    final isUrgent = content.trim().isNotEmpty &&
        moodService.shouldSendUrgentNotification(mood);

    await db.insertMessage(
      MessagesCompanion.insert(
        id: uuid,
        chatId: chatId,
        senderId: senderId,
        receiverId: receiverId,
        content: content,
        replyToMessageId: Value(replyToMessageId),
        reactionsJson: const Value('[]'),
        isUrgent: Value(isUrgent),
      ),
    );

    if (!isOnline) {
      developer.log('Direct message queued offline: $uuid',
          name: 'ChatService');
      return;
    }

    try {
      await _syncSingleDirectMessage(
        chatId: chatId,
        messageId: uuid,
        senderId: senderId,
        receiverId: receiverId,
        content: content,
        mediaUrl: null,
        mediaType: null,
        replyToMessageId: replyToMessageId,
        isUrgent: isUrgent,
        reactions: const [],
      );

      await db.markSynced(uuid);

      if (isUrgent) {
        await NotificationService().sendUrgentNotification(
            'Urgent Message', moodService.getMoodNotification(mood));
      }
    } catch (e) {
      developer.log('Failed to sync direct message $uuid: $e',
          name: 'ChatService');
    }
  }

  Future<void> _syncSingleDirectMessage({
    required String chatId,
    required String messageId,
    required String senderId,
    required String receiverId,
    required String content,
    required String? mediaUrl,
    required String? mediaType,
    required String? replyToMessageId,
    required bool isUrgent,
    required List<String> reactions,
  }) async {
    await ensureChatExists(chatId, [senderId, receiverId]);

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .set({
      'id': messageId,
      'chatId': chatId,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'replyToMessageId': replyToMessageId,
      'reactions': reactions,
      'isUrgent': isUrgent,
      'status': 'sent',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('chats').doc(chatId).set({
      'lastMessage': _buildPreview(content: content, mediaType: mediaType),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCount.$receiverId': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  Future<void> _syncSingleGroupMessage({
    required String groupId,
    required String messageId,
    required String senderId,
    required String content,
    required String? mediaUrl,
    required String? mediaType,
    required String? replyToMessageId,
    required bool isUrgent,
    required List<String> reactions,
  }) async {
    await ensureGroupExists(groupId);

    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .doc(messageId)
        .set({
      'id': messageId,
      'chatId': groupId,
      'senderId': senderId,
      'receiverId': '',
      'content': content,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'replyToMessageId': replyToMessageId,
      'reactions': reactions,
      'isUrgent': isUrgent,
      'status': 'sent',
      'readBy': <String>[senderId],
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('groups').doc(groupId).set({
      'lastMessage': _buildPreview(content: content, mediaType: mediaType),
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _buildPreview({required String content, String? mediaType}) {
    if (content.trim().isNotEmpty) return content.trim();
    switch (mediaType) {
      case 'voice':
        return 'Voice note';
      case 'image':
        return 'Photo';
      case 'file':
        return 'Attachment';
      default:
        return 'Message';
    }
  }

  void syncMessages(String chatId, String currentUserId) {
    if (chatId.isEmpty || _activeSyncs.containsKey(chatId)) return;

    final subscription = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .listen((snapshot) async {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final id = data['id']?.toString() ?? doc.id;
        final reactions =
            List<String>.from(data['reactions'] ?? const <String>[]);

        await db.insertMessage(
          MessagesCompanion.insert(
            id: id,
            chatId: chatId,
            senderId: data['senderId']?.toString() ?? '',
            receiverId: data['receiverId']?.toString() ?? '',
            content: data['content']?.toString() ?? '',
            mediaUrl: Value(data['mediaUrl']?.toString()),
            mediaType: Value(data['mediaType']?.toString()),
            replyToMessageId: Value(data['replyToMessageId']?.toString()),
            reactionsJson: Value(jsonEncode(reactions)),
            deletedForEveryone:
                Value((data['deletedForEveryone'] as bool?) ?? false),
            isDeleted: Value((data['isDeleted'] as bool?) ?? false),
            isUrgent: Value((data['isUrgent'] as bool?) ?? false),
            status: Value(data['status']?.toString() ?? 'sent'),
            isSynced: const Value(true),
            createdAt: Value(
              (data['createdAt'] is Timestamp)
                  ? (data['createdAt'] as Timestamp).toDate()
                  : DateTime.now(),
            ),
          ),
        );

        if (data['senderId'] != currentUserId && data['status'] != 'read') {
          await _firestore
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .doc(id)
              .set({'status': 'delivered'}, SetOptions(merge: true));

          final senderId = data['senderId']?.toString() ?? '';
          if (senderId.isNotEmpty) {
            final userDoc =
                await _firestore.collection('users').doc(senderId).get();
            final username =
                userDoc.data()?['username']?.toString() ?? 'Unknown User';
            await NotificationService.instance
                ?.sendNewMessageNotificationWithUsername(
                    username, senderId, data['content']?.toString() ?? '');
          }
        }
      }
    }, onError: (error) {
      debugPrint('ChatService.syncMessages error for $chatId: $error');
    });

    _activeSyncs[chatId] = subscription;
  }

  Future<void> ensureGroupExists(String groupId) async {
    final groupRef = _firestore.collection('groups').doc(groupId);
    final groupDoc = await groupRef.get();
    if (!groupDoc.exists) {
      developer.log('Group document does not exist: $groupId',
          name: 'ChatService');
    }
  }

  Future<void> ensureChatExists(
    String chatId,
    List<String> participants, {
    List<String>? participantUsernames,
  }) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();

    if (!chatDoc.exists) {
      final unreadCount = <String, int>{for (final p in participants) p: 0};
      final usernames = participantUsernames ?? <String>[];

      if (usernames.isEmpty) {
        for (final uid in participants) {
          if (uid.isEmpty) {
            usernames.add('Unknown User');
            continue;
          }
          try {
            final userDoc = await _firestore.collection('users').doc(uid).get();
            usernames
                .add(userDoc.data()?['username']?.toString() ?? 'Unknown User');
          } catch (_) {
            usernames.add('Unknown User');
          }
        }
      }

      await chatRef.set({
        'chatId': chatId,
        'participants': participants,
        'participantUsernames': usernames,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'isGroup': false,
        'unreadCount': unreadCount,
        'typingUsers': <String>[],
      });
      return;
    }

    final data = chatDoc.data();
    final existingParticipants = List<String>.from(data?['participants'] ?? []);
    final existingUnreadCount = Map<String, int>.from(
        data?['unreadCount'] as Map<dynamic, dynamic>? ?? {});

    var needsUpdate = existingParticipants.length != participants.length ||
        !existingParticipants.every(participants.contains);

    for (final participant in participants) {
      if (!existingUnreadCount.containsKey(participant)) {
        needsUpdate = true;
        break;
      }
    }

    if (!needsUpdate) return;

    final unreadCount = <String, int>{
      for (final participant in participants)
        participant: existingUnreadCount[participant] ?? 0,
    };

    final existingUsernames =
        List<String>.from(data?['participantUsernames'] ?? []);
    if (existingUsernames.length != participants.length) {
      final resolved = <String>[];
      for (final uid in participants) {
        if (uid.isEmpty) {
          resolved.add('Unknown User');
          continue;
        }
        try {
          final userDoc = await _firestore.collection('users').doc(uid).get();
          resolved
              .add(userDoc.data()?['username']?.toString() ?? 'Unknown User');
        } catch (_) {
          resolved.add('Unknown User');
        }
      }
      await chatRef.update({
        'participants': participants,
        'participantUsernames': resolved,
        'unreadCount': unreadCount,
      });
    } else {
      await chatRef.update({
        'participants': participants,
        'unreadCount': unreadCount,
      });
    }
  }

  Future<void> markMessageAsRead(String chatId, String messageId) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .set({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
      'status': 'read',
    }, SetOptions(merge: true));
  }

  Future<void> markAllMessagesAsRead(
      String chatId, String currentUserId) async {
    final snapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUserId)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      if (doc.data()['status'] == 'read') continue;
      batch.set(
          doc.reference,
          {
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
            'status': 'read',
          },
          SetOptions(merge: true));

      await (db.update(db.messages)..where((m) => m.id.equals(doc.id))).write(
        const MessagesCompanion(status: Value('read')),
      );
    }
    await batch.commit();

    await _firestore.collection('chats').doc(chatId).set({
      'unreadCount.$currentUserId': 0,
    }, SetOptions(merge: true));
  }

  Future<void> markGroupMessageAsRead({
    required String groupId,
    required String messageId,
    required String currentUserId,
  }) async {
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .doc(messageId)
        .set({
      'readBy': FieldValue.arrayUnion([currentUserId]),
      'status': 'delivered',
    }, SetOptions(merge: true));
  }

  Future<void> markAllGroupMessagesAsRead({
    required String groupId,
    required String currentUserId,
  }) async {
    final snapshot = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUserId)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.set(
          doc.reference,
          {
            'readBy': FieldValue.arrayUnion([currentUserId]),
            'status': 'delivered',
          },
          SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> deleteMessage(
      String chatId, String messageId, bool forEveryone) async {
    if (forEveryone) {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
      await db.deleteMessage(messageId);
      return;
    }

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .set({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await db.markMessageDeleted(messageId);
  }

  Future<void> sendMediaMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String mediaUrl,
    required String mediaType,
    String? caption,
    String? replyToMessageId,
  }) async {
    final uuid = const Uuid().v4();
    final text = caption ?? '';
    final moodService = MoodService();
    final mood = moodService.analyzeMood(text);
    final isUrgent = text.trim().isNotEmpty &&
        moodService.shouldSendUrgentNotification(mood);

    await db.insertMessage(
      MessagesCompanion.insert(
        id: uuid,
        chatId: chatId,
        senderId: senderId,
        receiverId: receiverId,
        content: text,
        mediaUrl: Value(mediaUrl),
        mediaType: Value(mediaType),
        replyToMessageId: Value(replyToMessageId),
        reactionsJson: const Value('[]'),
        isUrgent: Value(isUrgent),
      ),
    );

    if (!isOnline) {
      developer.log('Media message queued offline: $uuid', name: 'ChatService');
      return;
    }

    await _syncSingleDirectMessage(
      chatId: chatId,
      messageId: uuid,
      senderId: senderId,
      receiverId: receiverId,
      content: text,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      replyToMessageId: replyToMessageId,
      isUrgent: isUrgent,
      reactions: const [],
    );

    await db.markSynced(uuid);

    if (isUrgent) {
      await NotificationService().sendUrgentNotification(
          'Urgent Media Message', moodService.getMoodNotification(mood));
    }
  }

  Future<void> addReaction(
      String chatId, String messageId, String emoji) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'reactions': FieldValue.arrayUnion([emoji]),
    });
  }

  Future<void> removeReaction(
      String chatId, String messageId, String emoji) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'reactions': FieldValue.arrayRemove([emoji]),
    });
  }

  Future<void> addGroupReaction(
      String groupId, String messageId, String emoji) async {
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .doc(messageId)
        .update({
      'reactions': FieldValue.arrayUnion([emoji]),
    });
  }

  Future<void> removeGroupReaction(
      String groupId, String messageId, String emoji) async {
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .doc(messageId)
        .update({
      'reactions': FieldValue.arrayRemove([emoji]),
    });
  }

  Future<List<Map<String, dynamic>>> searchMessages(
      String chatId, String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return [];

    final snapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('content', isGreaterThanOrEqualTo: normalized)
        .where('content', isLessThanOrEqualTo: '$normalized\uf8ff')
        .orderBy('content')
        .limit(50)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<List<Map<String, dynamic>>> searchGroupMessages(
      String groupId, String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return [];

    final snapshot = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .where('content', isGreaterThanOrEqualTo: normalized)
        .where('content', isLessThanOrEqualTo: '$normalized\uf8ff')
        .orderBy('content')
        .limit(50)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<void> _syncPendingMessages() async {
    final unsyncedMessages = await (db.select(db.messages)
          ..where((m) => m.isSynced.equals(false)))
        .get();

    for (final message in unsyncedMessages) {
      try {
        List<String> reactions;
        try {
          reactions = (jsonDecode(message.reactionsJson) as List<dynamic>)
              .map((e) => e.toString())
              .toList();
        } catch (_) {
          reactions = const [];
        }

        if (message.receiverId.isEmpty) {
          await _syncSingleGroupMessage(
            groupId: message.chatId,
            messageId: message.id,
            senderId: message.senderId,
            content: message.content,
            mediaUrl: message.mediaUrl,
            mediaType: message.mediaType,
            replyToMessageId: message.replyToMessageId,
            isUrgent: message.isUrgent,
            reactions: reactions,
          );
        } else {
          await _syncSingleDirectMessage(
            chatId: message.chatId,
            messageId: message.id,
            senderId: message.senderId,
            receiverId: message.receiverId,
            content: message.content,
            mediaUrl: message.mediaUrl,
            mediaType: message.mediaType,
            replyToMessageId: message.replyToMessageId,
            isUrgent: message.isUrgent,
            reactions: reactions,
          );
        }

        await db.markSynced(message.id);
      } catch (e) {
        developer.log('Failed to sync pending message ${message.id}: $e',
            name: 'ChatService');
      }
    }
  }

  bool get isOnline => _connectivityService.isOnline;

  Future<void> startTyping(String chatId, String userId) async {
    await _firestore.collection('chats').doc(chatId).set({
      'typingUsers': FieldValue.arrayUnion([userId]),
    }, SetOptions(merge: true));
  }

  Future<void> stopTyping(String chatId, String userId) async {
    await _firestore.collection('chats').doc(chatId).set({
      'typingUsers': FieldValue.arrayRemove([userId]),
    }, SetOptions(merge: true));
  }

  void dispose() {
    _connectivityService.dispose();
    for (final subscription in _activeSyncs.values) {
      subscription.cancel();
    }
    _activeSyncs.clear();
  }

  void overrideFirestoreInstance(FirebaseFirestore firestore) {
    // Test hook kept for compatibility.
  }

  Future<void> fixChatParticipants() async {
    final chatsSnapshot = await _firestore.collection('chats').get();

    for (final chatDoc in chatsSnapshot.docs) {
      final data = chatDoc.data();
      final participants = List<String>.from(data['participants'] ?? []);
      final participantUsernames =
          List<String>.from(data['participantUsernames'] ?? []);
      final unreadCount = Map<String, int>.from(data['unreadCount'] ?? {});

      var needsUpdate = false;
      final fixedParticipants = <String>[];
      final fixedUsernames = <String>[];
      final fixedUnreadCount = <String, int>{};

      for (var i = 0; i < participants.length; i++) {
        final participant = participants[i];
        final username = i < participantUsernames.length
            ? participantUsernames[i]
            : 'Unknown User';

        if (participant.length > 20 &&
            participant.contains(RegExp(r'[a-zA-Z0-9]{20,}'))) {
          fixedParticipants.add(participant);
          fixedUsernames.add(username);
          if (unreadCount.containsKey(participant)) {
            fixedUnreadCount[participant] = unreadCount[participant]!;
          }
          continue;
        }

        final userQuery = await _firestore
            .collection('users')
            .where('username', isEqualTo: participant)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final uid = userQuery.docs.first.data()['uid'] as String;
          fixedParticipants.add(uid);
          fixedUsernames.add(participant);
          if (unreadCount.containsKey(participant)) {
            fixedUnreadCount[uid] = unreadCount[participant]!;
          }
          needsUpdate = true;
        } else {
          fixedParticipants.add(participant);
          fixedUsernames.add(username);
          if (unreadCount.containsKey(participant)) {
            fixedUnreadCount[participant] = unreadCount[participant]!;
          }
        }
      }

      if (needsUpdate) {
        await chatDoc.reference.update({
          'participants': fixedParticipants,
          'participantUsernames': fixedUsernames,
          'unreadCount': fixedUnreadCount,
        });
      }
    }
  }
}
