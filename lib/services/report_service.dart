import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final reportServiceProvider = Provider<ReportService>((ref) => ReportService());

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> reportMessage({
    required String reporterId,
    required String chatId,
    required String messageId,
    required String reason,
    bool isGroupChat = false,
  }) async {
    await _firestore.collection('reports').add({
      'type': 'message',
      'reporterId': reporterId,
      'chatId': chatId,
      'messageId': messageId,
      'reason': reason,
      'isGroupChat': isGroupChat,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'open',
    });
  }

  Future<void> reportUser({
    required String reporterId,
    required String reportedUserId,
    required String reason,
  }) async {
    await _firestore.collection('reports').add({
      'type': 'user',
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'open',
    });
  }
}
