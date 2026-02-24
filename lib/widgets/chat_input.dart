import 'dart:async';
import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../models/message_model.dart';
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
  final MessageModel? replyToMessage;
  final ValueChanged<MessageModel?>? onReplyChanged;

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
    this.replyToMessage,
    this.onReplyChanged,
  });

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isSending = false;
  bool _showEmojiPicker = false;
  bool _isTyping = false;
  bool _isRecordingVoice = false;
  Timer? _typingTimer;
  String? _recordingPath;

  bool get _hasText => _controller.text.trim().isNotEmpty;
  bool get _isInputLocked => widget.isBlockedBy || widget.isBlocking;

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

    final replyId = widget.replyToMessage?.id;

    try {
      if (widget.isGroupChat) {
        ref.read(
          sendGroupMessageProvider({
            'groupId': widget.groupId!,
            'senderId': currentUser.uid,
            'content': messageContent,
            'mediaUrl': mediaUrl,
            'mediaType': mediaType,
            'replyToMessageId': replyId,
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
            'replyToMessageId': replyId,
          }),
        );
      } else {
        ref.read(
          sendMessageProvider({
            'chatId': widget.chatId,
            'senderId': currentUser.uid,
            'receiverId': widget.receiverId,
            'content': messageContent,
            'replyToMessageId': replyId,
          }),
        );
      }

      _controller.clear();
      _updateTypingStatus(false);
      widget.onReplyChanged?.call(null);
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _onTextChanged(String text) {
    if (mounted) setState(() {});

    if (widget.isGroupChat || _isInputLocked) return;
    final isCurrentlyTyping = text.trim().isNotEmpty;
    if (_isTyping != isCurrentlyTyping) {
      _isTyping = isCurrentlyTyping;
      _updateTypingStatus(isCurrentlyTyping);
    }
  }

  void _updateTypingStatus(bool isTyping) {
    if (widget.isGroupChat) return;

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
      selection:
          TextSelection.collapsed(offset: baseOffset + emoji.emoji.length),
    );

    _onTextChanged(_controller.text);
  }

  Future<void> _sendMediaAsset(String filePath, String mediaType) async {
    setState(() => _isSending = true);
    try {
      final mediaUrl = await ref
          .read(firebaseStorageServiceProvider)
          .uploadFile(File(filePath));
      await _sendMessage(mediaUrl: mediaUrl, mediaType: mediaType);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to send media: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickFile() async {
    if (_isInputLocked) return;

    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.first.path;
    if (filePath == null) return;

    await _sendMediaAsset(filePath, 'file');
  }

  Future<void> _pickImage() async {
    if (_isInputLocked) return;

    final permissionStatus = await Permission.photos.request();
    if (!permissionStatus.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gallery permission denied')));
      return;
    }

    final pickedFile =
        await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    await _sendMediaAsset(pickedFile.path, 'image');
  }

  Future<void> _takePhoto() async {
    if (_isInputLocked) return;

    final permissionStatus = await Permission.camera.request();
    if (!permissionStatus.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission denied')));
      return;
    }

    final pickedFile = await _imagePicker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return;

    await _sendMediaAsset(pickedFile.path, 'image');
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isInputLocked || _isSending) return;

    if (_isRecordingVoice) {
      final path = await _audioRecorder.stop();
      if (mounted) {
        setState(() {
          _isRecordingVoice = false;
          _recordingPath = null;
        });
      }
      if (path != null && path.isNotEmpty) {
        await _sendMediaAsset(path, 'voice');
      }
      return;
    }

    final permissionStatus = await Permission.microphone.request();
    if (!permissionStatus.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')));
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final filePath =
        '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
      path: filePath,
    );

    if (mounted) {
      setState(() {
        _isRecordingVoice = true;
        _recordingPath = filePath;
      });
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
    _audioRecorder.dispose();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSendText = (_hasText || widget.replyToMessage != null) &&
        !_isInputLocked &&
        !_isSending;

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
        if (widget.replyToMessage != null)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Replying to message',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.replyToMessage!.content.isNotEmpty
                            ? widget.replyToMessage!.content
                            : (widget.replyToMessage!.mediaType == 'voice'
                                ? 'Voice note'
                                : widget.replyToMessage!.mediaType == 'image'
                                    ? 'Photo'
                                    : widget.replyToMessage!.mediaType == 'file'
                                        ? 'Attachment'
                                        : 'Message'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => widget.onReplyChanged?.call(null),
                ),
              ],
            ),
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
        if (_isRecordingVoice && _recordingPath != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Row(
              children: [
                Icon(Icons.mic_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                const Expanded(child: Text('Recording voice note...')),
                TextButton(
                  onPressed: _toggleVoiceRecording,
                  child: const Text('Stop & Send'),
                ),
              ],
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
                    IconButton(
                      tooltip: 'Attach',
                      icon: Icon(
                        Icons.add_circle_outline_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      onPressed: _isInputLocked ? null : _showAttachmentSheet,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        onChanged: _onTextChanged,
                        maxLines: null,
                        enabled: !_isInputLocked,
                        decoration: InputDecoration(
                          hintText: _isInputLocked
                              ? 'Messaging disabled'
                              : widget.isGroupChat
                                  ? 'Message group'
                                  : 'Type a message',
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: _isInputLocked
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
                            : Icon(
                                canSendText
                                    ? Icons.send_rounded
                                    : (_isRecordingVoice
                                        ? Icons.stop_rounded
                                        : Icons.mic_rounded),
                                color: Colors.white,
                              ),
                        onPressed: _isInputLocked
                            ? null
                            : () {
                                if (canSendText) {
                                  _sendMessage();
                                } else {
                                  _toggleVoiceRecording();
                                }
                              },
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
