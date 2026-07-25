import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/responsive.dart';

/// Shared viewport treatment for onboarding and authentication screens.
///
/// The intrinsic-height wrapper lets a short page use [Spacer] to balance its
/// content vertically, while the scroll view remains available for compact
/// phones, landscape, keyboards, and large accessibility text.
class ResponsiveEntryPage extends StatelessWidget {
  const ResponsiveEntryPage({
    super.key,
    required this.child,
    this.leading,
    this.maxWidth = 420,
    this.topPadding = 18,
    this.bottomPadding = 22,
  });

  final Widget child;
  final Widget? leading;
  final double maxWidth;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.pageBackground(context),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: const Alignment(0, 0.45),
            colors: AppColors.pageGradient(context),
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) {
              final horizontal = context.pageHorizontalPadding;
              final contentWidth = math.min(
                math.max(0.0, viewport.maxWidth - (horizontal * 2)),
                maxWidth,
              );
              final contentHeight = math.max(
                0.0,
                viewport.maxHeight - topPadding - bottomPadding,
              );

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  topPadding,
                  horizontal,
                  bottomPadding,
                ),
                child: Center(
                  child: SizedBox(
                    width: contentWidth,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: contentHeight),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: leading == null ? 0 : 54,
                              ),
                              child: child,
                            ),
                          ),
                          if (leading != null)
                            Positioned(top: 0, left: 0, child: leading!),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
