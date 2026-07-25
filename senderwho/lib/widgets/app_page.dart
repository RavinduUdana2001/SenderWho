import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import 'sender_drawer.dart';
import 'app_bottom_navigation.dart';

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.child,
    this.scrollable = true,
    this.drawer = true,
    this.bottomNavigationBar,
    this.maxContentWidth,
  });

  final Widget child;
  final bool scrollable;
  final bool drawer;
  final Widget? bottomNavigationBar;
  final double? maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.sizeOf(context).width;
    final maxWidth =
        maxContentWidth ??
        (availableWidth >= 1200
            ? 820.0
            : availableWidth >= 700
            ? 720.0
            : 560.0);
    final content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.pageHorizontalPadding,
            context.verticalGap(14),
            context.pageHorizontalPadding,
            context.verticalGap(36),
          ),
          child: child,
        ),
      ),
    );

    return Scaffold(
      drawer: drawer ? const SenderDrawer() : null,
      drawerScrimColor: AppColors.brandNavy.withValues(
        alpha: AppColors.isDark(context) ? 0.78 : 0.58,
      ),
      bottomNavigationBar:
          bottomNavigationBar ?? (drawer ? const AppBottomNavigation() : null),
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.pageBackground(context),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.pageGradient(context),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _BrandAmbientBackground(),
            SafeArea(
              child: _PageContentEntrance(
                child: FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: scrollable
                      ? SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          physics: const BouncingScrollPhysics(),
                          child: content,
                        )
                      : SizedBox.expand(child: content),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageContentEntrance extends StatelessWidget {
  const _PageContentEntrance({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 10),
          child: child,
        ),
      ),
    );
  }
}

class _BrandAmbientBackground extends StatelessWidget {
  const _BrandAmbientBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -150,
            right: -145,
            child: _Glow(color: AppColors.cyan, size: 330),
          ),
          Positioned(
            bottom: -190,
            left: -180,
            child: _Glow(color: AppColors.indigo, size: 390),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

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
