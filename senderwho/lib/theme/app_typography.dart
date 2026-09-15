import 'package:flutter/material.dart';

abstract final class AppTypography {
  // A single neutral system-sans stack is applied by ThemeData. Individual
  // widgets consume this scale instead of introducing their own font families.
  static const String fontFamily = 'sans-serif';
  static const List<String> fontFamilyFallback = [
    'SF Pro Text',
    'Roboto',
    'Arial',
  ];

  static TextTheme textTheme({required Color text, required Color muted}) {
    return TextTheme(
      headlineLarge: TextStyle(
        fontSize: 30,
        height: 1.15,
        fontWeight: FontWeight.w800,
        color: text,
        letterSpacing: -0.75,
      ),
      headlineMedium: TextStyle(
        fontSize: 25,
        height: 1.2,
        fontWeight: FontWeight.w800,
        color: text,
        letterSpacing: -0.6,
      ),
      headlineSmall: TextStyle(
        fontSize: 21,
        height: 1.25,
        fontWeight: FontWeight.w800,
        color: text,
        letterSpacing: -0.45,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        height: 1.25,
        fontWeight: FontWeight.w800,
        color: text,
        letterSpacing: -0.35,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: text,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: text,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: text,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: text,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: muted,
      ),
      labelSmall: TextStyle(
        fontSize: 11.5,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: muted,
      ),
    );
  }
}
