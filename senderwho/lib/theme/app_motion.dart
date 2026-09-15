import 'package:flutter/widgets.dart';

abstract final class AppMotion {
  static const Duration instant = Duration.zero;
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration deliberate = Duration(milliseconds: 300);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  static Duration responsive(BuildContext context, Duration duration) {
    return MediaQuery.disableAnimationsOf(context) ? instant : duration;
  }
}
