import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String id;
  final String name;
  final String? description;
  final String adminId;
  final List<String> participants;
  final List<String> admins;
  final DateTime createdAt;
  final String? avatarUrl;
  final bool isArchived;
  final Map<String, bool> mutedUsers; // userId: isMuted
  final String lastMessage;
  final DateTime lastMessageAt;

  GroupModel({
    required this.id,
    required this.name,
    this.description,
    required this.adminId,
    required this.participants,
    required this.admins,
    required this.createdAt,
    this.avatarUrl,
    this.isArchived = false,
    this.mutedUsers = const {},
    required this.lastMessage,
    required this.lastMessageAt,
  });

  factory GroupModel.fromMap(Map<String, dynamic> map) {
    return GroupModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      adminId: map['adminId'] ?? '',
      participants: List<String>.from(map['participants'] ?? []),
      admins: List<String>.from(map['admins'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      avatarUrl: map['avatarUrl'],
      isArchived: map['isArchived'] ?? false,
      mutedUsers: Map<String, bool>.from(map['mutedUsers'] ?? {}),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageAt:
          (map['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'adminId': adminId,
      'participants': participants,
      'admins': admins,
      'createdAt': Timestamp.fromDate(createdAt),
      'avatarUrl': avatarUrl,
      'isArchived': isArchived,
      'mutedUsers': mutedUsers,
      'lastMessage': lastMessage,
      'lastMessageAt': Timestamp.fromDate(lastMessageAt),
    };
  }

  GroupModel copyWith({
    String? id,
    String? name,
    String? description,
    String? adminId,
    List<String>? participants,
    List<String>? admins,
    DateTime? createdAt,
    String? avatarUrl,
    bool? isArchived,
    Map<String, bool>? mutedUsers,
    String? lastMessage,
    DateTime? lastMessageAt,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      adminId: adminId ?? this.adminId,
      participants: participants ?? this.participants,
      admins: admins ?? this.admins,
      createdAt: createdAt ?? this.createdAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isArchived: isArchived ?? this.isArchived,
      mutedUsers: mutedUsers ?? this.mutedUsers,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }
}
