import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_routes.dart';
import '../../providers/chat_provider.dart';
import '../../providers/message_provider.dart';
import '../../widgets/chat_input.dart';
import '../../widgets/message_bubble.dart';

class GroupChatScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String currentUserId;

  const GroupChatScreen({
    super.key,
    this.groupId = '',
    this.currentUserId = '',
  });

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final ScrollController _scrollController = ScrollController();
  String _groupName = 'Loading...';
  Map<String, Map<String, dynamic>> _users = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeGroupChat();
    });
  }

  Future<void> _initializeGroupChat() async {
    if (widget.groupId.isEmpty || widget.currentUserId.isEmpty) return;
    final chatService = ref.read(chatServiceProvider);
    chatService.syncMessages(widget.groupId, widget.currentUserId);
    await _fetchGroupData();
    await _markAllAsRead();
  }

  Future<void> _fetchGroupData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();
      if (!doc.exists) return;

      final data = doc.data();
      if (data == null) return;

      final groupName = data['name']?.toString() ?? 'Unknown Group';
      final participants = List<String>.from(data['participants'] ?? []);

      if (mounted) {
        setState(() {
          _groupName = groupName;
        });
      }

      if (participants.isEmpty) return;

      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: participants)
          .get();
      final users = {for (final doc in usersSnapshot.docs) doc.id: doc.data()};

      if (mounted) {
        setState(() {
          _users = users;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _groupName = 'Unknown Group');
    }
  }

  Future<void> _markAllAsRead() async {
    if (widget.groupId.isEmpty || widget.currentUserId.isEmpty) return;
    await ref
        .read(chatServiceProvider)
        .markAllMessagesAsRead(widget.groupId, widget.currentUserId);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groupId.isEmpty || widget.currentUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Invalid group parameters')),
      );
    }

    final messagesAsync = ref.watch(groupMessagesProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              AppRoutes.groupProfile,
              arguments: {'groupId': widget.groupId},
            );
          },
          borderRadius: BorderRadius.circular(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_groupName, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                '${_users.length} members',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            tooltip: 'Mark all as read',
            onPressed: _markAllAsRead,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.pushNamed(
                  context,
                  AppRoutes.groupSettings,
                  arguments: {'groupId': widget.groupId},
                );
              } else if (value == 'profile') {
                Navigator.pushNamed(
                  context,
                  AppRoutes.groupProfile,
                  arguments: {'groupId': widget.groupId},
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'settings', child: Text('Group Settings')),
              PopupMenuItem(value: 'profile', child: Text('Group Profile')),
            ],
          ),
        ],
      ),
      body: DecoratedBox(
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
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                data: (messages) {
                  if (messages.isEmpty) {
                    return const _EmptyGroupChatView();
                  }

                  for (final msg in messages) {
                    if (!msg.isRead && msg.senderId != widget.currentUserId) {
                      ref
                          .read(chatServiceProvider)
                          .markMessageAsRead(widget.groupId, msg.id);
                    }
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!_scrollController.hasClients) return;
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 10, bottom: 12),
                    itemCount: messages.length,
                    itemBuilder: (_, index) {
                      final msg = messages[index];
                      final sender = _users[msg.senderId];
                      return MessageBubble(
                        message: msg,
                        currentUserId: widget.currentUserId,
                        isGroupChat: true,
                        senderName:
                            sender?['username']?.toString() ?? 'Unknown User',
                        senderAvatarUrl: sender?['profileImage']?.toString(),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
              ),
            ),
            ChatInput(
              chatId: widget.groupId,
              receiverId: '',
              isGroupChat: true,
              groupId: widget.groupId,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyGroupChatView extends StatelessWidget {
  const _EmptyGroupChatView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.groups_rounded,
                size: 38,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No group messages yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start the group conversation.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
