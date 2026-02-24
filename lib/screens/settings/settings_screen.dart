import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../app_routes.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              settingsNotifier.resetToDefaults();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to defaults')),
              );
            },
            tooltip: 'Reset to defaults',
          ),
        ],
      ),
      body: ListView(
        children: [
          // Profile Section
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Profile"),
            subtitle: const Text("Edit your profile information"),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.editProfile);
            },
          ),
          const Divider(),

          // Privacy Section
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text("Privacy"),
            subtitle: const Text("Manage your privacy settings"),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.privacySettings);
            },
          ),
          const Divider(),

          // Theme Section
          SwitchListTile(
            secondary: const Icon(Icons.color_lens),
            title: const Text("Dark Mode"),
            subtitle: Text(settings.isDarkMode ? "Enabled" : "Disabled"),
            value: settings.isDarkMode,
            onChanged: (value) {
              settingsNotifier.setDarkMode(value);
              // Add call to rebuild app theme or notify listeners if needed
              // For example, you might want to use a callback or state management to apply theme changes globally
            },
          ),
          const Divider(),

          // Notifications Section
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text("Notifications"),
            subtitle:
                Text(settings.notificationsEnabled ? "Enabled" : "Disabled"),
            value: settings.notificationsEnabled,
            onChanged: (value) {
              settingsNotifier.setNotificationsEnabled(value);
            },
          ),
          const Divider(),

          // Sound Section
          SwitchListTile(
            secondary: const Icon(Icons.volume_up),
            title: const Text("Sound"),
            subtitle: Text(settings.soundEnabled ? "Enabled" : "Disabled"),
            value: settings.soundEnabled,
            onChanged: (value) {
              settingsNotifier.setSoundEnabled(value);
            },
          ),
          const Divider(),

          // Vibration Section
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: const Text("Vibration"),
            subtitle: Text(settings.vibrationEnabled ? "Enabled" : "Disabled"),
            value: settings.vibrationEnabled,
            onChanged: (value) {
              settingsNotifier.setVibrationEnabled(value);
            },
          ),
          const Divider(),

          // Language Section
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text("Language"),
            subtitle: Text("Current: ${settings.language.toUpperCase()}"),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              _showLanguageDialog(context, ref);
            },
          ),
          const Divider(),

          // About Section
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text("About"),
            subtitle: const Text("App version and information"),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: "Chatly",
                applicationVersion: "1.0.0",
                applicationLegalese: "© 2025 Chatly",
              );
            },
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final languages = ['en', 'es', 'fr', 'de'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.map((lang) {
            return ListTile(
              title: Text(lang.toUpperCase()),
              onTap: () {
                settingsNotifier.setLanguage(lang);
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
