import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    return _base(
      brightness: Brightness.light,
      scaffold: AppColors.background,
      surface: AppColors.card,
      text: AppColors.text,
      muted: AppColors.muted,
      border: AppColors.border,
    );
  }

  static ThemeData dark() {
    return _base(
      brightness: Brightness.dark,
      scaffold: AppColors.darkBackground,
      surface: AppColors.darkCard,
      text: AppColors.darkText,
      muted: AppColors.darkMuted,
      border: AppColors.darkBorder,
    );
  }

  static ThemeData _base({
    required Brightness brightness,
    required Color scaffold,
    required Color surface,
    required Color text,
    required Color muted,
    required Color border,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: brightness,
          surface: surface,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.indigo,
          onSecondary: Colors.white,
          tertiary: AppColors.cyan,
          onTertiary: AppColors.brandNavy,
          error: AppColors.danger,
          onError: Colors.white,
          surface: surface,
          onSurface: text,
          outline: border,
          outlineVariant: border.withValues(alpha: 0.72),
          surfaceContainerLowest: isDark
              ? AppColors.darkBackground
              : AppColors.card,
          surfaceContainerLow: surface,
          surfaceContainer: isDark
              ? AppColors.darkElevatedCard
              : AppColors.elevatedCard,
          surfaceContainerHigh: isDark
              ? AppColors.darkSubtle
              : AppColors.subtle,
          surfaceContainerHighest: isDark
              ? AppColors.darkSubtle
              : AppColors.subtle,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      cardColor: surface,
      disabledColor: muted.withValues(alpha: 0.5),
      colorScheme: colorScheme,
      dividerColor: border,
      splashColor: AppColors.primary.withValues(alpha: 0.08),
      highlightColor: AppColors.primary.withValues(alpha: 0.04),
      focusColor: AppColors.cyan.withValues(alpha: 0.16),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FixedShellPageTransitionsBuilder(),
          TargetPlatform.iOS: _FixedShellPageTransitionsBuilder(),
          TargetPlatform.macOS: _FixedShellPageTransitionsBuilder(),
          TargetPlatform.windows: _FixedShellPageTransitionsBuilder(),
          TargetPlatform.linux: _FixedShellPageTransitionsBuilder(),
        },
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: isDark ? AppColors.darkSubtle : AppColors.subtle,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 19,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.35,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: TextStyle(color: muted, fontSize: 14),
        labelStyle: TextStyle(color: muted, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          elevation: 0,
          disabledBackgroundColor: isDark
              ? AppColors.darkSubtle
              : AppColors.subtle,
          disabledForegroundColor: muted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 46),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkElevatedCard : AppColors.text,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: border, width: 1.5),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return muted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary.withValues(alpha: 0.3);
          }
          return border.withValues(alpha: 0.45);
        }),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: surface,
        indicatorColor: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
      textTheme: TextTheme(
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
          fontSize: 19,
          height: 1.25,
          fontWeight: FontWeight.w800,
          color: text,
          letterSpacing: -0.35,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        bodyLarge: TextStyle(
          fontSize: 14,
          height: 1.45,
          fontWeight: FontWeight.w400,
          color: text,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          height: 1.45,
          fontWeight: FontWeight.w400,
          color: muted,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          height: 1.4,
          fontWeight: FontWeight.w400,
          color: muted,
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        labelMedium: TextStyle(
          fontSize: 11,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: muted,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: muted,
        ),
      ),
    );
  }
}

/// Root routes swap immediately so shared shell controls (drawer and bottom
/// navigation) never slide with the page. AppPage animates only its content.
class _FixedShellPageTransitionsBuilder extends PageTransitionsBuilder {
  const _FixedShellPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
