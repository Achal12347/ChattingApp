import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;
  final bool isReadByReceiver;
  final bool isDelivered;
  final String status; // 'sent', 'delivered', 'read'
  final DateTime? deliveredAt;
  final String? mediaUrl;
  final String? mediaType; // 'image', 'voice', etc.
  final List<String> reactions; // List of emoji reactions
  final bool isDeleted;
  final bool deletedForEveryone;
  final String? replyToMessageId;
  final bool isUrgent;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.createdAt,
    this.isRead = false,
    this.readAt,
    this.isReadByReceiver = false,
    this.isDelivered = false,
    this.deliveredAt,
    this.status = 'sent',
    this.mediaUrl,
    this.mediaType,
    this.reactions = const [],
    this.isDeleted = false,
    this.deletedForEveryone = false,
    this.replyToMessageId,
    this.isUrgent = false,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    final rawReactions = map['reactions'];
    final reactions = rawReactions is List
        ? rawReactions.map((e) => e.toString()).toList()
        : const <String>[];

    return MessageModel(
      id: map['id'] ?? '',
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      content: map['content'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
      readAt: (map['readAt'] as Timestamp?)?.toDate(),
      isReadByReceiver: map['isReadByReceiver'] ?? false,
      isDelivered: map['isDelivered'] ?? false,
      status: map['status'] ?? 'sent',
      mediaUrl: map['mediaUrl'],
      mediaType: map['mediaType'],
      reactions: reactions,
      isDeleted: map['isDeleted'] ?? false,
      deletedForEveryone: map['deletedForEveryone'] ?? false,
      replyToMessageId: map['replyToMessageId'],
      isUrgent: map['isUrgent'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'isReadByReceiver': isReadByReceiver,
      'isDelivered': isDelivered,
      'status': status,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'reactions': reactions,
      'isDeleted': isDeleted,
      'deletedForEveryone': deletedForEveryone,
      'replyToMessageId': replyToMessageId,
      'isUrgent': isUrgent,
    };
  }

  factory MessageModel.fromDrift(dynamic msg) {
    final reactions = () {
      final raw = msg.reactionsJson;
      if (raw == null || raw.toString().isEmpty) return const <String>[];
      try {
        final decoded = jsonDecode(raw.toString()) as List<dynamic>;
        return decoded.map((e) => e.toString()).toList();
      } catch (_) {
        return const <String>[];
      }
    }();

    return MessageModel(
      id: msg.id,
      chatId: msg.chatId,
      senderId: msg.senderId,
      receiverId: msg.receiverId,
      content: msg.content,
      createdAt: msg.createdAt,
      isRead: false,
      readAt: null,
      isReadByReceiver: false,
      isDelivered: false,
      status: msg.status,
      mediaUrl: msg.mediaUrl,
      mediaType: msg.mediaType,
      reactions: reactions,
      isDeleted: msg.isDeleted,
      deletedForEveryone: msg.deletedForEveryone,
      replyToMessageId: msg.replyToMessageId,
      isUrgent: msg.isUrgent,
    );
  }
}
