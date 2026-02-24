import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/message_model.dart';
import 'urgent_message_indicator.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final String currentUserId;
  final bool isGroupChat;
  final String? senderName;
  final String? senderAvatarUrl;

  const MessageBubble({
    super.key,
    required this.message,
    required this.currentUserId,
    this.isGroupChat = false,
    this.senderName,
    this.senderAvatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    try {
      final isCurrentUser = message.senderId == currentUserId;
      final theme = Theme.of(context);
      print(
          'MessageBubble: Building for message ${message.id}, isCurrentUser: $isCurrentUser, content: ${message.content}, status: ${message.status}');

      final showSenderInfo =
          isGroupChat && !isCurrentUser && senderName != null;

      return Column(
        crossAxisAlignment:
            isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSenderInfo) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 12, right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/profile',
                          arguments: {'userId': message.senderId});
                    },
                    child: CircleAvatar(
                      radius: 12,
                      backgroundImage:
                          senderAvatarUrl != null && senderAvatarUrl!.isNotEmpty
                              ? NetworkImage(senderAvatarUrl!)
                              : null,
                      child: senderAvatarUrl == null || senderAvatarUrl!.isEmpty
                          ? const Icon(Icons.person, size: 12)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    senderName!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
          Align(
            alignment:
                isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: const BoxConstraints(maxWidth: 280),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? const Color(0xFF007AFF) // iMessage blue
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isCurrentUser
                      ? const Radius.circular(18)
                      : const Radius.circular(4),
                  bottomRight: isCurrentUser
                      ? const Radius.circular(4)
                      : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: isCurrentUser
                    ? null
                    : Border.all(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isUrgent) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: UrgentMessageIndicator(isUrgent: true),
                    ),
                  ],
                  if (message.mediaType == 'image' &&
                      message.mediaUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        message.mediaUrl!,
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 200,
                            height: 200,
                            color: Colors.grey.shade200,
                            child: const Center(
                                child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 200,
                            height: 200,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image, size: 50),
                          );
                        },
                      ),
                    ),
                    if (message.content.isNotEmpty) const SizedBox(height: 8),
                  ],
                  if (message.mediaType == 'file' &&
                      message.mediaUrl != null) ...[
                    GestureDetector(
                      onTap: () async {
                        // Open file URL
                        try {
                          final url = message.mediaUrl!;
                          if (await canLaunchUrl(Uri.parse(url))) {
                            await launchUrl(Uri.parse(url));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Could not open file URL')),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error opening file: $e')),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isCurrentUser
                              ? Colors.white.withOpacity(0.2)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.attach_file,
                              color:
                                  isCurrentUser ? Colors.white : Colors.black87,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'File', // You can extract file name from URL if needed
                              style: TextStyle(
                                color: isCurrentUser
                                    ? Colors.white
                                    : Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (message.content.isNotEmpty) const SizedBox(height: 8),
                  ],
                  if (message.content.isNotEmpty)
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isCurrentUser ? Colors.white : Colors.black87,
                        fontSize: 16,
                        height: 1.3,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: isCurrentUser
                              ? Colors.white.withOpacity(0.7)
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isCurrentUser && !isGroupChat) ...[
                        const SizedBox(width: 6),
                        Icon(
                          message.status == 'sent'
                              ? Icons.done // Single tick for sent
                              : Icons
                                  .done_all, // Double tick for delivered or read
                          size: 12,
                          color: message.status == 'read'
                              ? Colors.green // Green for read
                              : isCurrentUser // Check if current user for default color
                                  ? Colors.white.withOpacity(0.6)
                                  : Colors.grey
                                      .shade600, // Default color for delivered
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } catch (e, stack) {
      print('MessageBubble: Error building message ${message.id}: $e\n$stack');
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.red,
        child: Text('Error: $e'),
      );
    }
  }

  String _formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }
}
