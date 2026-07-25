import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // SenderWho brand foundations sampled and normalized from the supplied logo.
  // Cyan is reserved for highlights; the deeper blue/violet pair keeps white
  // button copy accessible in both brightness modes.
  static const Color brandNavy = Color(0xFF07142E);
  static const Color brandCyan = Color(0xFF08CFE8);
  static const Color brandBlue = Color(0xFF315CF5);
  static const Color brandViolet = Color(0xFF7438F2);
  static const Color brandMagenta = Color(0xFFC94DDF);

  static const Color background = Color(0xFFF4F7FF);
  static const Color darkBackground = Color(0xFF060D1E);
  static const Color card = Color(0xFFFFFFFF);
  static const Color darkCard = Color(0xFF0D1932);
  static const Color elevatedCard = Color(0xFFFAFBFF);
  static const Color darkElevatedCard = Color(0xFF13213F);
  static const Color text = Color(0xFF0C1732);
  static const Color darkText = Color(0xFFF6F8FF);
  static const Color muted = Color(0xFF62708B);
  static const Color darkMuted = Color(0xFFB2BDD3);
  static const Color secondary = Color(0xFF7784A0);
  static const Color subtle = Color(0xFFEBF0FB);
  static const Color darkSubtle = Color(0xFF1A2948);
  static const Color border = Color(0xFFD9E2F2);
  static const Color primary = brandBlue;
  static const Color indigo = brandViolet;
  static const Color cyan = brandCyan;
  // Positive states use the core SenderWho blue instead of an unrelated
  // green. Warning and danger retain distinct semantic colors.
  static const Color success = brandBlue;
  static const Color warning = Color(0xFFF4B740);
  static const Color orange = Color(0xFFF59E42);
  static const Color danger = Color(0xFFF0445E);
  static const Color chipBlue = Color(0xFFEDF2FF);
  static const Color chipGreen = chipBlue;
  static const Color darkBorder = Color(0xFF283B61);
  static const Color darkButtonPurple = brandViolet;

  static const List<Color> brandGradient = [brandBlue, brandViolet];
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

  static Color softFill(BuildContext context, Color color) =>
      color.withValues(alpha: isDark(context) ? 0.16 : 0.1);

  static List<Color> pageGradient(BuildContext context) => isDark(context)
      ? const [Color(0xFF0A1630), darkBackground, Color(0xFF100A24)]
      : const [Color(0xFFFBFDFF), background, Color(0xFFF8F4FF)];

  static Color brandGlow(BuildContext context, Color color) =>
      color.withValues(alpha: isDark(context) ? 0.13 : 0.08);

  static Color shadowFor(BuildContext context) => isDark(context)
      ? Colors.black.withValues(alpha: 0.3)
      : brandNavy.withValues(alpha: 0.07);
}
