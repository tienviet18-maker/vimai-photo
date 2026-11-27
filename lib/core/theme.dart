import 'package:flutter/material.dart';

/// ViMai Photo brand colours. Deep teal reads as "official document"
/// without copying the green used by most ID-photo apps.
abstract final class AppColors {
  static const primary = Color(0xFF0B5C6B);
  static const primaryDark = Color(0xFF08434E);
  static const primarySoft = Color(0xFFE3F0F1);
  static const accent = Color(0xFFF2A541);
  static const onAccent = Color(0xFF2E1D00);
  static const ok = Color(0xFF2E9E5B);
  static const okText = Color(0xFF165C34);
  static const okSoft = Color(0xFFE8F6EE);
  static const okLine = Color(0xFFB9DEC8);
  static const warnSoft = Color(0xFFFFF4E3);
  static const warnText = Color(0xFF6A4100);
  static const ground = Color(0xFFF4F7F7);
  static const well = Color(0xFFE6ECED);
  static const line = Color(0xFFDCE6E7);
  static const ink = Color(0xFF0F2A30);
  static const muted = Color(0xFF4A6268);
  static const onPrimaryMuted = Color(0xFFCDE6E9);
}

/// The app is light only for now: the designs and photo previews are
/// tuned for a light ground (an ID photo is judged on white).
ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    secondary: AppColors.accent,
    surface: Colors.white,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.muted,
    outline: const Color(0xFFCFDCDD),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.ground,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.ground,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
      color: Colors.white,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: Color(0xFFCFDCDD)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
