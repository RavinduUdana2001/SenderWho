import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_system_ui.dart';
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
    return AnnotatedRegion(
      value: AppSystemUi.style(context),
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.pageBackground(context),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: const Alignment(0, 0.45),
              colors: AppColors.pageGradient(context),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const RepaintBoundary(child: _EntryAmbientBackground()),
              SafeArea(
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
                      physics: switch (Theme.of(context).platform) {
                        TargetPlatform.iOS ||
                        TargetPlatform.macOS => const BouncingScrollPhysics(),
                        _ => const ClampingScrollPhysics(),
                      },
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
                            constraints: BoxConstraints(
                              minHeight: contentHeight,
                            ),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryAmbientBackground extends StatelessWidget {
  const _EntryAmbientBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -170,
            right: -150,
            child: _EntryGlow(color: AppColors.cyan, size: 340),
          ),
          Positioned(
            bottom: -210,
            left: -190,
            child: _EntryGlow(color: AppColors.indigo, size: 390),
          ),
        ],
      ),
    );
  }
}

class _EntryGlow extends StatelessWidget {
  const _EntryGlow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.brandGlow(context, color),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
