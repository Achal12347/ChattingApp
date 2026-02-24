import 'dart:async';
import 'dart:io';

import './block_reason_display.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/auth_provider.dart';
import '../providers/message_provider.dart';
import '../providers/chat_provider.dart';

class ChatInput extends ConsumerStatefulWidget {
  final String chatId;
  final String receiverId;
  final bool isBlockedBy;
  final bool isBlocking;
  final String? blockReason;
  final String? unblockReason;
  final VoidCallback? onSendUnblockRequest;
  final VoidCallback? onUnblock;
  final bool isGroupChat;
  final String? groupId;

  const ChatInput({
    super.key,
    required this.chatId,
    required this.receiverId,
    this.isBlockedBy = false,
    this.isBlocking = false,
    this.blockReason,
    this.unblockReason,
    this.onSendUnblockRequest,
    this.onUnblock,
    this.isGroupChat = false,
    this.groupId,
  });

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  bool _isSending = false;
  bool _showEmojiPicker = false;
  bool _isTyping = false;
  Timer? _typingTimer;

  final ImagePicker _imagePicker = ImagePicker();

  void _sendMessage(
      {String? content, String? mediaUrl, String? mediaType}) async {
    final messageContent = content ?? _controller.text.trim();
    if (messageContent.isEmpty && (mediaUrl == null || mediaType == null))
      return;

    setState(() {
      _isSending = true;
      _showEmojiPicker = false; // Hide emoji picker when sending
    });

    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null) {
      setState(() {
        _isSending = false;
      });
      return;
    }

    try {
      if (widget.isGroupChat) {
        ref.read(sendGroupMessageProvider({
          'groupId': widget.groupId!,
          'senderId': currentUser!.uid,
          'content': messageContent,
        }));
      } else if (mediaUrl != null && mediaType != null) {
        ref.read(sendMediaMessageProvider({
          'chatId': widget.chatId,
          'senderId': currentUser!.uid,
          'receiverId': widget.receiverId,
          'mediaUrl': mediaUrl,
          'mediaType': mediaType,
          'caption': messageContent,
        }));
      } else {
        ref.read(sendMessageProvider({
          'chatId': widget.chatId,
          'senderId': currentUser!.uid,
          'receiverId': widget.receiverId,
          'content': messageContent,
        }));
      }
      _controller.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _onTextChanged(String text) {
    if (widget.isGroupChat) return; // Disable typing for group chats
    final isCurrentlyTyping = text.isNotEmpty;
    if (_isTyping != isCurrentlyTyping) {
      setState(() {
        _isTyping = isCurrentlyTyping;
      });
      _updateTypingStatus(isCurrentlyTyping);
    }
  }

  void _updateTypingStatus(bool isTyping) {
    final chatService = ref.read(chatServiceProvider);
    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null) return;

    if (isTyping) {
      chatService.startTyping(widget.chatId, currentUser.uid);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _updateTypingStatus(false);
      });
    } else {
      _typingTimer?.cancel();
      chatService.stopTyping(widget.chatId, currentUser.uid);
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final text = _controller.text;
    final selection = _controller.selection;
    final newText =
        text.replaceRange(selection.start, selection.end, emoji.emoji);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + emoji.emoji.length,
      ),
    );
  }

  Future<void> _pickFile() async {
    if (widget.isBlockedBy || widget.isBlocking || widget.isGroupChat) return;

    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final filePath = file.path;
      if (filePath == null) return;

      setState(() {
        _isSending = true;
      });

      try {
        final mediaUrl = await ref
            .read(firebaseStorageServiceProvider)
            .uploadFile(File(filePath));
        _sendMessage(mediaUrl: mediaUrl, mediaType: 'file');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send file: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSending = false;
          });
        }
      }
    }
  }

  Future<void> _pickImage() async {
    if (widget.isBlockedBy || widget.isBlocking || widget.isGroupChat) return;

    final permissionStatus = await Permission.photos.request();
    if (!permissionStatus.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission denied to access gallery')),
      );
      return;
    }

    final pickedFile =
        await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() {
      _isSending = true;
    });

    try {
      final mediaUrl = await ref
          .read(firebaseStorageServiceProvider)
          .uploadFile(File(pickedFile.path));
      _sendMessage(mediaUrl: mediaUrl, mediaType: 'image');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send image: $e')),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _takePhoto() async {
    if (widget.isBlockedBy || widget.isBlocking || widget.isGroupChat) return;

    final permissionStatus = await Permission.camera.request();
    if (!permissionStatus.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission denied to access camera')),
      );
      return;
    }

    final pickedFile = await _imagePicker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return;

    setState(() {
      _isSending = true;
    });

    try {
      final mediaUrl = await ref
          .read(firebaseStorageServiceProvider)
          .uploadFile(File(pickedFile.path));
      _sendMessage(mediaUrl: mediaUrl, mediaType: 'image');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send photo: $e')),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.isBlockedBy)
          BlockReasonDisplay(
            blockReason: widget.blockReason,
            onSendUnblockRequest: widget.onSendUnblockRequest!,
          )
        else if (widget.isBlocking)
          BlockReasonDisplay(
            blockReason: widget.unblockReason,
            onUnblock: widget.onUnblock!,
          ),
        if (_showEmojiPicker)
          SizedBox(
            height: 250,
            child: EmojiPicker(
              onEmojiSelected: _onEmojiSelected,
              config: Config(),
            ),
          ),
        SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions,
                    color: _showEmojiPicker ? Colors.blue : Colors.grey,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _toggleEmojiPicker,
                ),
                if (!widget.isGroupChat)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.attach_file),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: (value) {
                      switch (value) {
                        case 'file':
                          _pickFile();
                          break;
                        case 'camera':
                          _takePhoto();
                          break;
                        case 'gallery':
                          _pickImage();
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem<String>(
                        value: 'file',
                        child: Text('Pick File'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'camera',
                        child: Text('Take Photo'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'gallery',
                        child: Text('Pick Image'),
                      ),
                    ],
                  ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    onChanged: _onTextChanged,
                    maxLines: null,
                    enabled: !widget.isBlockedBy && !widget.isBlocking,
                    decoration: InputDecoration(
                      hintText: widget.isBlockedBy || widget.isBlocking
                          ? 'Messaging disabled'
                          : widget.isGroupChat
                              ? 'Type a group message...'
                              : 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _isSending
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: (_controller.text.trim().isEmpty ||
                                  widget.isBlockedBy ||
                                  widget.isBlocking)
                              ? Colors.grey.shade300
                              : Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: (_controller.text.trim().isEmpty ||
                                  widget.isBlockedBy ||
                                  widget.isBlocking)
                              ? null
                              : () => _sendMessage(),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
