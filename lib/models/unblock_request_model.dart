
import 'package:cloud_firestore/cloud_firestore.dart';

class UnblockRequestModel {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String? message;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime createdAt;

  UnblockRequestModel({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    this.message,
    required this.status,
    required this.createdAt,
  });

  factory UnblockRequestModel.fromMap(Map<String, dynamic> map) {
    return UnblockRequestModel(
      id: map['id'] ?? '',
      fromUserId: map['fromUserId'] ?? '',
      toUserId: map['toUserId'] ?? '',
      message: map['message'],
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'message': message,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
