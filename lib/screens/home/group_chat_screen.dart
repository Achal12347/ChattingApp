import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_routes.dart';
import '../../models/message_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/message_provider.dart';
import '../../services/report_service.dart';
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

  bool _isSearchMode = false;
  String _searchQuery = '';
  MessageModel? _replyToMessage;

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
    await _fetchGroupData();
    await chatService.markAllGroupMessagesAsRead(
      groupId: widget.groupId,
      currentUserId: widget.currentUserId,
    );
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
    await ref.read(chatServiceProvider).markAllGroupMessagesAsRead(
          groupId: widget.groupId,
          currentUserId: widget.currentUserId,
        );
  }

  List<MessageModel> _applySearch(List<MessageModel> messages) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return messages;
    return messages.where((msg) {
      return msg.content.toLowerCase().contains(query) ||
          (msg.mediaType?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Future<void> _showMessageActions(MessageModel message) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final isMine = message.senderId == widget.currentUserId;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _replyToMessage = message);
                },
              ),
              if (message.content.trim().isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('Copy text'),
                  onTap: () async {
                    Navigator.pop(context);
                    await Clipboard.setData(
                        ClipboardData(text: message.content));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Copied')));
                  },
                ),
              ListTile(
                leading: const Icon(Icons.emoji_emotions_outlined),
                title: const Text('React'),
                onTap: () {
                  Navigator.pop(context);
                  _showReactionPicker(message);
                },
              ),
              if (isMine)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Delete message'),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteGroupMessage(message.id);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report'),
                onTap: () {
                  Navigator.pop(context);
                  _reportMessage(message);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showReactionPicker(MessageModel message) async {
    const emojis = ['??', '??', '??', '??', '??', '??'];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: emojis.map((emoji) {
                return InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () async {
                    Navigator.pop(context);
                    final chatService = ref.read(chatServiceProvider);
                    if (message.reactions.contains(emoji)) {
                      await chatService.removeGroupReaction(
                          widget.groupId, message.id, emoji);
                    } else {
                      await chatService.addGroupReaction(
                          widget.groupId, message.id, emoji);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteGroupMessage(String messageId) async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .doc(messageId)
        .set({'isDeleted': true}, SetOptions(merge: true));
  }

  Future<void> _reportMessage(MessageModel message) async {
    final reasonController = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report message'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Report'),
          ),
        ],
      ),
    );

    if (submit != true) return;

    final reason = reasonController.text.trim();
    if (reason.isEmpty) return;

    await ref.read(reportServiceProvider).reportMessage(
          reporterId: widget.currentUserId,
          chatId: widget.groupId,
          messageId: message.id,
          reason: reason,
          isGroupChat: true,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Report submitted')));
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
        title: _isSearchMode
            ? TextField(
                autofocus: true,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: const InputDecoration(
                  hintText: 'Search messages',
                  border: InputBorder.none,
                ),
              )
            : InkWell(
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
                    Text(_groupName,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      '${_users.length} members',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
                _isSearchMode ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              setState(() {
                if (_isSearchMode) {
                  _searchQuery = '';
                }
                _isSearchMode = !_isSearchMode;
              });
            },
          ),
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
                  final filteredMessages = _applySearch(messages);
                  final byId = {
                    for (final message in messages) message.id: message,
                  };

                  if (filteredMessages.isEmpty) {
                    return _EmptyGroupChatView(
                        isSearching: _searchQuery.trim().isNotEmpty);
                  }

                  for (final msg in filteredMessages) {
                    if (msg.senderId != widget.currentUserId) {
                      ref.read(chatServiceProvider).markGroupMessageAsRead(
                            groupId: widget.groupId,
                            messageId: msg.id,
                            currentUserId: widget.currentUserId,
                          );
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
                    itemCount: filteredMessages.length,
                    itemBuilder: (_, index) {
                      final msg = filteredMessages[index];
                      final sender = _users[msg.senderId];
                      final reply = msg.replyToMessageId != null
                          ? byId[msg.replyToMessageId!]?.content
                          : null;
                      return MessageBubble(
                        message: msg,
                        currentUserId: widget.currentUserId,
                        isGroupChat: true,
                        senderName:
                            sender?['username']?.toString() ?? 'Unknown User',
                        senderAvatarUrl: sender?['profileImage']?.toString(),
                        replyPreview: reply,
                        onLongPress: () => _showMessageActions(msg),
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
              replyToMessage: _replyToMessage,
              onReplyChanged: (value) =>
                  setState(() => _replyToMessage = value),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyGroupChatView extends StatelessWidget {
  final bool isSearching;

  const _EmptyGroupChatView({this.isSearching = false});

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
                isSearching ? Icons.search_off_rounded : Icons.groups_rounded,
                size: 38,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isSearching ? 'No matching messages' : 'No group messages yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isSearching
                  ? 'Try a different keyword.'
                  : 'Start the group conversation.',
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
