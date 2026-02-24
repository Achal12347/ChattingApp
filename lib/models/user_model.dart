import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String username;
  final String fullName;
  final String email;
  final DateTime createdAt;
  final String? fcmToken;
  final String? avatarUrl;
  final String about;
  final String mood; // 'happy', 'sad', 'tired', etc.
  final List<String> blockedUsers;
  final Map<String, String> relationships; // userId: 'friend', 'family', etc.
  final Map<String, String> blockReasons; // blockedUserId: reason
  final String status;
  final DateTime lastSeen;
  final Map<String, String> privacySettings;

  UserModel({
    required this.uid,
    required this.username,
    required this.fullName,
    required this.email,
    required this.createdAt,
    this.fcmToken,
    this.avatarUrl,
    this.about = "Hey there! I am using Chatly.",
    this.mood = "🙂",
    this.blockedUsers = const [],
    this.relationships = const {},
    this.blockReasons = const {},
    this.status = "offline",
    required this.lastSeen,
    this.privacySettings = const {
      'lastSeen': 'everyone',
      'profilePhoto': 'everyone',
      'about': 'everyone',
    },
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fcmToken: map['fcmToken'],
      avatarUrl: map['avatarUrl'],
      about: map['about'] ?? "Hey there! I am using Chatly.",
      mood: map['mood'] ?? "🙂",
      blockedUsers: List<String>.from(map['blockedUsers'] ?? []),
      relationships: Map<String, String>.from(map['relationships'] ?? {}),
      blockReasons: Map<String, String>.from(map['blockReasons'] ?? {}),
      status: map['status'] ?? "offline",
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      privacySettings: Map<String, String>.from(map['privacySettings'] ??
          {
            'lastSeen': 'everyone',
            'profilePhoto': 'everyone',
            'about': 'everyone',
          }),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'fullName': fullName,
      'email': email,
      'createdAt': Timestamp.fromDate(createdAt),
      'fcmToken': fcmToken,
      'avatarUrl': avatarUrl,
      'about': about,
      'mood': mood,
      'blockedUsers': blockedUsers,
      'relationships': relationships,
      'blockReasons': blockReasons,
      'status': status,
      'lastSeen': Timestamp.fromDate(lastSeen),
      'privacySettings': privacySettings,
    };
  }
}
