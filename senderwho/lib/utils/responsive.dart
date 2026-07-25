import 'dart:math' as math;

import 'package:flutter/widgets.dart';

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  double get pageHorizontalPadding {
    final width = screenWidth;
    if (width <= 340) return 14;
    if (width >= 900) return 36;
    if (width >= 600) return 30;
    if (width >= 430) return 22;
    return 20;
  }

  double get maxContentWidth =>
      math.min(screenWidth - (pageHorizontalPadding * 2), 560);

  double gap(double value) {
    final factor = (screenWidth / 390).clamp(0.88, 1.08);
    return value * factor;
  }

  double verticalGap(double value) {
    final widthFactor = (screenWidth / 390).clamp(0.88, 1.08);
    final heightFactor = (screenHeight / 844).clamp(0.82, 1.08);
    return value * math.min(widthFactor, heightFactor);
  }
}
