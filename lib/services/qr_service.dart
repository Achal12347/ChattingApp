// ignore_for_file: unused_import

import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QRService {
  /// ✅ Generate QR code data for user
  String generateUserQR(String userId, String username) {
    final qrData = {
      'type': 'user',
      'userId': userId,
      'username': username,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(qrData);
  }

  /// ✅ Parse QR code data
  Map<String, dynamic>? parseQRData(String qrData) {
    try {
      return jsonDecode(qrData) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// ✅ Validate QR code data
  bool isValidUserQR(Map<String, dynamic> qrData) {
    // Check if QR is not older than 5 minutes
    final timestamp = qrData['timestamp'] as int?;
    if (timestamp == null) return false;

    final qrTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(qrTime).inMinutes;

    return difference <= 5 && qrData['type'] == 'user';
  }

  /// ✅ Connect with user from QR code
  Future<String?> connectWithUserFromQR(String qrData) async {
    final parsedData = parseQRData(qrData);
    if (parsedData == null || !isValidUserQR(parsedData)) {
      return null;
    }

    final targetUserId = parsedData['userId'] as String;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || currentUser.uid == targetUserId) {
      return null;
    }

    // Generate chat ID
    final participants = [currentUser.uid, targetUserId]..sort();
    return participants.join('_');
  }
}
