import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_system_ui.dart';
import '../utils/responsive.dart';
import 'entry_artwork.dart';

/// A centered introduction with a bottom action area. Content and footer can
/// scroll together when large text, landscape, or the keyboard reduce space.
class ResponsiveEntryPage extends StatelessWidget {
  const ResponsiveEntryPage({
    super.key,
    required this.child,
    this.footer,
    this.leading,
    this.pinLeading = false,
    this.maxWidth = 420,
    this.topPadding = 18,
    this.bottomPadding = 22,
    this.contentAlignment = Alignment.center,
  });
  final Widget child;
  final Widget? footer, leading;
  final bool pinLeading;
  final double maxWidth, topPadding, bottomPadding;
  final Alignment contentAlignment;

  @override
  Widget build(BuildContext context) => AnnotatedRegion(
    value: AppSystemUi.style(context),
    child: Scaffold(
      backgroundColor: AppColors.pageBackground(context),
      body: Stack(
        children: [
          const Positioned.fill(child: EntryBackdrop()),
          SafeArea(
            child: Column(
              children: [
                if (leading != null && pinLeading)
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxWidth + context.pageHorizontalPadding * 2,
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          context.pageHorizontalPadding,
                          8,
                          context.pageHorizontalPadding,
                          0,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: leading,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, viewport) {
                      final horizontal = context.pageHorizontalPadding;
                      final width = math.min(
                        math.max(0.0, viewport.maxWidth - horizontal * 2),
                        maxWidth,
                      );
                      final height = math.max(
                        0.0,
                        viewport.maxHeight - topPadding - bottomPadding,
                      );
                      return SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          topPadding,
                          horizontal,
                          bottomPadding,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: height,
                              maxWidth: width,
                            ),
                            child: IntrinsicHeight(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (leading != null && !pinLeading)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: leading,
                                    ),
                                  Expanded(
                                    child: Align(
                                      alignment: contentAlignment,
                                      child: child,
                                    ),
                                  ),
                                  if (footer != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 32),
                                      child: footer!,
                                    ),
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
        ],
      ),
    ),
  );
}
