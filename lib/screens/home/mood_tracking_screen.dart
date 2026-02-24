import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/app_page_scaffold.dart';

class MoodTrackingScreen extends ConsumerStatefulWidget {
  const MoodTrackingScreen({super.key});

  @override
  ConsumerState<MoodTrackingScreen> createState() => _MoodTrackingScreenState();
}

class _MoodTrackingScreenState extends ConsumerState<MoodTrackingScreen> {
  Map<String, int> _moodStats = {};

  @override
  void initState() {
    super.initState();
    _loadMoodStats();
  }

  Future<void> _loadMoodStats() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('mood_history')
          .orderBy('timestamp', descending: true)
          .limit(30)
          .get();

      final stats = <String, int>{};
      for (final doc in snapshot.docs) {
        final mood = doc.data()['mood'] as String;
        stats[mood] = (stats[mood] ?? 0) + 1;
      }

      if (mounted) setState(() => _moodStats = stats);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      appBar: AppBar(title: const Text('Mood Tracking')),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Mood Statistics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 14),
                if (_moodStats.isEmpty)
                  const Center(child: Text('No mood data available yet'))
                else
                  ..._buildMoodStats(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent Mood History',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                _buildMoodHistory(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMoodStats() {
    final total = _moodStats.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return const [];

    return _moodStats.entries.map((entry) {
      final percentage = (entry.value / total * 100).round();
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(_getMoodIcon(entry.key),
                color: _getMoodColor(entry.key), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text('${entry.value} times ($percentage%)'),
                ],
              ),
            ),
            SizedBox(
              width: 92,
              child: LinearProgressIndicator(
                value: entry.value / total,
                borderRadius: BorderRadius.circular(12),
                minHeight: 7,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getMoodColor(entry.key),
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildMoodHistory() {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('mood_history')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No mood history yet'));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final mood = data['mood'] as String;
            final timestamp = (data['timestamp'] as Timestamp).toDate();
            return ListTile(
              leading: Icon(_getMoodIcon(mood), color: _getMoodColor(mood)),
              title: Text(mood.toUpperCase()),
              subtitle: Text(
                '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
              ),
            );
          },
        );
      },
    );
  }

  IconData _getMoodIcon(String mood) {
    switch (mood) {
      case 'happy':
        return Icons.sentiment_very_satisfied_rounded;
      case 'sad':
        return Icons.sentiment_dissatisfied_rounded;
      case 'tired':
        return Icons.bedtime_outlined;
      case 'angry':
        return Icons.sentiment_very_dissatisfied_rounded;
      default:
        return Icons.sentiment_neutral_rounded;
    }
  }

  Color _getMoodColor(String mood) {
    switch (mood) {
      case 'happy':
        return Colors.amber.shade700;
      case 'sad':
        return Colors.blue.shade600;
      case 'tired':
        return Colors.grey.shade600;
      case 'angry':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade500;
    }
  }
}
