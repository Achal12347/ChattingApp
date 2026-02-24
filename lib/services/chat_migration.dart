import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMigration {
  final FirebaseFirestore _firestore;

  ChatMigration([FirebaseFirestore? firestore])
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// ✅ Migrate existing chats to use UIDs in participants array
  Future<void> migrateExistingChats() async {
    developer.log("🔄 Starting chat migration...", name: 'ChatMigration');

    try {
      // Get all chats
      final chatsSnapshot = await _firestore.collection('chats').get();

      for (final chatDoc in chatsSnapshot.docs) {
        final data = chatDoc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        final participantUsernames =
            List<String>.from(data['participantUsernames'] ?? []);

        bool needsMigration = false;
        final migratedParticipants = <String>[];
        final migratedUsernames = <String>[];

        // Check if participants contain usernames instead of UIDs
        for (final participant in participants) {
          // If participant doesn't look like a UID (too short or contains special chars), it's likely a username
          if (participant.length < 20 || participant.contains('_') == false) {
            needsMigration = true;
            // Try to find the UID for this username
            try {
              final userQuery = await _firestore
                  .collection('users')
                  .where('username', isEqualTo: participant)
                  .limit(1)
                  .get();

              if (userQuery.docs.isNotEmpty) {
                final uid = userQuery.docs.first.id;
                migratedParticipants.add(uid);
                migratedUsernames.add(participant); // Keep original username
                developer.log("✅ Migrated $participant → $uid",
                    name: 'ChatMigration');
              } else {
                developer.log("❌ Could not find UID for username: $participant",
                    name: 'ChatMigration');
              }
            } catch (e) {
              developer.log("❌ Error migrating participant $participant: $e",
                  name: 'ChatMigration');
            }
          } else {
            // Already a UID
            migratedParticipants.add(participant);
            // Try to get username if not already in participantUsernames
            if (participantUsernames.length < participants.length) {
              try {
                final userDoc =
                    await _firestore.collection('users').doc(participant).get();
                final username = userDoc.data()?['username'] ?? 'Unknown User';
                migratedUsernames.add(username);
              } catch (e) {
                migratedUsernames.add('Unknown User');
              }
            }
          }
        }

        if (needsMigration ||
            participantUsernames.length != migratedParticipants.length) {
          // Update the chat document
          await chatDoc.reference.update({
            'participants': migratedParticipants,
            'participantUsernames': migratedUsernames.isNotEmpty
                ? migratedUsernames
                : participantUsernames,
          });
          developer.log("✅ Migrated chat ${chatDoc.id}", name: 'ChatMigration');
        }
      }

      developer.log("✅ Chat migration completed", name: 'ChatMigration');
    } catch (e) {
      developer.log("❌ Chat migration failed: $e", name: 'ChatMigration');
    }
  }
}
