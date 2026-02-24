import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MoodSelector extends StatelessWidget {
  const MoodSelector({super.key});

  static const Map<String, String> moods = {
    '😊': 'Happy',
    '😔': 'Sad',
    '😴': 'Tired',
    '😡': 'Angry',
    '🤒': 'Sick',
    '⚪': 'Neutral',
  };

  Future<void> _updateMood(String mood) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'mood': mood,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating mood: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Select Your Mood',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: moods.length,
            itemBuilder: (context, index) {
              final mood = moods.keys.elementAt(index);
              final label = moods[mood]!;
              return GestureDetector(
                onTap: () {
                  _updateMood(mood);
                  Navigator.of(context).pop();
                },
                child: Column(
                  children: [
                    Text(
                      mood,
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
