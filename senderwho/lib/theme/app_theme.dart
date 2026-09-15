import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_semantic_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

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
    final semanticColors = isDark
        ? const AppSemanticColors.dark()
        : const AppSemanticColors.light();
    final primary = isDark ? AppColors.darkPrimary : AppColors.brandBlue;
    final visualPrimary = isDark
        ? AppColors.darkVisualPrimary
        : AppColors.lightVisualPrimary;
    final onPrimary = isDark ? AppColors.brandNavy : Colors.white;
    final secondary = isDark ? AppColors.darkSecondary : AppColors.brandViolet;
    final onSecondary = isDark ? AppColors.brandNavy : Colors.white;
    final tertiary = isDark ? AppColors.darkAccent : AppColors.cyan;
    final error = isDark ? AppColors.darkDanger : AppColors.danger;
    final onError = isDark ? const Color(0xFF3D0714) : Colors.white;
    final appTextTheme = AppTypography.textTheme(text: text, muted: muted);
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: brightness,
          surface: surface,
        ).copyWith(
          primary: primary,
          onPrimary: onPrimary,
          primaryContainer: isDark
              ? const Color(0xFF26335C)
              : const Color(0xFFE9EEFF),
          onPrimaryContainer: isDark
              ? const Color(0xFFE6E9FF)
              : AppColors.brandNavy,
          secondary: secondary,
          onSecondary: onSecondary,
          secondaryContainer: isDark
              ? const Color(0xFF30274F)
              : const Color(0xFFEEEAFF),
          onSecondaryContainer: isDark
              ? const Color(0xFFEFE8FF)
              : const Color(0xFF2E246F),
          tertiary: tertiary,
          onTertiary: AppColors.brandNavy,
          error: error,
          onError: onError,
          errorContainer: isDark
              ? const Color(0xFF482333)
              : const Color(0xFFFFE8E8),
          onErrorContainer: isDark
              ? const Color(0xFFFFD9E1)
              : const Color(0xFF8E2929),
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
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: AppTypography.fontFamilyFallback,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      cardColor: surface,
      disabledColor: semanticColors.onDisabled,
      colorScheme: colorScheme,
      extensions: [semanticColors],
      dividerColor: border,
      splashColor: primary.withValues(alpha: 0.1),
      highlightColor: primary.withValues(alpha: 0.05),
      focusColor: tertiary.withValues(alpha: 0.2),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: 0.24),
        selectionHandleColor: primary,
      ),
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
        color: primary,
        linearTrackColor: isDark ? AppColors.darkSubtle : AppColors.subtle,
        circularTrackColor: isDark ? AppColors.darkSubtle : AppColors.subtle,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: appTextTheme.titleLarge?.copyWith(
          color: text,
          height: 1.2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkElevatedCard : AppColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 15,
        ),
        hintStyle: appTextTheme.bodyMedium,
        labelStyle: appTextTheme.bodySmall,
        errorStyle: appTextTheme.bodySmall?.copyWith(color: error),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 50),
          elevation: 0,
          disabledBackgroundColor: isDark
              ? AppColors.darkSubtle
              : AppColors.subtle,
          disabledForegroundColor: muted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          textStyle: appTextTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          textStyle: appTextTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          textStyle: appTextTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkElevatedCard : AppColors.text,
        contentTextStyle: appTextTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
        showDragHandle: true,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(onPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: border, width: 1.5),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return onPrimary;
          return muted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return border.withValues(alpha: 0.45);
        }),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: border.withValues(alpha: 0.82)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: text,
        minVerticalPadding: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.darkSubtle : AppColors.subtle,
        selectedColor: primary.withValues(alpha: isDark ? 0.22 : 0.11),
        disabledColor: muted.withValues(alpha: 0.12),
        side: BorderSide(color: border.withValues(alpha: 0.75)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        labelStyle: appTextTheme.labelMedium?.copyWith(color: text),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 6,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shadowColor: AppColors.shadowForBrightness(brightness),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkText : AppColors.text,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: appTextTheme.labelMedium?.copyWith(
          color: isDark ? AppColors.text : AppColors.darkText,
        ),
        waitDuration: const Duration(milliseconds: 500),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 62,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: visualPrimary.withValues(alpha: isDark ? 0.22 : 0.11),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? visualPrimary : muted,
            size: selected ? 23 : 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return appTextTheme.labelSmall?.copyWith(
            color: selected ? visualPrimary : muted,
            height: 1.15,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          );
        }),
      ),
      textTheme: appTextTheme,
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
