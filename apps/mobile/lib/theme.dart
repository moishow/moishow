import 'package:flutter/material.dart';

/// Native mapping of design/system/tokens.css. Monetary surfaces use blue.
abstract final class Tokens {
  static const blue = Color(0xFF3B5CFF),
      blueSoft = Color(0xFFEEF2FF),
      coral = Color(0xFFFF6B5C),
      ink = Color(0xFF161A24),
      muted = Color(0xFF6E7689),
      sunken = Color(0xFFF4F6FA),
      border = Color(0xFFDDE2EC),
      white = Color(0xFFFFFFFF);
  static const screen = 20.0, gap = 12.0, radius = 20.0;
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: white,
    fontFamily: 'Pretendard',
    colorScheme: const ColorScheme.light(
      primary: blue,
      onPrimary: white,
      primaryContainer: blueSoft,
      onPrimaryContainer: ink,
      secondary: muted,
      onSecondary: white,
      secondaryContainer: sunken,
      onSecondaryContainer: ink,
      tertiary: Color(0xFF008857),
      onTertiary: white,
      tertiaryContainer: Color(0xFFE5FBF3),
      onTertiaryContainer: Color(0xFF008857),
      surface: white,
      onSurface: ink,
      surfaceContainer: sunken,
      outline: border,
      outlineVariant: Color(0xFFEBEEF4),
      error: blue,
      onError: white,
      errorContainer: blueSoft,
      onErrorContainer: ink,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: white,
      indicatorColor: blueSoft,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected) ? blue : muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected) ? blue : muted,
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: white,
      surfaceTintColor: Colors.transparent,
      constraints: BoxConstraints(maxWidth: 420),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontFeatures: [FontFeature.tabularFigures()],
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontFeatures: [FontFeature.tabularFigures()],
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontFeatures: [FontFeature.tabularFigures()],
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.5,
        color: ink,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      bodySmall: TextStyle(fontSize: 12, color: muted),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: white,
      foregroundColor: ink,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: sunken,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
    ),
    cardTheme: CardThemeData(
      color: white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: gap),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: border),
        borderRadius: BorderRadius.circular(radius),
      ),
    ),
  );
}
