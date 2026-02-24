import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app_routes.dart';
import '../../database/app_database.dart';
import '../../models/group_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/chat_service.dart';
import '../../services/group_service.dart';
import '../../widgets/mood_selector.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'Offline';
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) return 'Last seen just now';
    if (difference.inHours < 1) return 'Last seen ${difference.inMinutes}m ago';
    if (difference.inDays == 0) {
      return 'Last seen today at ${DateFormat('h:mm a').format(lastSeen)}';
    }
    if (difference.inDays == 1) {
      return 'Last seen yesterday at ${DateFormat('h:mm a').format(lastSeen)}';
    }
    if (difference.inDays < 7) return 'Last seen ${difference.inDays}d ago';
    return 'Last seen ${DateFormat('MMM d').format(lastSeen)}';
  }

  String _formatTileTime(DateTime? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    if (now.year == timestamp.year &&
        now.month == timestamp.month &&
        now.day == timestamp.day) {
      return DateFormat('h:mm a').format(timestamp);
    }
    return DateFormat('MMM d').format(timestamp);
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
        Navigator.pushNamed(context, AppRoutes.unblockRequests);
        break;
      case 'Logout':
        FirebaseAuth.instance.signOut();
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        break;
    }
  }

  Future<void> _markAllAsRead() async {
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All messages marked as read')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking messages as read: $e')),
      );
    }
  }

  void _startSyncForAllChats(List<Map<String, dynamic>> chats) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final chatService = ref.read(chatServiceProvider);
    for (final chat in chats) {
      final chatId = chat['id']?.toString() ?? '';
      if (chatId.isNotEmpty) {
        chatService.syncMessages(chatId, user.uid);
      }
    }
  }

  Future<void> _deleteChat(String chatId, String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: Text(
          'Delete the chat with $username? This removes chat history for everyone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    final messagesRef = chatRef.collection('messages');
    final messagesSnapshot = await messagesRef.get();
    for (final doc in messagesSnapshot.docs) {
      await doc.reference.delete();
    }
    await chatRef.delete();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Chat deleted')));
  }

  Future<void> _leaveGroup(GroupModel group, String currentUserId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: Text('Leave "${group.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final groupService = ref.read(groupServiceProvider);
    await groupService.leaveGroup(group.id, currentUserId);
    ref.invalidate(groupsProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 72,
        leading: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser?.uid)
              .snapshots(),
          builder: (context, snapshot) {
            String currentMood = '🙂';
            if (snapshot.hasData && snapshot.data?.exists == true) {
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              currentMood = data?['mood']?.toString() ?? '🙂';
            }
            return IconButton(
              tooltip: 'Mood',
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (context) => const MoodSelector(),
                );
              },
              icon: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(currentMood, style: const TextStyle(fontSize: 18)),
              ),
            );
          },
        ),
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chats'),
            Text(
              'Your recent conversations',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () {
              showSearch(context: context, delegate: UserSearchDelegate());
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded),
            tooltip: 'My QR Code',
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.qrCode);
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Menu',
            onSelected: _openMenu,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'Create Group', child: Text('Create Group')),
              PopupMenuItem(value: 'Edit Profile', child: Text('Edit Profile')),
              PopupMenuItem(value: 'Settings', child: Text('Settings')),
              PopupMenuItem(
                value: 'Mark All as Read',
                child: Text('Mark All as Read'),
              ),
              PopupMenuItem(
                value: 'Unblock Requests',
                child: Text('Unblock Requests'),
              ),
              PopupMenuDivider(),
              PopupMenuItem(value: 'Logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: Consumer(
        builder: (context, ref, _) {
          final user = ref.watch(authStateProvider).value;
          if (user == null) {
            return const Center(child: Text('Please log in'));
          }

          final chatsAsync = ref.watch(chatsProvider);
          final groups = ref.watch(groupsProvider);

          return chatsAsync.when(
            data: (chats) {
              if (chats.isEmpty && groups.isEmpty) {
                return _EmptyChatState(
                  onSearchPressed: () {
                    showSearch(
                      context: context,
                      delegate: UserSearchDelegate(),
                    );
                  },
                );
              }

              final combined = <Map<String, dynamic>>[
                ...chats.map((c) => {'type': 'chat', 'data': c}),
                ...groups.map((g) => {'type': 'group', 'data': g}),
              ];

              combined.sort((a, b) {
                DateTime? aTime;
                DateTime? bTime;

                if (a['type'] == 'chat') {
                  aTime = ((a['data'] as Map<String, dynamic>)['lastMessageAt']
                          as Timestamp?)
                      ?.toDate();
                } else {
                  aTime = (a['data'] as GroupModel).lastMessageAt;
                }

                if (b['type'] == 'chat') {
                  bTime = ((b['data'] as Map<String, dynamic>)['lastMessageAt']
                          as Timestamp?)
                      ?.toDate();
                } else {
                  bTime = (b['data'] as GroupModel).lastMessageAt;
                }

                return (bTime ?? DateTime.fromMillisecondsSinceEpoch(0))
                    .compareTo(aTime ?? DateTime.fromMillisecondsSinceEpoch(0));
              });

              _startSyncForAllChats(chats);

              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.surface,
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  itemCount: combined.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = combined[index];
                    if (item['type'] == 'chat') {
                      final chat = item['data'] as Map<String, dynamic>;
                      final participants = List<String>.from(
                        chat['participants'] ?? [],
                      );
                      final otherUserId = participants.firstWhere(
                        (id) => id != user.uid && id.isNotEmpty,
                        orElse: () => '',
                      );

                      if (otherUserId.isEmpty) return const SizedBox.shrink();

                      final unreadCount = (chat['unreadCount']
                              as Map<String, dynamic>?)?[user.uid] ??
                          0;
                      final lastMessage = chat['lastMessage']?.toString() ?? '';
                      final lastMessageAt =
                          (chat['lastMessageAt'] as Timestamp?)?.toDate();

                      return StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(otherUserId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const _ConversationTilePlaceholder();
                          }

                          final userData =
                              snapshot.data!.data() as Map<String, dynamic>?;
                          final username = userData?['username']?.toString() ??
                              'Unknown User';
                          final profilePhotoUrl =
                              userData?['profileImage']?.toString() ?? '';
                          final mood = userData?['mood']?.toString() ?? '';
                          final userStatus =
                              userData?['status']?.toString() ?? 'offline';
                          final lastSeen =
                              (userData?['lastSeen'] as Timestamp?)?.toDate();

                          final subtitle = lastMessage.trim().isNotEmpty
                              ? lastMessage
                              : (userStatus == 'online'
                                  ? 'Online'
                                  : _formatLastSeen(lastSeen));

                          return _ConversationTile(
                            title: username,
                            subtitle: subtitle,
                            timeText: _formatTileTime(lastMessageAt),
                            avatarUrl: profilePhotoUrl,
                            badgeText:
                                unreadCount > 0 ? unreadCount.toString() : null,
                            moodText: mood.isNotEmpty ? mood : null,
                            isOnline: userStatus == 'online',
                            onTap: () async {
                              await Navigator.pushNamed(
                                context,
                                AppRoutes.chat,
                                arguments: {
                                  'chatId': chat['id'] ?? '',
                                  'receiverId': otherUserId,
                                  'currentUserId': user.uid,
                                },
                              );
                              ref.invalidate(chatsProvider);
                            },
                            onLongPress: () => _deleteChat(
                              chat['id']?.toString() ?? '',
                              username,
                            ),
                          );
                        },
                      );
                    }

                    final group = item['data'] as GroupModel;
                    return _ConversationTile(
                      title: group.name,
                      subtitle: group.lastMessage.isNotEmpty
                          ? group.lastMessage
                          : '${group.participants.length} members',
                      timeText: _formatTileTime(group.lastMessageAt),
                      avatarUrl: group.avatarUrl ?? '',
                      badgeText: 'Group',
                      isGroup: true,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.groupChat,
                          arguments: {
                            'groupId': group.id,
                            'currentUserId': user.uid,
                          },
                        );
                      },
                      onLongPress: () => _leaveGroup(group, user.uid),
                    );
                  },
                ),
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

class _ConversationTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String timeText;
  final String avatarUrl;
  final String? badgeText;
  final String? moodText;
  final bool isOnline;
  final bool isGroup;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ConversationTile({
    required this.title,
    required this.subtitle,
    required this.timeText,
    required this.avatarUrl,
    required this.onTap,
    this.badgeText,
    this.moodText,
    this.isOnline = false,
    this.isGroup = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    backgroundImage:
                        avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl.isEmpty
                        ? Icon(
                            isGroup
                                ? Icons.groups_rounded
                                : Icons.person_rounded,
                            color: theme.colorScheme.onPrimaryContainer,
                          )
                        : null,
                  ),
                  if (!isGroup)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: isOnline
                              ? Colors.green.shade500
                              : Colors.grey.shade400,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (moodText != null) ...[
                          const SizedBox(width: 6),
                          Text(moodText!, style: const TextStyle(fontSize: 13)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (badgeText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isGroup
                            ? theme.colorScheme.secondaryContainer
                            : theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badgeText!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isGroup
                              ? theme.colorScheme.onSecondaryContainer
                              : theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationTilePlaceholder extends StatelessWidget {
  const _ConversationTilePlaceholder();

  @override
  Widget build(BuildContext context) {
    final shade = Theme.of(context).brightness == Brightness.dark
        ? Colors.white12
        : Colors.black12;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(radius: 26, backgroundColor: shade),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, width: 120, color: shade),
                const SizedBox(height: 8),
                Container(height: 12, width: 170, color: shade),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  final VoidCallback onSearchPressed;

  const _EmptyChatState({required this.onSearchPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.forum_rounded,
                size: 42,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a new chat from search or create a group.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onSearchPressed,
              icon: const Icon(Icons.person_search_rounded),
              label: const Text('Find people'),
            ),
          ],
        ),
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
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
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
  Widget buildResults(BuildContext context) => _buildUserList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildUserList(context);

  Widget _buildUserList(BuildContext context) {
    if (query.trim().isEmpty) {
      return const Center(child: Text('Search users by username'));
    }

    return FutureBuilder<QuerySnapshot>(
      future: _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(20)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;
        if (users.isEmpty) return const Center(child: Text('No users found'));

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final userData = users[index].data() as Map<String, dynamic>;
            final username = userData['username']?.toString() ?? 'Unknown';
            final email = userData['email']?.toString() ?? '';
            final profileUrl = userData['profileImage']?.toString() ?? '';

            return ListTile(
              tileColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              leading: CircleAvatar(
                backgroundImage:
                    profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                child: profileUrl.isEmpty
                    ? const Icon(Icons.person_rounded)
                    : null,
              ),
              title: Text(username),
              subtitle: Text(email),
              onTap: () async {
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser == null) return;
                final currentUserId = currentUser.uid;
                final receiverId = userData['uid'] as String? ?? '';
                if (receiverId.isEmpty) return;

                final chatIdParts = [currentUserId, receiverId]..sort();
                final generatedChatId = chatIdParts.join('_');

                final existingChatsQuery = await _firestore
                    .collection('chats')
                    .where('participants', arrayContains: currentUserId)
                    .get();

                String? existingChatId;
                for (final doc in existingChatsQuery.docs) {
                  final participants = List<String>.from(
                    doc.data()['participants'] ?? [],
                  );
                  final isDirectChat = participants.contains(currentUserId) &&
                      participants.contains(receiverId) &&
                      participants.length == 2;
                  if (isDirectChat) {
                    existingChatId = doc.id;
                    break;
                  }
                }

                final participantUsernames = <String>[];
                for (final uid in [currentUserId, receiverId]) {
                  final userDoc =
                      await _firestore.collection('users').doc(uid).get();
                  participantUsernames.add(
                    userDoc.data()?['username']?.toString() ?? 'Unknown',
                  );
                }

                final chatService = ChatService(AppDatabase.instance);
                final finalChatId = existingChatId ?? generatedChatId;
                await chatService.ensureChatExists(
                    finalChatId,
                    [
                      currentUserId,
                      receiverId,
                    ],
                    participantUsernames: participantUsernames);

                close(context, userData);
                Navigator.pushNamed(
                  context,
                  AppRoutes.chat,
                  arguments: {
                    'chatId': finalChatId,
                    'receiverId': receiverId,
                    'currentUserId': currentUserId,
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
