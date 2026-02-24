import '../../widgets/mood_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../app_routes.dart';
import '../../services/chat_service.dart';

import '../../database/app_database.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/group_model.dart';
import '../../services/group_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Map<String, String> _usernames = {};
  final Map<String, String> _profilePhotoUrls = {};

  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return '';
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inDays == 0) {
      return 'Last seen today at ${DateFormat('h:mm a').format(lastSeen)}';
    } else if (difference.inDays == 1) {
      return 'Last seen yesterday at ${DateFormat('h:mm a').format(lastSeen)}';
    } else if (difference.inDays < 7) {
      return 'Last seen ${difference.inDays} days ago';
    } else {
      return 'Last seen ${DateFormat('MMM d').format(lastSeen)}';
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final chatsSnapshot = await FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: user.uid)
        .get();

    final uids = <String>{};
    for (final doc in chatsSnapshot.docs) {
      final participants = List<String>.from(doc.data()['participants'] ?? []);
      for (final uid in participants) {
        if (uid != user.uid) {
          uids.add(uid);
        }
      }
    }

    if (uids.isNotEmpty) {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', whereIn: uids.toList())
          .get();

      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        _usernames[data['uid']] = data['username'] ?? 'Unknown User';
        _profilePhotoUrls[data['uid']] = data['profileImage'] ?? '';
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _openMenu(String choice) {
    switch (choice) {
      case 'Create Group':
        Navigator.pushNamed(context, AppRoutes.createGroup);
        break;
      case 'Edit Profile':
        Navigator.pushNamed(context, AppRoutes.editProfile);
        break;
      case 'Settings':
        Navigator.pushNamed(context, AppRoutes.settings);
        break;
      case 'Mark All as Read':
        _markAllAsRead();
        break;

      case 'Unblock Requests':
        Navigator.pushNamed(context, '/unblockRequests');
        break;

      case 'Logout':
        FirebaseAuth.instance.signOut();
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        break;
    }
  }

  void _markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final chatsSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: user.uid)
          .get();

      for (final chatDoc in chatsSnapshot.docs) {
        await ref
            .read(chatServiceProvider)
            .markAllMessagesAsRead(chatDoc.id, user.uid);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All messages marked as read')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking messages as read: $e')),
        );
      }
    }
  }

  void _startSyncForAllChats(List<Map<String, dynamic>> chats) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final chatService = ref.read(chatServiceProvider);

    for (final chat in chats) {
      final chatId = chat['id'] ?? '';
      if (chatId.isNotEmpty) {
        chatService.syncMessages(chatId, user.uid);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser!.uid)
              .snapshots(),
          builder: (context, snapshot) {
            String currentMood = '🙂'; // default
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              currentMood = data['mood'] ?? '🙂';
            }
            return IconButton(
              icon: Text(currentMood, style: const TextStyle(fontSize: 24)),
              tooltip: 'Mood',
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => const MoodSelector(),
                );
              },
            );
          },
        ),
        title: const Text("Chatly"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () {
              showSearch(context: context, delegate: UserSearchDelegate());
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code),
            tooltip: 'My QR Code',
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.qrCode);
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Menu',
            onSelected: _openMenu,
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'Create Group', child: Text("Create Group")),
              const PopupMenuItem(
                  value: 'Edit Profile', child: Text("Edit Profile")),
              const PopupMenuItem(value: 'Settings', child: Text("Settings")),
              const PopupMenuItem(
                  value: 'Mark All as Read', child: Text("Mark All as Read")),
              const PopupMenuItem(value: 'Logout', child: Text("Logout")),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'Unblock Requests',
                child: Row(
                  children: const [
                    Icon(Icons.lock_open, size: 18),
                    SizedBox(width: 8),
                    Text('Unblock Requests'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer(
        builder: (context, ref, _) {
          final user = ref.watch(authStateProvider).value;
          if (user == null) return const Center(child: Text("Please log in"));

          final chatsAsync = ref.watch(chatsProvider);
          final groupsAsync = ref.watch(groupsProvider);

          return chatsAsync.when(
            data: (chats) {
              final groups = groupsAsync;
              if (chats.isEmpty && groups.isEmpty) {
                return const Center(
                  child: Text(
                    "👋 Welcome to Chatly!\nTap the search icon to find friends or create a group.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                );
              }

              // Combine chats and groups
              final combined = [
                ...chats.map((c) => {'type': 'chat', 'data': c}),
                ...groups.map((g) => {'type': 'group', 'data': g}),
              ];

              combined.sort((a, b) {
                DateTime? aTime;
                DateTime? bTime;
                if (a['type'] == 'chat') {
                  final chatData = a['data'] as Map<String, dynamic>;
                  aTime = (chatData['lastMessageAt'] as Timestamp?)?.toDate();
                } else {
                  final group = a['data'] as GroupModel;
                  aTime = group.lastMessageAt;
                }
                if (b['type'] == 'chat') {
                  final chatData = b['data'] as Map<String, dynamic>;
                  bTime = (chatData['lastMessageAt'] as Timestamp?)?.toDate();
                } else {
                  final group = b['data'] as GroupModel;
                  bTime = group.lastMessageAt;
                }
                return bTime?.compareTo(aTime ?? DateTime.now()) ?? 0;
              });

              _startSyncForAllChats(chats); // Still sync chats

              return ListView.builder(
                itemCount: combined.length,
                itemBuilder: (context, index) {
                  final item = combined[index];
                  if (item['type'] == 'chat') {
                    final chat = item['data'] as Map<String, dynamic>;
                    final participants =
                        List<String>.from(chat['participants'] ?? []);
                    final otherUserId = participants.firstWhere(
                        (id) => id != user.uid && id.isNotEmpty,
                        orElse: () => '');

                    if (otherUserId.isEmpty) {
                      return const SizedBox(); // Skip invalid chats
                    }

                    final lastMessage = chat['lastMessage'] ?? '';
                    final lastMessageAt = chat['lastMessageAt'] != null
                        ? (chat['lastMessageAt'] as Timestamp).toDate()
                        : null;

                    final unreadCount = (chat['unreadCount']
                            as Map<String, dynamic>?)?[user.uid] ??
                        0;
                    print(
                        'HomeScreen: Chat ID: ${chat['id']}, Unread Count: $unreadCount');

                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(otherUserId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const ListTile(
                            leading: CircleAvatar(
                              child: CircularProgressIndicator(),
                            ),
                            title: Text('Loading...'),
                          );
                        }

                        final otherUsername = (snapshot.data?.data()
                                as Map<String, dynamic>?)?['username'] ??
                            'Unknown User';
                        final profilePhotoUrl = (snapshot.data?.data()
                                as Map<String, dynamic>?)?['profileImage'] ??
                            '';
                        final mood = (snapshot.data?.data()
                                as Map<String, dynamic>?)?['mood'] ??
                            '';
                        final userStatus = (snapshot.data?.data()
                                as Map<String, dynamic>?)?['status'] ??
                            'offline';
                        final lastSeenTimestamp = (snapshot.data?.data()
                                as Map<String, dynamic>?)?['lastSeen']
                            as Timestamp?;
                        final lastSeen = lastSeenTimestamp?.toDate();

                        return ListTile(
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                backgroundImage: profilePhotoUrl.isNotEmpty
                                    ? NetworkImage(profilePhotoUrl)
                                    : null,
                                child: profilePhotoUrl.isEmpty
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: userStatus == 'online'
                                        ? Colors.green
                                        : Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: unreadCount > 0
                              ? Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              : null,
                          title: Row(
                            children: [
                              Text(
                                otherUsername,
                                style: TextStyle(
                                  fontWeight: unreadCount > 0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              if (mood.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Text(mood,
                                      style: const TextStyle(fontSize: 14)),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            userStatus == 'online'
                                ? 'Online'
                                : _formatLastSeen(lastSeen),
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                          onTap: () async {
                            await Navigator.pushNamed(context, AppRoutes.chat,
                                arguments: {
                                  'chatId': chat['id'] ?? '',
                                  'receiverId': otherUserId,
                                  'currentUserId': user.uid,
                                });
                            ref.invalidate(chatsProvider);
                            print(
                                'HomeScreen: chatsProvider invalidated after returning from chat.');
                          },
                          onLongPress: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Chat'),
                                content: Text(
                                    'Are you sure you want to delete chat with $otherUsername? This will delete all chat history.'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              final chatId = chat['id'] ?? '';
                              final chatRef = FirebaseFirestore.instance
                                  .collection('chats')
                                  .doc(chatId);
                              final messagesRef =
                                  chatRef.collection('messages');

                              final messagesSnapshot = await messagesRef.get();
                              for (final doc in messagesSnapshot.docs) {
                                await doc.reference.delete();
                              }

                              await chatRef.delete();

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Chat deleted successfully')),
                                );
                              }
                            }
                          },
                        );
                      },
                    );
                  } else {
                    // Group
                    final group = item['data'] as GroupModel;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: group.avatarUrl != null
                            ? NetworkImage(group.avatarUrl!)
                            : null,
                        child: group.avatarUrl == null
                            ? const Icon(Icons.group)
                            : null,
                      ),
                      title: Text(group.name),
                      subtitle: const Text('Group'),
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.groupChat,
                            arguments: {
                              'groupId': group.id,
                              'currentUserId': user.uid,
                            });
                      },
                      onLongPress: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Leave Group'),
                            content: Text(
                                'Are you sure you want to leave ${group.name}?'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text('Leave'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          final groupService = ref.read(groupServiceProvider);
                          await groupService.leaveGroup(group.id, user.uid);
                          ref.invalidate(groupsProvider);
                        }
                      },
                    );
                  }
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          );
        },
      ),
    );
  }
}

class UserSearchDelegate extends SearchDelegate {
  final _firestore = FirebaseFirestore.instance;

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildUserList();
  @override
  Widget buildSuggestions(BuildContext context) => _buildUserList();

  Widget _buildUserList() {
    if (query.trim().isEmpty) {
      return const Center(child: Text("Search for users by username or email"));
    }

    return FutureBuilder<QuerySnapshot>(
      future: _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThanOrEqualTo: "$query\uf8ff")
          .limit(10)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;
        if (users.isEmpty) return const Center(child: Text("No users found"));

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final doc = users[index];
            final userData = doc.data() as Map<String, dynamic>;
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(userData['username'] ?? 'Unknown'),
              subtitle: Text(userData['email'] ?? ''),
              onTap: () async {
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser == null) return;
                final currentUserId = currentUser.uid;
                final receiverId = userData['uid'] as String;
                if (receiverId.isEmpty) return;

                // Sorted chatId
                final chatIdList = [currentUserId, receiverId]..sort();
                final chatIdStr = chatIdList.join('_');

                // Check if chat exists
                final existingChatsQuery = await _firestore
                    .collection('chats')
                    .where('participants', arrayContains: currentUserId)
                    .get();

                String? existingChatId;
                for (final doc in existingChatsQuery.docs) {
                  final participants =
                      List<String>.from(doc.data()['participants'] ?? []);
                  if (participants.contains(currentUserId) &&
                      participants.contains(receiverId) &&
                      participants.length == 2) {
                    existingChatId = doc.id;
                    break;
                  }
                }

                // Ensure chat exists
                final participantUsernames = <String>[];
                for (final uid in [currentUserId, receiverId]) {
                  if (uid.isNotEmpty) {
                    try {
                      final userDoc =
                          await _firestore.collection('users').doc(uid).get();
                      participantUsernames
                          .add(userDoc.data()?['username'] ?? 'Unknown User');
                    } catch (_) {
                      participantUsernames.add('Unknown User');
                    }
                  } else {
                    participantUsernames.add('Unknown User');
                    print(
                        'HomeScreen: Skipped fetching userDoc due to empty uid');
                  }
                }

                final chatService = ChatService(AppDatabase.instance);
                final finalChatId = existingChatId ?? chatIdStr;
                await chatService.ensureChatExists(
                  finalChatId,
                  [currentUserId, receiverId],
                  participantUsernames: participantUsernames,
                );

                close(context, userData);

                Navigator.pushNamed(context, AppRoutes.chat, arguments: {
                  'chatId': finalChatId,
                  'receiverId': receiverId,
                  'currentUserId': currentUserId,
                });
              },
            );
          },
        );
      },
    );
  }
}
