import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // Reference-board palette. Visual accents use the supplied colors exactly;
  // action fills use slightly deeper companions where white text requires AA
  // contrast.
  static const Color brandNavy = Color(0xFF0B1630);
  static const Color brandBlue = Color(0xFF4058D8);
  static const Color brandViolet = Color(0xFF5B4FD1);
  static const Color brandCyan = Color(0xFF3A8DFF);
  static const Color brandMagenta = Color(0xFFC85B76);
  static const Color darkPrimary = Color(0xFF7C8CFF);
  static const Color darkSecondary = Color(0xFFA78BFA);
  static const Color darkAccent = Color(0xFF60A5FA);
  static const Color darkDanger = Color(0xFFFB7185);
  static const Color darkSuccess = Color(0xFF36D399);
  static const Color darkWarning = Color(0xFFFBBF24);
  static const Color darkInfo = Color(0xFF60A5FA);
  static const Color darkSocial = Color(0xFFF0A6C5);

  static const Color lightVisualPrimary = Color(0xFF4F6BFF);
  static const Color lightVisualSecondary = Color(0xFF7A6CFF);
  static const Color lightVisualSuccess = Color(0xFF2BBF9B);
  static const Color lightVisualInfo = Color(0xFF3A8DFF);
  static const Color lightVisualAlert = Color(0xFFE46A6A);
  static const Color darkVisualPrimary = darkPrimary;
  static const Color darkVisualSecondary = darkSecondary;

  // Third-party and data-visualization colors live here so screens never own
  // raw color values. Provider colors intentionally retain their identities.
  static const Color google = Color(0xFF4285F4);
  static const Color googleContainer = Color(0xFFEAF1FF);
  static const Color microsoft = Color(0xFF2563B9);
  static const Color microsoftContainer = Color(0xFFE8F1FC);
  static const Color yahoo = Color(0xFF6001D2);
  static const Color yahooContainer = Color(0xFFF1E7FF);
  static const Color social = Color(0xFFA54F78);
  static const Color medalGold = Color(0xFFF5B942);
  static const Color medalSilver = Color(0xFF9AA7BA);
  static const Color medalBronze = Color(0xFFC98755);
  static const Color info = Color(0xFF176FC7);

  static const Color background = Color(0xFFF6F8FC);
  static const Color darkBackground = Color(0xFF07111F);
  static const Color card = Color(0xFFFFFFFF);
  static const Color darkCard = Color(0xFF0D1728);
  static const Color elevatedCard = Color(0xFFFAFBFF);
  static const Color darkElevatedCard = Color(0xFF122038);
  static const Color text = Color(0xFF162033);
  static const Color darkText = Color(0xFFF3F7FF);
  static const Color muted = Color(0xFF5F6C85);
  static const Color darkMuted = Color(0xFF94A3B8);
  static const Color secondary = Color(0xFF71809A);
  static const Color subtle = Color(0xFFEEF3FF);
  static const Color darkTertiaryMuted = Color(0xFF64748B);
  static const Color darkSubtle = Color(0xFF18263B);
  static const Color border = Color(0xFFD8E2F2);
  static const Color primary = lightVisualPrimary;
  static const Color indigo = lightVisualSecondary;
  static const Color cyan = brandCyan;
  // Semantic colors stay distinct from navigation and brand actions so status
  // can be understood without relying on copy alone.
  static const Color success = Color(0xFF167C66);
  static const Color warning = Color(0xFF966515);
  static const Color orange = Color(0xFF9A5F19);
  static const Color danger = Color(0xFFC74C4C);
  static const Color chipBlue = Color(0xFFEEF3FF);
  static const Color chipGreen = chipBlue;
  static const Color darkBorder = Color(0xFF22324E);
  static const Color darkButtonPurple = darkVisualPrimary;
  static const Color onBrand = Color(0xFFFFFFFF);
  static const Color onBrandMuted = Color(0xFFCBD5E1);
  static const Color lightPrimaryAccent = lightVisualPrimary;
  static const Color lightSecondaryAccent = lightVisualSecondary;
  static const Color lightSuccessAccent = lightVisualSuccess;
  static const Color lightWarningAccent = Color(0xFFE0A13A);
  static const Color lightInfoAccent = lightVisualInfo;
  static const Color lightDangerAccent = lightVisualAlert;

  static const List<Color> brandGradient = [brandBlue, brandViolet];
  static const List<Color> lightBrandSurfaceGradient = [
    Color(0xFFEEF4FF),
    Color(0xFFF2EFFF),
  ];
  static const List<Color> darkBrandGradient = [
    Color(0xFF111D35),
    Color(0xFF1B2341),
  ];
  static const List<Color> brandSpectrum = [
    brandCyan,
    brandBlue,
    brandViolet,
    brandMagenta,
  ];

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color surface(BuildContext context) =>
      isDark(context) ? darkCard : card;

  static Color elevatedSurface(BuildContext context) =>
      isDark(context) ? darkElevatedCard : elevatedCard;

  /// A quiet brand-tinted surface for dashboard modules. The tint is blended
  /// into the active surface instead of being rendered as an opaque accent,
  /// so related cards feel cohesive without competing with their content.
  static Color dashboardSurface(BuildContext context) => Color.alphaBlend(
    visualAccentFor(
      context,
      primary,
    ).withValues(alpha: isDark(context) ? 0.075 : 0.032),
    surface(context),
  );

  static Color dashboardElevatedSurface(BuildContext context) =>
      Color.alphaBlend(
        visualAccentFor(
          context,
          primary,
        ).withValues(alpha: isDark(context) ? 0.095 : 0.04),
        elevatedSurface(context),
      );

  static Color dashboardBorder(BuildContext context) => Color.alphaBlend(
    visualAccentFor(
      context,
      primary,
    ).withValues(alpha: isDark(context) ? 0.16 : 0.09),
    borderFor(context),
  );

  /// Builds a translucent-looking tonal gradient on top of the current
  /// surface. Each dashboard module can have its own quiet accent while all
  /// cards retain the same depth, saturation, and contrast system.
  static List<Color> tonalGradientFor(
    BuildContext context,
    Color tint, {
    bool elevated = false,
    double intensity = 1,
  }) {
    final accent = visualAccentFor(context, tint);
    final base = elevated ? elevatedSurface(context) : surface(context);
    final dark = isDark(context);
    return [
      Color.alphaBlend(
        accent.withValues(alpha: (dark ? 0.12 : 0.052) * intensity),
        base,
      ),
      Color.alphaBlend(
        accent.withValues(alpha: (dark ? 0.045 : 0.016) * intensity),
        base,
      ),
    ];
  }

  static Color tonalBorderFor(
    BuildContext context,
    Color tint, {
    double intensity = 1,
  }) => Color.alphaBlend(
    visualAccentFor(
      context,
      tint,
    ).withValues(alpha: (isDark(context) ? 0.2 : 0.13) * intensity),
    borderFor(context),
  );

  static Color pageBackground(BuildContext context) =>
      isDark(context) ? darkBackground : background;

  static Color borderFor(BuildContext context) =>
      isDark(context) ? darkBorder : border;

  static Color mutedFor(BuildContext context) =>
      isDark(context) ? darkMuted : muted;

  static Color textFor(BuildContext context) =>
      isDark(context) ? darkText : text;

  static Color trackFor(BuildContext context) =>
      isDark(context) ? darkSubtle : subtle;

  static Color primaryFor(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static List<Color> brandGradientFor(BuildContext context) =>
      isDark(context) ? darkBrandGradient : lightBrandSurfaceGradient;

  static Color onGradientFor(BuildContext context) =>
      isDark(context) ? onBrand : brandNavy;

  static Color onGradientMutedFor(BuildContext context) =>
      isDark(context) ? onBrandMuted : muted;

  static Color gradientActionFor(BuildContext context) =>
      isDark(context) ? onBrand : lightPrimaryAccent;

  static Color successFor(BuildContext context) =>
      foregroundFor(context, success);

  /// Large non-text visuals can be lighter than their accessible text color.
  /// This keeps progress rings, bars, and icons soft in light mode while text
  /// continues using the darker semantic foreground.
  static Color visualAccentFor(BuildContext context, Color color) {
    if (isDark(context)) {
      if (color == primary || color == brandBlue) return darkVisualPrimary;
      if (color == indigo || color == brandViolet) return darkVisualSecondary;
      if (color == cyan || color == brandCyan) return darkInfo;
      if (color == success) return darkSuccess;
      if (color == warning || color == orange) return darkWarning;
      if (color == info) return darkInfo;
      if (color == danger) return darkDanger;
      return foregroundFor(context, color);
    }
    if (color == primary || color == brandBlue) return lightPrimaryAccent;
    if (color == indigo || color == brandViolet) {
      return lightSecondaryAccent;
    }
    if (color == success) return lightSuccessAccent;
    if (color == warning || color == orange) return lightWarningAccent;
    if (color == info || color == cyan || color == brandCyan) {
      return lightInfoAccent;
    }
    if (color == danger) return lightDangerAccent;
    return color;
  }

  static Color successVisualFor(BuildContext context) =>
      visualAccentFor(context, success);

  static Color secondaryFor(BuildContext context) =>
      Theme.of(context).colorScheme.secondary;

  static Color dangerFor(BuildContext context) =>
      Theme.of(context).colorScheme.error;

  /// Resolves colors used as text or icons against the current page surface.
  /// Brand fills retain their deeper base colors via the constants above.
  static Color foregroundFor(BuildContext context, Color color) {
    if (!isDark(context)) return color;
    if (color == primary || color == brandBlue) return darkPrimary;
    if (color == indigo || color == brandViolet) return darkSecondary;
    if (color == cyan || color == brandCyan) return darkInfo;
    if (color == info) return darkInfo;
    if (color == success) return darkSuccess;
    if (color == warning || color == orange) return darkWarning;
    if (color == danger) return darkDanger;
    if (color == social) return darkSocial;
    if (color == muted || color == secondary) return darkMuted;
    return color;
  }

  static Color softFill(BuildContext context, Color color) => foregroundFor(
    context,
    color,
  ).withValues(alpha: isDark(context) ? 0.18 : 0.085);

  static List<Color> pageGradient(BuildContext context) => isDark(context)
      ? const [Color(0xFF0A172A), darkBackground, Color(0xFF0A1020)]
      : const [Color(0xFFF8FAFF), background, Color(0xFFF8F7FF)];

  static Color brandGlow(BuildContext context, Color color) =>
      color.withValues(alpha: isDark(context) ? 0.1 : 0.038);

  static Color shadowFor(BuildContext context) => isDark(context)
      ? Colors.black.withValues(alpha: 0.26)
      : brandNavy.withValues(alpha: 0.075);

  static Color shadowForBrightness(Brightness brightness) =>
      brightness == Brightness.dark
      ? Colors.black.withValues(alpha: 0.26)
      : brandNavy.withValues(alpha: 0.075);
}
