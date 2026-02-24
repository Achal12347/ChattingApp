import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class MoodIndicator extends ConsumerWidget {
  final String userId;
  final double size;

  const MoodIndicator({
    super.key,
    required this.userId,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authStateProvider).value;

    // Only show mood indicator for other users, not current user
    if (currentUser?.uid == userId) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<String?>(
      future: _getUserMood(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData ||
            snapshot.data == null ||
            snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final mood = snapshot.data!;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              mood,
              style: TextStyle(fontSize: size * 0.6),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _getUserMood(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        return userDoc.data()?['mood'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
