import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/chat_provider.dart';
import '../../providers/message_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/chat_input.dart';
import '../../app_routes.dart';

// GroupChatScreen takes groupId, currentUserId
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
  String _groupName = 'Loading...';
  Map<String, Map<String, dynamic>> _users = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start syncing messages
    final chatService = ref.read(chatServiceProvider);
    chatService.syncMessages(widget.groupId, widget.currentUserId);
    // Fetch group name
    _fetchGroupName();
    // Auto-mark all messages as read when entering group screen
    _markAllAsRead();
  }

  Future<void> _fetchGroupName() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();
      if (doc.exists && mounted) {
        final groupName = doc.data()?['name'] ?? 'Unknown Group';
        final participants =
            List<String>.from(doc.data()?['participants'] ?? []);
        setState(() {
          _groupName = groupName;
        });
        // Fetch users
        if (participants.isNotEmpty) {
          final usersSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: participants)
              .get();
          final users = {
            for (var doc in usersSnapshot.docs) doc.id: doc.data(),
          };
          if (mounted) {
            setState(() {
              _users = users;
            });
          }
        }
      } else if (mounted) {
        setState(() {
          _groupName = 'Unknown Group';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _groupName = 'Unknown Group';
        });
      }
    }
  }

  void _markAllAsRead() async {
    if (widget.groupId.isNotEmpty && widget.currentUserId.isNotEmpty) {
      await ref
          .read(chatServiceProvider)
          .markAllMessagesAsRead(widget.groupId, widget.currentUserId);
      // Remove snackbar notification for auto-mark on screen open
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(groupMessagesProvider(widget.groupId));

    if (widget.groupId.isEmpty || widget.currentUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Error"),
        ),
        body: const Center(child: Text("Invalid group parameters")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.groupProfile,
                arguments: {'groupId': widget.groupId});
          },
          child: Text(_groupName),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: _markAllAsRead,
            tooltip: 'Mark all as read',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  Navigator.pushNamed(context, AppRoutes.groupSettings,
                      arguments: {'groupId': widget.groupId});
                  break;
                case 'profile':
                  Navigator.pushNamed(context, AppRoutes.groupProfile,
                      arguments: {'groupId': widget.groupId});
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Text('Group Settings'),
              ),
              const PopupMenuItem(
                value: 'profile',
                child: Text('Group Profile'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text("Say hello 👋"));
                }

                // Mark unread messages as read
                for (final msg in messages) {
                  if (!msg.isRead && msg.senderId != widget.currentUserId) {
                    ref
                        .read(chatServiceProvider)
                        .markMessageAsRead(widget.groupId, msg.id);
                  }
                }

                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (_, index) {
                    final msg = messages[index];
                    final user = _users[msg.senderId];
                    return MessageBubble(
                      message: msg,
                      currentUserId: widget.currentUserId,
                      isGroupChat: true,
                      senderName: user?['username'] ?? 'Unknown User',
                      senderAvatarUrl: user?['profileImage'],
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
    );
  }
}
