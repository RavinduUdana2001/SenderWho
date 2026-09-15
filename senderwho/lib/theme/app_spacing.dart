import 'package:flutter/widgets.dart';

/// SenderWho's 8-point layout scale.
///
/// The smaller 4 and 12 point steps are intentional half-steps for dense
/// controls; page composition should prefer the 8-point values.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
  static const double xxxl = 48;

  static const EdgeInsets card = EdgeInsets.all(lg);
  static const EdgeInsets cardCompact = EdgeInsets.all(md);
  static const EdgeInsets control = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );
}
