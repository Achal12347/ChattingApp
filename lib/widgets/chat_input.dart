import 'dart:async';
import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/message_provider.dart';
import 'block_reason_display.dart';

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
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isSending = false;
  bool _showEmojiPicker = false;
  bool _isTyping = false;
  Timer? _typingTimer;

  bool get _hasText => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmojiPicker) {
        setState(() => _showEmojiPicker = false);
      }
    });
  }

  Future<void> _sendMessage({
    String? content,
    String? mediaUrl,
    String? mediaType,
  }) async {
    final messageContent = content ?? _controller.text.trim();
    if (messageContent.isEmpty && (mediaUrl == null || mediaType == null)) {
      return;
    }

    setState(() {
      _isSending = true;
      _showEmojiPicker = false;
    });

    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null) {
      if (mounted) setState(() => _isSending = false);
      return;
    }

    try {
      if (widget.isGroupChat) {
        ref.read(
          sendGroupMessageProvider({
            'groupId': widget.groupId!,
            'senderId': currentUser.uid,
            'content': messageContent,
          }),
        );
      } else if (mediaUrl != null && mediaType != null) {
        ref.read(
          sendMediaMessageProvider({
            'chatId': widget.chatId,
            'senderId': currentUser.uid,
            'receiverId': widget.receiverId,
            'mediaUrl': mediaUrl,
            'mediaType': mediaType,
            'caption': messageContent,
          }),
        );
      } else {
        ref.read(
          sendMessageProvider({
            'chatId': widget.chatId,
            'senderId': currentUser.uid,
            'receiverId': widget.receiverId,
            'content': messageContent,
          }),
        );
      }

      _controller.clear();
      _updateTypingStatus(false);
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _onTextChanged(String text) {
    if (mounted) setState(() {});

    if (widget.isGroupChat) return;
    final isCurrentlyTyping = text.trim().isNotEmpty;
    if (_isTyping != isCurrentlyTyping) {
      _isTyping = isCurrentlyTyping;
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
    if (_showEmojiPicker) {
      _focusNode.unfocus();
    } else {
      _focusNode.requestFocus();
    }
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final text = _controller.text;
    final selection = _controller.selection;
    final baseOffset = selection.start < 0 ? text.length : selection.start;
    final extentOffset = selection.end < 0 ? text.length : selection.end;
    final newText = text.replaceRange(baseOffset, extentOffset, emoji.emoji);

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: baseOffset + emoji.emoji.length,
      ),
    );

    _onTextChanged(_controller.text);
  }

  Future<void> _pickFile() async {
    if (widget.isBlockedBy || widget.isBlocking || widget.isGroupChat) return;

    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.first.path;
    if (filePath == null) return;

    setState(() => _isSending = true);
    try {
      final mediaUrl = await ref
          .read(firebaseStorageServiceProvider)
          .uploadFile(File(filePath));
      await _sendMessage(mediaUrl: mediaUrl, mediaType: 'file');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send file: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickImage() async {
    if (widget.isBlockedBy || widget.isBlocking || widget.isGroupChat) return;

    final permissionStatus = await Permission.photos.request();
    if (!permissionStatus.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gallery permission denied')),
      );
      return;
    }

    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile == null) return;

    setState(() => _isSending = true);
    try {
      final mediaUrl = await ref
          .read(firebaseStorageServiceProvider)
          .uploadFile(File(pickedFile.path));
      await _sendMessage(mediaUrl: mediaUrl, mediaType: 'image');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send image: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _takePhoto() async {
    if (widget.isBlockedBy || widget.isBlocking || widget.isGroupChat) return;

    final permissionStatus = await Permission.camera.request();
    if (!permissionStatus.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Camera permission denied')));
      return;
    }

    final pickedFile = await _imagePicker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return;

    setState(() => _isSending = true);
    try {
      final mediaUrl = await ref
          .read(firebaseStorageServiceProvider)
          .uploadFile(File(pickedFile.path));
      await _sendMessage(mediaUrl: mediaUrl, mediaType: 'image');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send photo: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _showAttachmentSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Photo from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Take photo'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file_rounded),
                title: const Text('Send file'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sendingDisabled =
        !_hasText || widget.isBlockedBy || widget.isBlocking || _isSending;

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
            height: 260,
            child: EmojiPicker(
              onEmojiSelected: _onEmojiSelected,
              config: Config(
                emojiViewConfig: EmojiViewConfig(
                  emojiSizeMax: 28 *
                      (defaultTargetPlatform == TargetPlatform.iOS ? 1.2 : 1.0),
                ),
              ),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: theme.brightness == Brightness.dark
                      ? Colors.white10
                      : Colors.black12,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Emoji',
                      icon: Icon(
                        _showEmojiPicker
                            ? Icons.keyboard_rounded
                            : Icons.emoji_emotions_outlined,
                        color: _showEmojiPicker
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      onPressed: _toggleEmojiPicker,
                    ),
                    if (!widget.isGroupChat)
                      IconButton(
                        tooltip: 'Attach',
                        icon: Icon(
                          Icons.add_circle_outline_rounded,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: widget.isBlockedBy || widget.isBlocking
                            ? null
                            : _showAttachmentSheet,
                      ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        onChanged: _onTextChanged,
                        maxLines: null,
                        enabled: !widget.isBlockedBy && !widget.isBlocking,
                        decoration: InputDecoration(
                          hintText: widget.isBlockedBy || widget.isBlocking
                              ? 'Messaging disabled'
                              : widget.isGroupChat
                                  ? 'Message group'
                                  : 'Type a message',
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: sendingDisabled
                            ? theme.colorScheme.outlineVariant
                            : theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                              ),
                        onPressed:
                            sendingDisabled ? null : () => _sendMessage(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
