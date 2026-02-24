import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            tooltip: 'Reset to defaults',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: () {
              settingsNotifier.resetToDefaults();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to defaults')),
              );
            },
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [scheme.surface, Theme.of(context).scaffoldBackgroundColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SettingsCard(
              title: 'Appearance',
              subtitle: 'Theme mode and color style',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Theme mode'),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'system',
                        icon: Icon(Icons.smartphone_rounded),
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: 'light',
                        icon: Icon(Icons.light_mode_rounded),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: 'dark',
                        icon: Icon(Icons.dark_mode_rounded),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (value) {
                      settingsNotifier.setThemeMode(value.first);
                    },
                  ),
                  const SizedBox(height: 18),
                  const Text('Color theme'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: appThemePresets.map((preset) {
                      final selected = preset.id == settings.themePreset;
                      return ChoiceChip(
                        selected: selected,
                        label: Text(preset.label),
                        avatar: CircleAvatar(
                          radius: 7,
                          backgroundColor: preset.seedColor,
                        ),
                        onSelected: (_) {
                          settingsNotifier.setThemePreset(preset.id);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              title: 'Account',
              subtitle: 'Profile and privacy',
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline_rounded),
                    title: const Text('Profile'),
                    subtitle: const Text('Edit your profile'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.editProfile);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_outline_rounded),
                    title: const Text('Privacy'),
                    subtitle:
                        const Text('Last seen, about and photo visibility'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.privacySettings);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              title: 'Notifications',
              subtitle: 'Control alerts and feedback',
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.notifications_active_outlined),
                    title: const Text('Notifications'),
                    subtitle: Text(
                      settings.notificationsEnabled ? 'Enabled' : 'Disabled',
                    ),
                    value: settings.notificationsEnabled,
                    onChanged: settingsNotifier.setNotificationsEnabled,
                  ),
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.volume_up_outlined),
                    title: const Text('Sound'),
                    subtitle:
                        Text(settings.soundEnabled ? 'Enabled' : 'Disabled'),
                    value: settings.soundEnabled,
                    onChanged: settingsNotifier.setSoundEnabled,
                  ),
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.vibration_rounded),
                    title: const Text('Vibration'),
                    subtitle: Text(
                        settings.vibrationEnabled ? 'Enabled' : 'Disabled'),
                    value: settings.vibrationEnabled,
                    onChanged: settingsNotifier.setVibrationEnabled,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              title: 'Regional',
              subtitle: 'Language and app info',
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.language_rounded),
                    title: const Text('Language'),
                    subtitle:
                        Text('Current: ${settings.language.toUpperCase()}'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showLanguageDialog(context, ref),
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('About'),
                    subtitle: const Text('Version and legal information'),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Chatly',
                        applicationVersion: '1.0.0',
                        applicationLegalese: '© 2026 Chatly',
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    final settingsNotifier = ref.read(settingsProvider.notifier);
    const languages = ['en', 'es', 'fr', 'de', 'hi'];

    showDialog<void>(
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
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
