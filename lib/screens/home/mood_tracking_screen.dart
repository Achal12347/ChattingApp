import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../services/mood_service.dart';

class MoodTrackingScreen extends ConsumerStatefulWidget {
  const MoodTrackingScreen({super.key});

  @override
  ConsumerState<MoodTrackingScreen> createState() => _MoodTrackingScreenState();
}

class _MoodTrackingScreenState extends ConsumerState<MoodTrackingScreen> {
  final MoodService _moodService = MoodService();
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

      setState(() {
        _moodStats = stats;
      });
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood Tracking'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Mood Statistics',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            if (_moodStats.isEmpty)
              const Center(
                child: Text('No mood data available yet'),
              )
            else
              ..._buildMoodStats(),
            const SizedBox(height: 30),
            const Text(
              'Recent Mood History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _buildMoodHistory(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMoodStats() {
    final total = _moodStats.values.reduce((a, b) => a + b);
    return _moodStats.entries.map((entry) {
      final percentage = (entry.value / total * 100).round();
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                _getMoodIcon(entry.key),
                color: _getMoodColor(entry.key),
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text('${entry.value} times ($percentage%)'),
                  ],
                ),
              ),
              SizedBox(
                width: 100,
                child: LinearProgressIndicator(
                  value: entry.value / total,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getMoodColor(entry.key),
                  ),
                ),
              ),
            ],
          ),
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
              leading: Icon(
                _getMoodIcon(mood),
                color: _getMoodColor(mood),
              ),
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
        return Icons.sentiment_very_satisfied;
      case 'sad':
        return Icons.sentiment_dissatisfied;
      case 'tired':
        return Icons.sentiment_neutral;
      case 'angry':
        return Icons.sentiment_very_dissatisfied;
      default:
        return Icons.sentiment_neutral;
    }
  }

  Color _getMoodColor(String mood) {
    switch (mood) {
      case 'happy':
        return Colors.yellow.shade600;
      case 'sad':
        return Colors.blue.shade600;
      case 'tired':
        return Colors.grey.shade600;
      case 'angry':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade400;
    }
  }
}
