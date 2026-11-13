import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_system_ui.dart';
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
    this.plainBackground = true,
    this.header,
    this.onRefresh,
  });

  final Widget child;
  final bool scrollable;
  final bool drawer;
  final Widget? bottomNavigationBar;
  final double? maxContentWidth;
  final bool plainBackground;
  final Widget? header;
  final Future<void> Function()? onRefresh;

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
            header == null ? context.verticalGap(14) : 8,
            context.pageHorizontalPadding,
            context.verticalGap(32),
          ),
          child: child,
        ),
      ),
    );

    return AnnotatedRegion(
      value: AppSystemUi.style(
        context,
        navigationBarColor: AppColors.surface(context),
      ),
      child: Scaffold(
        drawer: drawer ? const SenderDrawer() : null,
        drawerScrimColor: AppColors.brandNavy.withValues(
          alpha: AppColors.isDark(context) ? 0.78 : 0.58,
        ),
        bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
            ? null
            : bottomNavigationBar ??
                  (drawer ? const AppBottomNavigation() : null),
        body: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.pageBackground(context),
            gradient: plainBackground
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: AppColors.pageGradient(context),
                  ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!plainBackground)
                const RepaintBoundary(child: _BrandAmbientBackground()),
              SafeArea(
                child: FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: Column(
                    children: [
                      if (header != null)
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1100),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                context.pageHorizontalPadding,
                                8,
                                context.pageHorizontalPadding,
                                4,
                              ),
                              child: header,
                            ),
                          ),
                        ),
                      Expanded(
                        child: scrollable
                            ? _scrollBody(context, content)
                            : SizedBox.expand(child: content),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scrollBody(BuildContext context, Widget content) {
    final scroll = SingleChildScrollView(
      key: PageStorageKey('page-${ModalRoute.of(context)?.hashCode}'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: _pageScrollPhysics(context),
      child: content,
    );
    return onRefresh == null
        ? scroll
        : RefreshIndicator(onRefresh: onRefresh!, child: scroll);
  }
}

class _BrandAmbientBackground extends StatelessWidget {
  const _BrandAmbientBackground();

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.visualAccentFor(context, AppColors.primary);
    final secondary = AppColors.visualAccentFor(context, AppColors.cyan);
    final violet = AppColors.visualAccentFor(context, AppColors.indigo);
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 260,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    primary.withValues(
                      alpha: AppColors.isDark(context) ? 0.04 : 0.022,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -180,
            right: -175,
            child: _Glow(color: secondary, size: 360),
          ),
          Positioned(
            bottom: -220,
            left: -210,
            child: _Glow(color: violet, size: 420),
          ),
        ],
      ),
    );
  }
}

ScrollPhysics _pageScrollPhysics(BuildContext context) {
  return switch (Theme.of(context).platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    ),
    _ => const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
  };
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
