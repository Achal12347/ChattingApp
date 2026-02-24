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
    final isCurrentUser = message.senderId == currentUserId;
    final theme = Theme.of(context);
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.74;
    final showSenderInfo = isGroupChat && !isCurrentUser && senderName != null;

    final incomingColor = theme.brightness == Brightness.dark
        ? Colors.grey.shade800
        : Colors.white;
    final outgoingGradient = LinearGradient(
      colors: [
        theme.colorScheme.primary,
        theme.colorScheme.primary.withValues(alpha: 0.85),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSenderInfo)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/profile',
                        arguments: {'userId': message.senderId},
                      );
                    },
                    child: CircleAvatar(
                      radius: 10,
                      backgroundImage:
                          senderAvatarUrl != null && senderAvatarUrl!.isNotEmpty
                              ? NetworkImage(senderAvatarUrl!)
                              : null,
                      child: senderAvatarUrl == null || senderAvatarUrl!.isEmpty
                          ? const Icon(Icons.person, size: 11)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    senderName!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          Align(
            alignment:
                isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              child: Container(
                margin: EdgeInsets.only(
                  left: isCurrentUser ? 42 : 10,
                  right: isCurrentUser ? 10 : 42,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isCurrentUser ? null : incomingColor,
                  gradient: isCurrentUser ? outgoingGradient : null,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isCurrentUser ? 18 : 6),
                    bottomRight: Radius.circular(isCurrentUser ? 6 : 18),
                  ),
                  border: isCurrentUser
                      ? null
                      : Border.all(
                          color: theme.brightness == Brightness.dark
                              ? Colors.white10
                              : Colors.black12,
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.isUrgent)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: UrgentMessageIndicator(isUrgent: true),
                      ),
                    if (message.mediaType == 'image' &&
                        message.mediaUrl != null)
                      _ImageAttachment(url: message.mediaUrl!),
                    if (message.mediaType == 'file' && message.mediaUrl != null)
                      _FileAttachment(
                        url: message.mediaUrl!,
                        isCurrentUser: isCurrentUser,
                      ),
                    if ((message.mediaType == 'image' ||
                            message.mediaType == 'file') &&
                        message.content.isNotEmpty)
                      const SizedBox(height: 8),
                    if (message.isDeleted)
                      Text(
                        'This message was deleted',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: isCurrentUser
                              ? Colors.white.withValues(alpha: 0.82)
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    else if (message.content.isNotEmpty)
                      Text(
                        message.content,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: isCurrentUser
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                          height: 1.28,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('h:mm a').format(message.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isCurrentUser
                                ? Colors.white.withValues(alpha: 0.75)
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (isCurrentUser && !isGroupChat) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message.status == 'sent'
                                ? Icons.done_rounded
                                : Icons.done_all_rounded,
                            size: 15,
                            color: message.status == 'read'
                                ? const Color(0xFF4FC3F7)
                                : Colors.white.withValues(alpha: 0.76),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageAttachment extends StatelessWidget {
  final String url;

  const _ImageAttachment({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: 220,
        height: 220,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 220,
            height: 220,
            color: Theme.of(context).colorScheme.surface,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(strokeWidth: 2),
          );
        },
        errorBuilder: (context, _, __) => Container(
          width: 220,
          height: 220,
          color: Theme.of(context).colorScheme.surface,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_rounded, size: 38),
        ),
      ),
    );
  }
}

class _FileAttachment extends StatelessWidget {
  final String url;
  final bool isCurrentUser;

  const _FileAttachment({required this.url, required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = isCurrentUser
        ? Colors.white.withValues(alpha: 0.2)
        : theme.colorScheme.surface;
    final fg =
        isCurrentUser ? Colors.white : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          return;
        }
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Unable to open file')));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.attach_file_rounded, color: fg, size: 18),
            const SizedBox(width: 6),
            Text(
              'Open file',
              style: theme.textTheme.bodyMedium?.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
