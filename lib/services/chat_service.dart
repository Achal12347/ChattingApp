import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'mood_service.dart';
import 'notification_service.dart';
import 'connectivity_service.dart';
import 'relationship_service.dart';

class ChatService {
  final FirebaseFirestore _firestore;
  final AppDatabase db;
  final ConnectivityService _connectivityService = ConnectivityService();
  final Map<String, StreamSubscription> _activeSyncs = {};

  ChatService([AppDatabase? db, FirebaseFirestore? firestore])
      : db = db ?? AppDatabase.instance,
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

  /// ✅ Send group message: Save locally in Drift first, then sync to Firestore if online
  Future<void> sendGroupMessage({
    required String groupId,
    required String senderId,
    required String content,
  }) async {
    final uuid = const Uuid().v4();

    developer.log(
        "📤 Sending group message: groupId=$groupId, senderId=$senderId",
        name: 'ChatService');

    // Check for urgent message
    final moodService = MoodService();
    final mood = moodService.analyzeMood(content);
    final isUrgent = moodService.shouldSendUrgentNotification(mood);

    // 1. Save message locally
    await db.insertMessage(MessagesCompanion.insert(
      id: uuid,
      chatId: groupId,
      senderId: senderId,
      receiverId: '', // No specific receiver for groups
      content: content,
    ));

    developer.log("💾 Group message saved locally: id=$uuid",
        name: 'ChatService');

    // 2. Try to sync to Firestore if online
    if (isOnline) {
      try {
        // Ensure group document exists
        await ensureGroupExists(groupId);

        final msgRef = _firestore
            .collection('groups')
            .doc(groupId)
            .collection('messages')
            .doc(uuid);

        developer.log("☁️ Syncing group message to Firestore: id=$uuid",
            name: 'ChatService');

        await msgRef.set({
          'id': uuid,
          'senderId': senderId,
          'content': content,
          'createdAt': FieldValue.serverTimestamp(),
          'isUrgent': isUrgent,
          'status': 'sent',
        });

        developer.log("✅ Group message set in Firestore: id=$uuid",
            name: 'ChatService');

        // Update group document with last message
        await _firestore.collection('groups').doc(groupId).update({
          'lastMessage': content,
          'lastMessageAt': FieldValue.serverTimestamp(),
        });

        developer.log("🔄 Group document updated: groupId=$groupId",
            name: 'ChatService');

        // 3. Mark synced in Drift after success
        await db.markSynced(uuid);

        developer.log("✅ Group message marked as synced: id=$uuid",
            name: 'ChatService');

        // 4. Send urgent notification if needed
        if (isUrgent) {
          final notificationService = NotificationService();
          await notificationService.sendUrgentNotification(
            'Urgent Group Message',
            moodService.getMoodNotification(mood),
          );
          developer.log("🚨 Urgent notification sent", name: 'ChatService');
        }
      } catch (e) {
        developer.log("❌ Failed to sync group message to Firestore: $e",
            name: 'ChatService');
        // Message remains unsynced in local database
      }
    } else {
      developer.log(
          "📱 Group message saved offline, will sync when online: id=$uuid",
          name: 'ChatService');
    }
  }

  /// ✅ Send message: Save locally in Drift first, then sync to Firestore if online
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String content,
  }) async {
    // Validate that senderId and receiverId are not empty
    if (senderId.isEmpty || receiverId.isEmpty) {
      print(
          'ChatService: Error - senderId or receiverId is empty. senderId=$senderId, receiverId=$receiverId');
      return; // Or throw an exception
    }

    // Check if sender is blocked by receiver
    final relationshipService = RelationshipService();
    final isBlocked =
        await relationshipService.isCurrentUserBlockedBy(receiverId);
    if (isBlocked) {
      print(
          'ChatService: Cannot send message - sender $senderId is blocked by receiver $receiverId');
      return;
    }

    final uuid = const Uuid().v4();

    print(
        'ChatService: Sending message: chatId=$chatId, senderId=$senderId, receiverId=$receiverId, content=$content');
    // Add logging to verify senderId and receiverId are UIDs
    print(
        'ChatService: sendMessage senderId = $senderId, receiverId = $receiverId');

    // Check for urgent message
    final moodService = MoodService();
    final mood = moodService.analyzeMood(content);
    final isUrgent = moodService.shouldSendUrgentNotification(mood);

    // 1. Save message locally
    await db.insertMessage(MessagesCompanion.insert(
      id: uuid,
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      content: content,
    ));

    print('ChatService: Message saved locally: id=$uuid');

    // 2. Try to sync to Firestore if online
    if (isOnline) {
      try {
        print('ChatService: Ensuring chat exists for chatId=$chatId');
        // Ensure chat document exists
        await ensureChatExists(chatId, [senderId, receiverId]);

        final msgRef = _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(uuid);

        print('ChatService: Syncing message to Firestore: id=$uuid');

        await msgRef.set({
          'id': uuid,
          'senderId': senderId,
          'receiverId': receiverId,
          'content': content,
          'createdAt': FieldValue.serverTimestamp(),
          'isUrgent': isUrgent,
          'status': 'sent',
        });

        print('ChatService: Message set in Firestore: id=$uuid');

        // Update chat document with last message and increment unread count
        await _firestore.collection('chats').doc(chatId).update({
          'lastMessage': content,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'unreadCount.$receiverId': FieldValue.increment(1),
        });

        developer.log("🔄 Chat document updated: chatId=$chatId",
            name: 'ChatService');

        // 3. Mark synced in Drift after success
        await db.markSynced(uuid);

        developer.log("✅ Message marked as synced: id=$uuid",
            name: 'ChatService');

        // 4. Send urgent notification if needed
        if (isUrgent) {
          final notificationService = NotificationService();
          await notificationService.sendUrgentNotification(
            'Urgent Message',
            moodService.getMoodNotification(mood),
          );
          developer.log("🚨 Urgent notification sent", name: 'ChatService');
        }
      } catch (e) {
        developer.log("❌ Failed to sync message to Firestore: $e",
            name: 'ChatService');
        // Message remains unsynced in local database
      }
    } else {
      developer.log("📱 Message saved offline, will sync when online: id=$uuid",
          name: 'ChatService');
    }
  }

  /// ✅ Sync Firestore messages → Drift local DB
  void syncMessages(String chatId, String currentUserId) {
    print(
        'ChatService: syncMessages called for chatId=$chatId, currentUserId=$currentUserId');

    // Guard against empty chatId
    if (chatId.isEmpty) {
      print('ChatService: syncMessages skipped - chatId is empty');
      return;
    }

    // Check if sync is already active for this chatId
    if (_activeSyncs.containsKey(chatId)) {
      print('ChatService: sync already active for chatId=$chatId');
      return;
    }

    final subscription = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .listen((snapshot) async {
      print(
          'ChatService: syncMessages received snapshot with ${snapshot.docs.length} docs for chatId=$chatId');
      for (var doc in snapshot.docs) {
        final data = doc.data();

        if (!data.containsKey('id')) continue; // skip invalid docs
        final id = data['id'] as String;
        print(
            'ChatService: processing message id=$id, senderId=${data['senderId']}, content=${data['content']}');

        // 1. Check if already exists in Drift
        final existing =
            await (db.select(db.messages)..where((m) => m.id.equals(id))).get();

        if (existing.isEmpty) {
          print('ChatService: inserting new message id=$id into local DB');
          try {
            // 2. Insert new message into Drift
            await db.insertMessage(MessagesCompanion.insert(
              id: id,
              chatId: chatId,
              senderId: data['senderId'] ?? '',
              receiverId: data['receiverId'] ?? '',
              content: data['content'] ?? '',
              isSynced: const Value(true),
              createdAt: Value(
                (data['createdAt'] is Timestamp)
                    ? (data['createdAt'] as Timestamp).toDate()
                    : (data['createdAt'] is DateTime)
                        ? data['createdAt'] as DateTime
                        : DateTime.now(),
              ),
            ));
            print(
                'ChatService: successfully inserted message id=$id into local DB');

            // 3. Update status to 'received' if not sent by current user
            if (data['senderId'] != currentUserId) {
              print(
                  'ChatService: updating message status to received for id=$id');
              await _firestore
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .doc(id)
                  .update({'status': 'delivered'});

              // Update status in local DB
              await (db.update(db.messages)..where((m) => m.id.equals(id)))
                  .write(
                MessagesCompanion(status: const Value('delivered')),
              );

              // 4. Send local notification
              // Fetch username for senderId to show in notification
              final senderId = data['senderId'] ?? '';
              if (senderId.isNotEmpty) {
                final userDoc =
                    await _firestore.collection('users').doc(senderId).get();
                final username = userDoc.data()?['username'] ?? 'Unknown User';
                NotificationService.instance
                    ?.sendNewMessageNotificationWithUsername(
                        username, senderId, data['content']);
              } else {
                print(
                    'ChatService: Skipped fetching userDoc due to empty senderId');
              }
            }
          } catch (e) {
            print('ChatService: Error inserting message id=$id: $e');
          }
        } else {
          print(
              'ChatService: message id=$id already exists in local DB. Checking for status update.');
          // Check if status needs to be updated for existing message
          if (existing.first.status != data['status']) {
            print(
                'ChatService: Updating status for existing message $id from ${existing.first.status} to ${data['status']}');
            await (db.update(db.messages)..where((m) => m.id.equals(id))).write(
              MessagesCompanion(status: Value(data['status'])),
            );
          }
        }
      }
    }, onError: (error) {
      print('ChatService: Error in syncMessages for chatId=$chatId: $error');
    });

    _activeSyncs[chatId] = subscription;
    print('ChatService: started sync for chatId=$chatId');
  }

  /// ✅ Create Group Document if it doesn’t exist
  Future<void> ensureGroupExists(String groupId) async {
    final groupRef = _firestore.collection('groups').doc(groupId);
    final groupDoc = await groupRef.get();

    developer.log(
        "🔍 Checking group existence: groupId=$groupId, exists=${groupDoc.exists}",
        name: 'ChatService');

    if (!groupDoc.exists) {
      // Group should already exist, but if not, we can't create it here
      // This method assumes the group is created elsewhere
      developer.log("⚠️ Group document does not exist: groupId=$groupId",
          name: 'ChatService');
    }
  }

  /// ✅ Create Chat Document if it doesn’t exist
  Future<void> ensureChatExists(String chatId, List<String> participants,
      {List<String>? participantUsernames}) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();

    print(
        'ChatService: Checking chat existence: chatId=$chatId, exists=${chatDoc.exists}');

    if (!chatDoc.exists) {
      final unreadCount = <String, int>{};
      for (final participant in participants) {
        unreadCount[participant] = 0;
      }

      // Use provided usernames or fetch them
      final usernames = participantUsernames ?? <String>[];
      if (usernames.isEmpty) {
        for (final uid in participants) {
          if (uid.isNotEmpty) {
            try {
              final userDoc =
                  await _firestore.collection('users').doc(uid).get();
              final username = userDoc.data()?['username'] ?? 'Unknown User';
              usernames.add(username);
            } catch (e) {
              usernames.add('Unknown User');
            }
          } else {
            usernames.add('Unknown User');
            print(
                'ChatService: Skipped fetching userDoc due to empty uid in participants');
          }
        }
      }

      print('ChatService: Creating new chat document: chatId=$chatId');
      await chatRef.set({
        'chatId': chatId,
        'participants': participants, // UIDs only
        'participantUsernames': usernames, // Usernames for display
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'isGroup': false,
        'unreadCount': unreadCount,
        'typingUsers': <String>[],
      });
      print('ChatService: Created new chat document: chatId=$chatId');
    } else {
      // Ensure participants are set for existing chats
      final data = chatDoc.data();
      final existingParticipants =
          List<String>.from(data?['participants'] as List<dynamic>? ?? []);
      final existingUnreadCount = Map<String, int>.from(
          data?['unreadCount'] as Map<dynamic, dynamic>? ?? {});

      bool needsUpdate = false;
      if (existingParticipants.length != participants.length ||
          !existingParticipants.every((p) => participants.contains(p))) {
        needsUpdate = true;
      }

      for (final participant in participants) {
        if (!existingUnreadCount.containsKey(participant)) {
          needsUpdate = true;
          break;
        }
      }

      if (needsUpdate) {
        final unreadCount = <String, int>{};
        for (final participant in participants) {
          unreadCount[participant] = existingUnreadCount[participant] ?? 0;
        }

        // Update participantUsernames if needed
        final existingUsernames = List<String>.from(
            data?['participantUsernames'] as List<dynamic>? ?? []);
        if (existingUsernames.length != participants.length) {
          final participantUsernames = <String>[];
          for (final uid in participants) {
            if (uid.isNotEmpty) {
              try {
                final userDoc =
                    await _firestore.collection('users').doc(uid).get();
                final username = userDoc.data()?['username'] ?? 'Unknown User';
                participantUsernames.add(username);
              } catch (e) {
                participantUsernames.add('Unknown User');
              }
            } else {
              participantUsernames.add('Unknown User');
              print(
                  'ChatService: Skipped fetching userDoc due to empty uid in participants');
            }
          }
          await chatRef.update({
            'participants': participants,
            'participantUsernames': participantUsernames,
            'unreadCount': unreadCount,
          });
        } else {
          await chatRef.update({
            'participants': participants,
            'unreadCount': unreadCount,
          });
        }
        developer.log(
            "🔧 Updated participants for existing chat: chatId=$chatId",
            name: 'ChatService');
      }
    }
  }

  /// ✅ Mark message as read
  Future<void> markMessageAsRead(String chatId, String messageId) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
      'status': 'read',
    });
  }

  /// ✅ Mark all messages as read in a chat
  Future<void> markAllMessagesAsRead(
      String chatId, String currentUserId) async {
    print(
        'ChatService: Entering markAllMessagesAsRead for chatId=$chatId, currentUserId=$currentUserId');
    // Get all unread messages
    final snapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUserId)
        .get();

    // Update each message in Firestore using a batch write
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      final messageStatus = doc.data()['status'] as String?;
      if (messageStatus == 'read') {
        continue; // Skip messages that are already read
      }
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
        'status': 'read',
      });

      // Also update in local database (this part remains individual as Drift doesn't have batch updates in this context)
      final messageId = doc.id;
      await (db.update(db.messages)..where((m) => m.id.equals(messageId)))
          .write(
        MessagesCompanion(
          status: const Value('read'),
        ),
      );
    }
    await batch.commit();

    // Reset unread count for current user
    await _firestore.collection('chats').doc(chatId).update({
      'unreadCount.$currentUserId': 0,
    });
    print(
        'ChatService: Unread count for $currentUserId in chat $chatId set to 0.');
  }

  /// ✅ Delete message
  Future<void> deleteMessage(
      String chatId, String messageId, bool forEveryone) async {
    if (forEveryone) {
      // Delete from Firestore
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();

      // Delete from local database
      await db.deleteMessage(messageId);
    } else {
      // Mark as deleted for current user in Firestore
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });

      // Mark as deleted in local database
      await db.markMessageDeleted(messageId);
    }
  }

  /// ✅ Send media message
  Future<void> sendMediaMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String mediaUrl,
    required String mediaType,
    String? caption,
  }) async {
    final uuid = const Uuid().v4();

    developer.log(
        "📤 Sending media message: chatId=$chatId, senderId=$senderId, receiverId=$receiverId",
        name: 'ChatService');

    // Check for urgent message based on caption
    final moodService = MoodService();
    final mood = caption != null && caption.isNotEmpty
        ? moodService.analyzeMood(caption)
        : null;
    final isUrgent =
        mood != null ? moodService.shouldSendUrgentNotification(mood) : false;

    // Save locally
    await db.insertMessage(MessagesCompanion.insert(
      id: uuid,
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      content: caption ?? '',
    ));

    developer.log("💾 Media message saved locally: id=$uuid",
        name: 'ChatService');

    // Ensure chat exists
    await ensureChatExists(chatId, [senderId, receiverId]);

    // Push to Firestore
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(uuid)
        .set({
      'id': uuid,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': caption ?? '',
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'createdAt': FieldValue.serverTimestamp(),
      'isUrgent': isUrgent,
      'status': 'sent',
    });

    developer.log("✅ Media message synced to Firestore: id=$uuid",
        name: 'ChatService');

    // Update chat document with last message
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': caption ?? 'Media message',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCount.$receiverId': FieldValue.increment(1),
    });

    await db.markSynced(uuid);

    developer.log("✅ Media message marked as synced: id=$uuid",
        name: 'ChatService');

    // Send urgent notification if needed
    if (isUrgent) {
      final notificationService = NotificationService();
      await notificationService.sendUrgentNotification(
        'Urgent Media Message',
        moodService.getMoodNotification(mood!),
      );
      developer.log("🚨 Urgent notification sent", name: 'ChatService');
    }
  }

  /// ✅ Add reaction to message
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

  /// ✅ Search messages in chat
  Future<List<Map<String, dynamic>>> searchMessages(
      String chatId, String query) async {
    final snapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('content', isGreaterThanOrEqualTo: query)
        .where('content', isLessThanOrEqualTo: "$query\uf8ff")
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// ✅ Sync pending messages when coming back online
  Future<void> _syncPendingMessages() async {
    developer.log("🔄 Syncing pending messages...", name: 'ChatService');

    // Get all unsynced messages from local database
    final unsyncedMessages = await (db.select(db.messages)
          ..where((m) => m.isSynced.equals(false)))
        .get();

    for (final message in unsyncedMessages) {
      try {
        // Ensure chat exists
        await ensureChatExists(
            message.chatId, [message.senderId, message.receiverId]);

        // Sync to Firestore
        await _firestore
            .collection('chats')
            .doc(message.chatId)
            .collection('messages')
            .doc(message.id)
            .set({
          'id': message.id,
          'senderId': message.senderId,
          'receiverId': message.receiverId,
          'content': message.content,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'sent',
        });

        // Update chat document
        await _firestore.collection('chats').doc(message.chatId).update({
          'lastMessage': message.content,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'unreadCount': {message.receiverId: FieldValue.increment(1)},
        });

        // Mark as synced in local database
        await db.markSynced(message.id);

        developer.log("✅ Synced pending message: ${message.id}",
            name: 'ChatService');
      } catch (e) {
        developer.log("❌ Failed to sync message ${message.id}: $e",
            name: 'ChatService');
      }
    }

    developer.log("✅ Finished syncing pending messages", name: 'ChatService');
  }

  /// ✅ Get connectivity status
  bool get isOnline => _connectivityService.isOnline;

  /// ✅ Start typing in chat
  Future<void> startTyping(String chatId, String userId) async {
    await _firestore.collection('chats').doc(chatId).update({
      'typingUsers': FieldValue.arrayUnion([userId]),
    });
    developer.log("✅ Started typing: chatId=$chatId, userId=$userId",
        name: 'ChatService');
  }

  /// ✅ Stop typing in chat
  Future<void> stopTyping(String chatId, String userId) async {
    await _firestore.collection('chats').doc(chatId).update({
      'typingUsers': FieldValue.arrayRemove([userId]),
    });
    developer.log("✅ Stopped typing: chatId=$chatId, userId=$userId",
        name: 'ChatService');
  }

  /// ✅ Dispose resources
  void dispose() {
    _connectivityService.dispose();
    // Cancel all active sync subscriptions
    for (final subscription in _activeSyncs.values) {
      subscription.cancel();
    }
    _activeSyncs.clear();
  }

  /// For testing: Override Firestore instance
  void overrideFirestoreInstance(FirebaseFirestore firestore) {
    // This method is for testing purposes only
    // In a real implementation, you might need to make _firestore injectable
  }

  /// ✅ Fix participants in chat documents: Replace usernames with UIDs
  Future<void> fixChatParticipants() async {
    print('ChatService: Starting to fix chat participants...');

    final chatsSnapshot = await _firestore.collection('chats').get();
    print('ChatService: Found ${chatsSnapshot.docs.length} chat documents');

    for (final chatDoc in chatsSnapshot.docs) {
      print('ChatService: Processing chat ${chatDoc.id}');
      final data = chatDoc.data();
      final participants = List<String>.from(data['participants'] ?? []);
      final participantUsernames =
          List<String>.from(data['participantUsernames'] ?? []);
      final unreadCount = Map<String, int>.from(data['unreadCount'] ?? {});

      print('ChatService: Original participants: $participants');
      print(
          'ChatService: Original participantUsernames: $participantUsernames');
      print('ChatService: Original unreadCount: $unreadCount');

      bool needsUpdate = false;
      final fixedParticipants = <String>[];
      final fixedUsernames = <String>[];
      final fixedUnreadCount = <String, int>{};

      for (int i = 0; i < participants.length; i++) {
        final participant = participants[i];
        final username = i < participantUsernames.length
            ? participantUsernames[i]
            : 'Unknown User';

        // Check if participant is a UID (assuming UIDs are longer than usernames and contain specific characters)
        if (participant.length > 20 &&
            participant.contains(RegExp(r'[a-zA-Z0-9]{20,}'))) {
          // It's likely a UID
          print('ChatService: Participant $participant is a UID');
          fixedParticipants.add(participant);
          fixedUsernames.add(username);
          if (unreadCount.containsKey(participant)) {
            fixedUnreadCount[participant] = unreadCount[participant]!;
          }
        } else {
          // It's likely a username, find the UID
          print('ChatService: Found username $participant, finding UID...');
          final userQuery = await _firestore
              .collection('users')
              .where('username', isEqualTo: participant)
              .limit(1)
              .get();
          print(
              'ChatService: User query returned ${userQuery.docs.length} docs');
          if (userQuery.docs.isNotEmpty) {
            final uid = userQuery.docs.first.data()['uid'] as String;
            print('ChatService: Found UID $uid for username $participant');
            fixedParticipants.add(uid);
            fixedUsernames.add(participant); // username remains
            if (unreadCount.containsKey(participant)) {
              fixedUnreadCount[uid] = unreadCount[participant]!;
              print('ChatService: Moved unreadCount from $participant to $uid');
            }
            needsUpdate = true;
          } else {
            print('ChatService: Could not find UID for username $participant');
            fixedParticipants.add(participant);
            fixedUsernames.add(username);
            if (unreadCount.containsKey(participant)) {
              fixedUnreadCount[participant] = unreadCount[participant]!;
            }
          }
        }
      }

      print('ChatService: Fixed participants: $fixedParticipants');
      print('ChatService: Fixed participantUsernames: $fixedUsernames');
      print('ChatService: Fixed unreadCount: $fixedUnreadCount');

      if (needsUpdate) {
        print(
            'ChatService: Updating chat ${chatDoc.id} with fixed participants');
        try {
          await chatDoc.reference.update({
            'participants': fixedParticipants,
            'participantUsernames': fixedUsernames,
            'unreadCount': fixedUnreadCount,
          });
          print('ChatService: Successfully updated chat ${chatDoc.id}');
        } catch (e) {
          print('ChatService: Error updating chat ${chatDoc.id}: $e');
        }
      } else {
        print('ChatService: No update needed for chat ${chatDoc.id}');
      }
    }

    print('ChatService: Finished fixing chat participants');
  }
}
