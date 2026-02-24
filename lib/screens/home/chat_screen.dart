import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/message_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/message_provider.dart';
import '../../providers/unblock_request_provider.dart';
import '../../services/relationship_service.dart';
import '../../services/report_service.dart';
import '../../widgets/chat_input.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/relationship_tag_dialog.dart';
import '../../widgets/typing_indicator.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String receiverId;
  final String currentUserId;

  const ChatScreen({
    super.key,
    this.chatId = '',
    this.receiverId = '',
    this.currentUserId = '',
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final RelationshipService _relationshipService = RelationshipService();

  bool _showMood = false;
  String _currentMood = '';
  Timer? _moodTimer;
  Timer? _periodicTimer;

  bool _isSearchMode = false;
  String _searchQuery = '';
  MessageModel? _replyToMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  Future<void> _initializeChat() async {
    if (widget.chatId.isEmpty || widget.currentUserId.isEmpty) return;
    final chatService = ref.read(chatServiceProvider);
    chatService.syncMessages(widget.chatId, widget.currentUserId);
    await chatService.markAllMessagesAsRead(
        widget.chatId, widget.currentUserId);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _moodTimer?.cancel();
    _periodicTimer?.cancel();
    super.dispose();
  }

  String _buildStatusText(String status, DateTime? lastSeen, String privacy) {
    if (_showMood && _currentMood.isNotEmpty) {
      return _currentMood;
    }
    if (privacy != 'everyone') return '';
    if (status == 'online') return 'Online';
    if (lastSeen == null) return 'Offline';
    return 'Last seen ${DateFormat('MMM d, h:mm a').format(lastSeen)}';
  }

  List<MessageModel> _applySearch(List<MessageModel> messages) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return messages;
    return messages.where((msg) {
      return msg.content.toLowerCase().contains(query) ||
          (msg.mediaType?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  void _showTagRelationshipDialog() async {
    final currentTag = await _relationshipService.getRelationshipTag(
        widget.currentUserId, widget.receiverId);
    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (context) => RelationshipTagDialog(
        initialTag: currentTag,
        onTagSelected: (tag) async {
          await _relationshipService.setRelationshipTag(
            widget.currentUserId,
            widget.receiverId,
            tag,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Relationship tagged as $tag')));
        },
      ),
    );
  }

  void _showBlockUserDialog() {
    final reasonController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: 'Reason for blocking'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isNotEmpty) {
                ref
                    .read(blockedUsersProvider.notifier)
                    .blockUser(widget.receiverId, reason);
                Navigator.pop(context);
              }
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _showUnblockRequestDialog() {
    final messageController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Unblock Request'),
        content: TextField(
          controller: messageController,
          decoration: const InputDecoration(hintText: 'Optional message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final message = messageController.text.trim();
              final canSendRequest = await ref
                  .read(unblockRequestProvider.notifier)
                  .checkUnblockRequestLimit(widget.receiverId);

              if (!mounted) return;

              if (canSendRequest) {
                await ref
                    .read(unblockRequestProvider.notifier)
                    .sendUnblockRequest(widget.receiverId, message: message);
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Unblock request sent.')));
              } else {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('You have reached your request limit.')),
                );
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
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
                    _deleteMessage(message);
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
                      await chatService.removeReaction(
                          widget.chatId, message.id, emoji);
                    } else {
                      await chatService.addReaction(
                          widget.chatId, message.id, emoji);
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

  Future<void> _deleteMessage(MessageModel message) async {
    final deleteForEveryone = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message'),
        content: const Text('Delete this message for everyone?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Only for me'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('For everyone'),
          ),
        ],
      ),
    );

    if (deleteForEveryone == null) return;
    await ref.read(deleteMessageProvider({
      'chatId': widget.chatId,
      'messageId': message.id,
      'deleteForEveryone': deleteForEveryone,
    }).future);
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
          chatId: widget.chatId,
          messageId: message.id,
          reason: reason,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Report submitted')));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chatId.isEmpty ||
        widget.receiverId.isEmpty ||
        widget.currentUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Invalid chat parameters')),
      );
    }

    final messagesAsync = ref.watch(messagesProvider(widget.chatId));
    final isBlockedAsync = ref.watch(isBlockedByProvider(widget.receiverId));
    final pendingCountAsync = ref.watch(pendingMessageCountProvider);

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
            : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.receiverId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data?.exists != true) {
                    return const Text('Loading...');
                  }

                  final userData =
                      snapshot.data!.data() as Map<String, dynamic>;
                  final username =
                      userData['username']?.toString() ?? 'Unknown User';
                  final profilePhotoUrl =
                      userData['profileImage']?.toString() ?? '';
                  final userStatus =
                      userData['status']?.toString() ?? 'offline';
                  final mood = userData['mood']?.toString() ?? '';
                  final lastSeen =
                      (userData['lastSeen'] as Timestamp?)?.toDate();
                  final privacySettings = Map<String, String>.from(
                      userData['privacySettings'] ?? {});
                  final lastSeenPrivacy =
                      privacySettings['lastSeen'] ?? 'everyone';

                  if (mood != _currentMood) {
                    _currentMood = mood;
                    _showMood = true;
                    _moodTimer?.cancel();
                    _moodTimer = Timer(const Duration(seconds: 3), () {
                      if (mounted) setState(() => _showMood = false);
                    });

                    _periodicTimer?.cancel();
                    if (mood.isNotEmpty) {
                      _periodicTimer =
                          Timer.periodic(const Duration(seconds: 15), (_) {
                        if (!mounted) return;
                        setState(() => _showMood = true);
                        _moodTimer?.cancel();
                        _moodTimer = Timer(const Duration(seconds: 3), () {
                          if (mounted) setState(() => _showMood = false);
                        });
                      });
                    }
                  }

                  final statusText =
                      _buildStatusText(userStatus, lastSeen, lastSeenPrivacy);

                  return InkWell(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/profile',
                        arguments: {'userId': widget.receiverId},
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: profilePhotoUrl.isNotEmpty
                                  ? NetworkImage(profilePhotoUrl)
                                  : null,
                              child: profilePhotoUrl.isEmpty
                                  ? const Icon(Icons.person_rounded)
                                  : null,
                            ),
                            Positioned(
                              right: -1,
                              bottom: -1,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: userStatus == 'online'
                                      ? Colors.green.shade500
                                      : Colors.grey.shade400,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .scaffoldBackgroundColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              if (statusText.isNotEmpty)
                                Text(
                                  statusText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        color:
                                            _showMood && _currentMood.isNotEmpty
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                      ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
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
          PopupMenuButton<String>(
            tooltip: 'Menu',
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  Navigator.pushNamed(
                    context,
                    '/profile',
                    arguments: {'userId': widget.receiverId},
                  );
                  break;
                case 'tagRelationship':
                  _showTagRelationshipDialog();
                  break;
                case 'block':
                  _showBlockUserDialog();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'profile', child: Text('View profile')),
              PopupMenuItem(
                  value: 'tagRelationship', child: Text('Tag Relationship')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'block', child: Text('Block')),
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
            pendingCountAsync.when(
              data: (count) {
                if (count <= 0) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$count message(s) pending sync',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            Expanded(
              child: messagesAsync.when(
                data: (messages) {
                  final filteredMessages = _applySearch(messages);
                  final byId = {
                    for (final message in messages) message.id: message,
                  };

                  if (filteredMessages.isEmpty) {
                    return _EmptyChatView(
                        isSearching: _searchQuery.trim().isNotEmpty);
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
                      final reply = msg.replyToMessageId != null
                          ? byId[msg.replyToMessageId!]?.content
                          : null;
                      return MessageBubble(
                        message: msg,
                        currentUserId: widget.currentUserId,
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
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data?.exists == true) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final typingUsers =
                      List<String>.from(data['typingUsers'] ?? []);
                  if (typingUsers.contains(widget.receiverId)) {
                    return const Padding(
                      padding: EdgeInsets.only(left: 14, right: 14, bottom: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TypingIndicator(),
                      ),
                    );
                  }
                }
                return const SizedBox.shrink();
              },
            ),
            isBlockedAsync.when(
              data: (isBlockedBy) {
                final blockedUsers = ref.watch(blockedUsersProvider);
                final isBlocking = blockedUsers.contains(widget.receiverId);
                final blockReason =
                    isBlockedBy ? 'You are blocked by this user' : null;
                final unblockReason =
                    isBlocking ? 'You have blocked this user' : null;

                return ChatInput(
                  chatId: widget.chatId,
                  receiverId: widget.receiverId,
                  isBlockedBy: isBlockedBy,
                  isBlocking: isBlocking,
                  blockReason: blockReason,
                  unblockReason: unblockReason,
                  onSendUnblockRequest: _showUnblockRequestDialog,
                  replyToMessage: _replyToMessage,
                  onReplyChanged: (value) =>
                      setState(() => _replyToMessage = value),
                  onUnblock: () async {
                    await ref
                        .read(blockedUsersProvider.notifier)
                        .unblockUser(widget.receiverId);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('User unblocked')));
                  },
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (error, stack) => Text('Error: $error'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChatView extends StatelessWidget {
  final bool isSearching;

  const _EmptyChatView({this.isSearching = false});

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
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearching
                    ? Icons.search_off_rounded
                    : Icons.chat_bubble_outline_rounded,
                size: 38,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isSearching ? 'No matching messages' : 'No messages yet',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              isSearching
                  ? 'Try a different keyword.'
                  : 'Start the conversation with a message.',
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
