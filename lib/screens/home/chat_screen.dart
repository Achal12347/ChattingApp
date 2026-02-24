import '../../providers/unblock_request_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../providers/chat_provider.dart';
import '../../providers/message_provider.dart';
import '../../widgets/chat_input.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/relationship_tag_dialog.dart';
import '../../widgets/typing_indicator.dart';
import '../../services/relationship_service.dart';

// ChatScreen takes chatId, receiverId, and currentUserId
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

  static const Map<String, String> moodMessages = {
    '😊': 'Available',
    '😔': 'Feeling low',
    '😴': 'Don’t disturb if not urgent',
    '😡': 'Irritated',
    '🤒': 'Not feeling well',
    '⚪': 'default',
  };

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    // Start syncing messages
    final chatService = ref.read(chatServiceProvider);
    chatService.syncMessages(widget.chatId, widget.currentUserId);
    // Mark all messages as read to reset unread badge and update status
    try {
      await chatService.markAllMessagesAsRead(
          widget.chatId, widget.currentUserId);
      print('ChatScreen: Successfully marked all messages as read.');
    } catch (e) {
      print('ChatScreen: Error marking messages as read: $e');
    }
    // Debug logs
    print(
        'ChatScreen: didChangeDependencies called with chatId=${widget.chatId} and currentUserId=${widget.currentUserId}');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _moodTimer?.cancel();
    _periodicTimer?.cancel();
    super.dispose();
  }

  void _showTagRelationshipDialog() async {
    final currentTag = await _relationshipService.getRelationshipTag(
      widget.currentUserId,
      widget.receiverId,
    );
    showDialog(
      context: context,
      builder: (context) => RelationshipTagDialog(
        initialTag: currentTag,
        onTagSelected: (tag) async {
          await _relationshipService.setRelationshipTag(
            widget.currentUserId,
            widget.receiverId,
            tag,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Relationship tagged as $tag')),
          );
        },
      ),
    );
  }

  void _showBlockUserDialog() {
    final reasonController = TextEditingController();
    showDialog(
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
    showDialog(
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

              if (canSendRequest) {
                await ref
                    .read(unblockRequestProvider.notifier)
                    .sendUnblockRequest(widget.receiverId, message: message);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unblock request sent.')),
                );
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

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.chatId));
    final isBlockedAsync = ref.watch(isBlockedByProvider(widget.receiverId));

    // Debug log for messagesAsync state
    print('ChatScreen: messagesProvider watched for chatId=${widget.chatId}');

    if (widget.chatId.isEmpty ||
        widget.receiverId.isEmpty ||
        widget.currentUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Error"),
        ),
        body: const Center(child: Text("Invalid chat parameters")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.receiverId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.exists) {
              final userData = snapshot.data!.data() as Map<String, dynamic>;
              final username = userData['username'] ?? 'Unknown User';
              final fullName = userData['fullName'] ?? '';
              final profilePhotoUrl = userData['profileImage'] ?? '';
              final userStatus = userData['status'] ?? 'offline';
              final lastSeen = (userData['lastSeen'] as Timestamp?)?.toDate();
              final privacySettings =
                  Map<String, String>.from(userData['privacySettings'] ?? {});
              final lastSeenPrivacy = privacySettings['lastSeen'] ?? 'everyone';

              final mood = userData['mood'] ?? '';
              if (mood != _currentMood) {
                _currentMood = mood;
                _showMood = true;
                _moodTimer?.cancel();
                _moodTimer = Timer(const Duration(seconds: 3), () {
                  if (mounted) {
                    setState(() {
                      _showMood = false;
                    });
                  }
                });
                _periodicTimer?.cancel();
                if (mood.isNotEmpty) {
                  _periodicTimer =
                      Timer.periodic(const Duration(seconds: 15), (timer) {
                    if (mounted) {
                      setState(() {
                        _showMood = true;
                      });
                      _moodTimer?.cancel();
                      _moodTimer = Timer(const Duration(seconds: 3), () {
                        if (mounted) {
                          setState(() {
                            _showMood = false;
                          });
                        }
                      });
                    }
                  });
                }
              }

              return Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundImage: profilePhotoUrl.isNotEmpty
                          ? NetworkImage(profilePhotoUrl)
                          : null,
                      child: profilePhotoUrl.isEmpty
                          ? const Icon(Icons.person, size: 16)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      // Navigate to user2 profile screen
                      Navigator.pushNamed(context, '/profile', arguments: {
                        'userId': widget.receiverId,
                      });
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_showMood && _currentMood.isNotEmpty)
                          Text(
                            '$_currentMood "${moodMessages[_currentMood] ?? "default"}"',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.blueAccent,
                            ),
                          )
                        else if (lastSeenPrivacy == 'everyone')
                          if (userStatus == 'online')
                            const Text(
                              'Online',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                              ),
                            )
                          else if (lastSeen != null)
                            Text(
                              'Last seen ${DateFormat.yMd().add_jm().format(lastSeen)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: 'Menu',
                    icon: const Icon(Icons.more_vert),
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
                        case 'media':
                          // TODO: Implement media, links, docs
                          print('Selected: Media, links, docs');
                          break;
                        case 'search':
                          // TODO: Implement search
                          print('Selected: Search');
                          break;
                        case 'mute':
                          // TODO: Implement mute notifications
                          print('Selected: Mute notifications');
                          break;
                        case 'disappearing':
                          // TODO: Implement disappearing messages
                          print('Selected: Disappearing messages');
                          break;
                        case 'wallpaper':
                          // TODO: Implement wallpaper
                          print('Selected: Wallpaper');
                          break;
                        case 'block':
                          _showBlockUserDialog();
                          break;
                        case 'report':
                          // TODO: Implement report user
                          print('Selected: Report');
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                          value: 'profile', child: Text("View profile")),
                      const PopupMenuItem(
                          value: 'tagRelationship',
                          child: Text("Tag Relationship")),
                      const PopupMenuItem(
                          value: 'media', child: Text("Media, links, docs")),
                      const PopupMenuItem(
                          value: 'search', child: Text("Search")),
                      const PopupMenuItem(
                          value: 'mute', child: Text("Mute notifications")),
                      const PopupMenuItem(
                          value: 'disappearing',
                          child: Text("Disappearing messages")),
                      const PopupMenuItem(
                          value: 'wallpaper', child: Text("Wallpaper")),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'block', child: Text("Block")),
                      const PopupMenuItem(
                          value: 'report', child: Text("Report")),
                    ],
                  ),
                ],
              );
            }
            return const Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  child: CircularProgressIndicator(),
                ),
                SizedBox(width: 8),
                Text('Loading...'),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text("Say hello 👋"));
                }

                // Scroll to bottom when messages update
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                print(
                    'ChatScreen: Building ListView with ${messages.length} messages');
                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (_, index) {
                    final msg = messages[index];
                    print(
                        'ChatScreen: Building MessageBubble for message ${msg.id}, content: ${msg.content}');
                    return MessageBubble(
                      message: msg,
                      currentUserId: widget.currentUserId,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
          // Show total message count at the bottom
          messagesAsync.when(
            data: (messages) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[100],
              child: Text(
                'Total messages: ${messages.length}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (error, stack) => const SizedBox.shrink(),
          ),
          // Typing indicator
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .doc(widget.chatId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final typingUsers =
                    List<String>.from(data['typingUsers'] ?? []);
                if (typingUsers.contains(widget.receiverId)) {
                  return const TypingIndicator();
                }
              }
              return const SizedBox.shrink();
            },
          ),
          isBlockedAsync.when(
            data: (isBlockedBy) {
              final blockedUsers = ref.watch(blockedUsersProvider);
              final isBlocking = blockedUsers.contains(widget.receiverId);
              String? blockReason;
              String? unblockReason;
              if (isBlockedBy) {
                blockReason = 'You are blocked by this user';
              }
              if (isBlocking) {
                unblockReason = 'You have blocked this user';
              }
              return ChatInput(
                chatId: widget.chatId,
                receiverId: widget.receiverId,
                isBlockedBy: isBlockedBy,
                isBlocking: isBlocking,
                blockReason: blockReason,
                unblockReason: unblockReason,
                onSendUnblockRequest: _showUnblockRequestDialog,
                onUnblock: () async {
                  await ref
                      .read(blockedUsersProvider.notifier)
                      .unblockUser(widget.receiverId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User unblocked')),
                  );
                },
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (error, stack) => Text('Error: $error'),
          ),
        ],
      ),
    );
  }
}
