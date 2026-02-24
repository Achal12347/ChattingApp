import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/app_page_scaffold.dart';

final userProvider = StreamProvider.autoDispose<DocumentSnapshot>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.empty();
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots();
});

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);

    return AppPageScaffold(
      appBar: AppBar(title: const Text('Privacy Settings')),
      child: userAsync.when(
        data: (userDoc) {
          if (!userDoc.exists) {
            return const Center(child: Text('User not found'));
          }

          final userData = userDoc.data() as Map<String, dynamic>;
          final privacySettings =
              Map<String, String>.from(userData['privacySettings'] ?? {});

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppSectionCard(
                child: Column(
                  children: [
                    _PrivacyTile(
                      title: 'Last Seen',
                      subtitle:
                          _display(privacySettings['lastSeen'] ?? 'everyone'),
                      icon: Icons.visibility_rounded,
                      onTap: () => _showPrivacyOptionsDialog(
                        context,
                        field: 'lastSeen',
                        label: 'last seen',
                        currentValue: privacySettings['lastSeen'] ?? 'everyone',
                      ),
                    ),
                    _PrivacyTile(
                      title: 'Profile Photo',
                      subtitle: _display(
                          privacySettings['profilePhoto'] ?? 'everyone'),
                      icon: Icons.photo_camera_back_rounded,
                      onTap: () => _showPrivacyOptionsDialog(
                        context,
                        field: 'profilePhoto',
                        label: 'profile photo',
                        currentValue:
                            privacySettings['profilePhoto'] ?? 'everyone',
                      ),
                    ),
                    _PrivacyTile(
                      title: 'About',
                      subtitle:
                          _display(privacySettings['about'] ?? 'everyone'),
                      icon: Icons.info_outline_rounded,
                      onTap: () => _showPrivacyOptionsDialog(
                        context,
                        field: 'about',
                        label: 'about',
                        currentValue: privacySettings['about'] ?? 'everyone',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  String _display(String value) {
    switch (value) {
      case 'myContacts':
        return 'My Contacts';
      case 'nobody':
        return 'Nobody';
      default:
        return 'Everyone';
    }
  }

  Future<void> _showPrivacyOptionsDialog(
    BuildContext context, {
    required String field,
    required String label,
    required String currentValue,
  }) async {
    final newValue = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Who can see your $label?'),
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

    if (newValue == null || newValue == currentValue) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'privacySettings.$field': newValue,
    });
  }
}

class _PrivacyTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _PrivacyTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
