import 'package:flutter_riverpod/flutter_riverpod.dart';

// Settings model
class Settings {
  final bool isDarkMode;
  final bool notificationsEnabled;
  final String language;
  final bool soundEnabled;
  final bool vibrationEnabled;

  const Settings({
    this.isDarkMode = false,
    this.notificationsEnabled = true,
    this.language = 'en',
    this.soundEnabled = true,
    this.vibrationEnabled = true,
  });

  Settings copyWith({
    bool? isDarkMode,
    bool? notificationsEnabled,
    String? language,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) {
    return Settings(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      language: language ?? this.language,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }
}

// Settings notifier
class SettingsNotifier extends StateNotifier<Settings> {
  SettingsNotifier() : super(const Settings());

  void toggleDarkMode() {
    state = state.copyWith(isDarkMode: !state.isDarkMode);
  }

  void setDarkMode(bool isDark) {
    state = state.copyWith(isDarkMode: isDark);
  }

  void toggleNotifications() {
    state = state.copyWith(notificationsEnabled: !state.notificationsEnabled);
  }

  void setNotificationsEnabled(bool enabled) {
    state = state.copyWith(notificationsEnabled: enabled);
  }

  void setLanguage(String language) {
    state = state.copyWith(language: language);
  }

  void toggleSound() {
    state = state.copyWith(soundEnabled: !state.soundEnabled);
  }

  void setSoundEnabled(bool enabled) {
    state = state.copyWith(soundEnabled: enabled);
  }

  void toggleVibration() {
    state = state.copyWith(vibrationEnabled: !state.vibrationEnabled);
  }

  void setVibrationEnabled(bool enabled) {
    state = state.copyWith(vibrationEnabled: enabled);
  }

  void resetToDefaults() {
    state = const Settings();
  }
}

// Provider
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, Settings>((ref) {
  return SettingsNotifier();
});
