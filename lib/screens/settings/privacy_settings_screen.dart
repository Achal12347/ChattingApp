import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userProvider = StreamProvider.autoDispose<DocumentSnapshot>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return Stream.empty();
  }
  return FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots();
});

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Settings'),
      ),
      body: userAsync.when(
        data: (userDoc) {
          if (!userDoc.exists) {
            return const Center(child: Text("User not found"));
          }
          final userData = userDoc.data() as Map<String, dynamic>;
          final privacySettings = Map<String, String>.from(userData['privacySettings'] ?? {});

          return ListView(
            children: [
              ListTile(
                title: const Text('Last Seen'),
                subtitle: Text(privacySettings['lastSeen'] ?? 'Everyone'),
                onTap: () => _showPrivacyOptionsDialog(context, 'lastSeen', privacySettings['lastSeen'] ?? 'everyone'),
              ),
              ListTile(
                title: const Text('Profile Photo'),
                subtitle: Text(privacySettings['profilePhoto'] ?? 'Everyone'),
                onTap: () => _showPrivacyOptionsDialog(context, 'profilePhoto', privacySettings['profilePhoto'] ?? 'everyone'),
              ),
              ListTile(
                title: const Text('About'),
                subtitle: Text(privacySettings['about'] ?? 'Everyone'),
                onTap: () => _showPrivacyOptionsDialog(context, 'about', privacySettings['about'] ?? 'everyone'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text("Error: $error")),
      ),
    );
  }

  Future<void> _showPrivacyOptionsDialog(BuildContext context, String field, String currentValue) async {
    final newValue = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Who can see my $field'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Everyone'),
              value: 'everyone',
              groupValue: currentValue,
              onChanged: (value) => Navigator.of(context).pop(value),
            ),
            RadioListTile<String>(
              title: const Text('My Contacts'),
              value: 'myContacts',
              groupValue: currentValue,
              onChanged: (value) => Navigator.of(context).pop(value),
            ),
            RadioListTile<String>(
              title: const Text('Nobody'),
              value: 'nobody',
              groupValue: currentValue,
              onChanged: (value) => Navigator.of(context).pop(value),
            ),
          ],
        ),
      ),
    );

    if (newValue != null && newValue != currentValue) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'privacySettings.$field': newValue,
        });
      }
    }
  }
}
