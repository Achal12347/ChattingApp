import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_theme.dart';

// Settings model
class Settings {
  final String themeMode; // system | light | dark
  final String themePreset; // one of appThemePresets ids
  final bool notificationsEnabled;
  final String language;
  final bool soundEnabled;
  final bool vibrationEnabled;

  const Settings({
    this.themeMode = 'system',
    this.themePreset = defaultThemePresetId,
    this.notificationsEnabled = true,
    this.language = 'en',
    this.soundEnabled = true,
    this.vibrationEnabled = true,
  });

  bool get isDarkMode => themeMode == 'dark';

  Settings copyWith({
    String? themeMode,
    String? themePreset,
    bool? notificationsEnabled,
    String? language,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) {
    return Settings(
      themeMode: themeMode ?? this.themeMode,
      themePreset: themePreset ?? this.themePreset,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      language: language ?? this.language,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }
}

// Settings notifier
class SettingsNotifier extends StateNotifier<Settings> {
  SettingsNotifier() : super(const Settings()) {
    _loadSettings();
  }

  static const _themeModeKey = 'settings_theme_mode';
  static const _themePresetKey = 'settings_theme_preset';
  static const _notificationsKey = 'settings_notifications_enabled';
  static const _languageKey = 'settings_language';
  static const _soundKey = 'settings_sound_enabled';
  static const _vibrationKey = 'settings_vibration_enabled';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      themeMode: prefs.getString(_themeModeKey) ?? 'system',
      themePreset: prefs.getString(_themePresetKey) ?? defaultThemePresetId,
      notificationsEnabled: prefs.getBool(_notificationsKey) ?? true,
      language: prefs.getString(_languageKey) ?? 'en',
      soundEnabled: prefs.getBool(_soundKey) ?? true,
      vibrationEnabled: prefs.getBool(_vibrationKey) ?? true,
    );
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, state.themeMode);
    await prefs.setString(_themePresetKey, state.themePreset);
    await prefs.setBool(_notificationsKey, state.notificationsEnabled);
    await prefs.setString(_languageKey, state.language);
    await prefs.setBool(_soundKey, state.soundEnabled);
    await prefs.setBool(_vibrationKey, state.vibrationEnabled);
  }

  void toggleDarkMode() {
    final mode = state.isDarkMode ? 'light' : 'dark';
    state = state.copyWith(themeMode: mode);
    _persistState();
  }

  void setDarkMode(bool isDark) {
    state = state.copyWith(themeMode: isDark ? 'dark' : 'light');
    _persistState();
  }

  void setThemeMode(String mode) {
    state = state.copyWith(themeMode: mode);
    _persistState();
  }

  void setThemePreset(String preset) {
    state = state.copyWith(themePreset: preset);
    _persistState();
  }

  void toggleNotifications() {
    state = state.copyWith(notificationsEnabled: !state.notificationsEnabled);
    _persistState();
  }

  void setNotificationsEnabled(bool enabled) {
    state = state.copyWith(notificationsEnabled: enabled);
    _persistState();
  }

  void setLanguage(String language) {
    state = state.copyWith(language: language);
    _persistState();
  }

  void toggleSound() {
    state = state.copyWith(soundEnabled: !state.soundEnabled);
    _persistState();
  }

  void setSoundEnabled(bool enabled) {
    state = state.copyWith(soundEnabled: enabled);
    _persistState();
  }

  void toggleVibration() {
    state = state.copyWith(vibrationEnabled: !state.vibrationEnabled);
    _persistState();
  }

  void setVibrationEnabled(bool enabled) {
    state = state.copyWith(vibrationEnabled: enabled);
    _persistState();
  }

  void resetToDefaults() {
    state = const Settings();
    _persistState();
  }
}

// Provider
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, Settings>((ref) {
  return SettingsNotifier();
});
