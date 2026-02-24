import 'package:cloud_firestore/cloud_firestore.dart';
// ignore: unused_import
import 'package:firebase_auth/firebase_auth.dart';

class MoodService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ Analyze message content for mood
  String analyzeMood(String message) {
    final lowerMessage = message.toLowerCase();

    // Keywords for different moods
    if (lowerMessage.contains('happy') ||
        lowerMessage.contains('great') ||
        lowerMessage.contains('awesome')) {
      return 'happy';
    } else if (lowerMessage.contains('sad') ||
        lowerMessage.contains('unhappy') ||
        lowerMessage.contains('depressed')) {
      return 'sad';
    } else if (lowerMessage.contains('tired') ||
        lowerMessage.contains('exhausted') ||
        lowerMessage.contains('sleepy')) {
      return 'tired';
    } else if (lowerMessage.contains('angry') ||
        lowerMessage.contains('mad') ||
        lowerMessage.contains('frustrated')) {
      return 'angry';
    } else {
      return 'neutral';
    }
  }

  /// ✅ Update user mood based on message analysis
  Future<void> updateUserMood(String userId, String mood) async {
    await _firestore.collection('users').doc(userId).update({
      'mood': mood,
      'lastMoodUpdate': FieldValue.serverTimestamp(),
    });
  }

  /// ✅ Get mood-based notification message
  String getMoodNotification(String mood) {
    switch (mood) {
      case 'sad':
        return "We noticed you might be feeling down. Take a break and talk to a friend! 😊";
      case 'tired':
        return "You seem tired. Maybe get some rest or have a coffee? ☕";
      case 'angry':
        return "Feeling frustrated? Take a deep breath and relax. 🧘‍♂️";
      default:
        return "";
    }
  }

  /// ✅ Check if urgent notification should be sent
  bool shouldSendUrgentNotification(String mood) {
    return mood == 'sad' || mood == 'tired' || mood == 'angry';
  }
}
