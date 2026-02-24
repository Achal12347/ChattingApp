import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants.dart';

const String defaultThemePresetId = 'ocean';

class AppThemePreset {
  final String id;
  final String label;
  final Color seedColor;

  const AppThemePreset({
    required this.id,
    required this.label,
    required this.seedColor,
  });
}

const List<AppThemePreset> appThemePresets = [
  AppThemePreset(
    id: 'ocean',
    label: 'Ocean Blue',
    seedColor: Color(primaryColorValue),
  ),
  AppThemePreset(
    id: 'emerald',
    label: 'Emerald',
    seedColor: Color(0xFF0F9D84),
  ),
  AppThemePreset(
    id: 'sunset',
    label: 'Sunset Orange',
    seedColor: Color(0xFFE16A3D),
  ),
  AppThemePreset(
    id: 'orchid',
    label: 'Orchid Pink',
    seedColor: Color(0xFFC03A8C),
  ),
  AppThemePreset(
    id: 'forest',
    label: 'Forest Green',
    seedColor: Color(0xFF2E7D32),
  ),
  AppThemePreset(
    id: 'amber',
    label: 'Amber Gold',
    seedColor: Color(0xFFEF6C00),
  ),
  AppThemePreset(
    id: 'slate',
    label: 'Slate Gray',
    seedColor: Color(0xFF455A64),
  ),
];

AppThemePreset resolveThemePreset(String presetId) {
  return appThemePresets.firstWhere(
    (preset) => preset.id == presetId,
    orElse: () => appThemePresets.first,
  );
}

ThemeData _buildTheme({
  required Brightness brightness,
  required AppThemePreset preset,
}) {
  final seed = preset.seedColor;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
  );
  final baseTextTheme = ThemeData(brightness: brightness).textTheme;
  final textTheme = GoogleFonts.manropeTextTheme(baseTextTheme).copyWith(
    headlineLarge: GoogleFonts.manrope(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      color: colorScheme.onSurface,
    ),
    headlineMedium: GoogleFonts.manrope(
      fontSize: 29,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      color: colorScheme.onSurface,
    ),
    titleLarge: GoogleFonts.manrope(
      fontSize: 23,
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
    ),
    titleMedium: GoogleFonts.manrope(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
    ),
    bodyLarge: GoogleFonts.nunitoSans(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    ),
    bodyMedium: GoogleFonts.nunitoSans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    ),
    labelLarge: GoogleFonts.nunitoSans(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    fontFamily: GoogleFonts.nunitoSans().fontFamily,
    textTheme: textTheme,
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? const Color(0xFF0F141B)
        : const Color(backgroundColorValue),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.03),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      iconColor: colorScheme.primary,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: brightness == Brightness.dark
          ? const Color(0xFF232A35)
          : const Color(0xFF1F2937),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

ThemeData getLightTheme(String presetId) {
  return _buildTheme(
    brightness: Brightness.light,
    preset: resolveThemePreset(presetId),
  );
}

ThemeData getDarkTheme(String presetId) {
  return _buildTheme(
    brightness: Brightness.dark,
    preset: resolveThemePreset(presetId),
  );
}

ThemeData lightTheme = getLightTheme(defaultThemePresetId);
ThemeData darkTheme = getDarkTheme(defaultThemePresetId);

ThemeData getThemeData(bool isDark) {
  return isDark ? darkTheme : lightTheme;
}

ThemeMode resolveThemeMode(String mode) {
  switch (mode) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}
