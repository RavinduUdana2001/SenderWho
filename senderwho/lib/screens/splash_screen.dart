import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../widgets/senderwho_brand.dart';

class AppLaunchState {
  const AppLaunchState({required this.authenticated, required this.themeMode});
  final bool authenticated;
  final ThemeMode themeMode;
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.startup,
    required this.onReady,
    this.onLogoReady,
    this.firstFrameRasterized,
  });
  final Future<AppLaunchState> startup;
  final ValueChanged<AppLaunchState> onReady;
  final VoidCallback? onLogoReady;
  final Future<void>? firstFrameRasterized;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller, _exitController;
  late final Animation<double> _fade, _scale;
  late final Animation<Offset> _slide;
  AppLaunchState? _launch;
  bool _started = false, _leaving = false, _releasedFirstFrame = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 900),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _finishIfReady();
            if (mounted) setState(() {});
          }
        });
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    final curve = CurveTween(curve: Curves.easeOutCubic);
    _fade = _controller.drive(Tween(begin: .3, end: 1.0).chain(curve));
    _scale = _controller.drive(Tween(begin: .86, end: 1.0).chain(curve));
    _slide = _controller.drive(
      Tween(begin: const Offset(0, .06), end: Offset.zero).chain(curve),
    );
    unawaited(_restore());
  }

  Future<void> _restore() async {
    AppLaunchState launch;
    try {
      launch = await widget.startup;
    } on Object {
      launch = const AppLaunchState(
        authenticated: false,
        themeMode: ThemeMode.dark,
      );
    }
    if (!mounted) return;
    setState(() => _launch = launch);
    _finishIfReady();
  }

  void _releaseFirstFrame() {
    if (_releasedFirstFrame) return;
    _releasedFirstFrame = true;
    widget.onLogoReady?.call();
  }

  Future<void> _warmLogo() async {
    try {
      await precacheImage(
        SenderWhoLogo.image,
        context,
        onError: (_, _) {},
      ).timeout(const Duration(milliseconds: 800));
    } on Object {
      /* Native launch must also be released after a decoding failure. */
    }
    _releaseFirstFrame();
    // GPU setup on the first frame can be much slower than subsequent frames.
    // Start the animation clock after that frame is actually displayed.
    try {
      await widget.firstFrameRasterized?.timeout(const Duration(seconds: 2));
    } on Object {
      // Keep launch usable if the platform cannot report its first raster.
    }
    if (mounted) _startEntrance();
  }

  void _startEntrance() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      if (MediaQuery.disableAnimationsOf(context)) _controller.value = 1;
      return;
    }
    _started = true;
    if (widget.onLogoReady != null) {
      unawaited(_warmLogo());
    } else {
      _startEntrance();
    }
  }

  void _finishIfReady() {
    if (_leaving || _launch == null || !_controller.isCompleted) return;
    _leaving = true;
    unawaited(_leaveSplash());
  }

  Future<void> _leaveSplash() async {
    // Finish the outgoing wordmark before moving the logo to the next page.
    // The destination can then fade in without two overlapping brand names.
    try {
      if (MediaQuery.disableAnimationsOf(context)) {
        _exitController.value = 1;
      } else {
        await _exitController.forward().orCancel;
      }
    } on TickerCanceled {
      return;
    }
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady(_launch!);
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    _releaseFirstFrame();
    _controller.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.darkBackground,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        key: const ValueKey('senderwho-splash'),
        backgroundColor: AppColors.darkBackground,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: ExcludeSemantics(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: _BrandRipple(_controller)),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: ScaleTransition(
                        scale: _scale,
                        child: RepaintBoundary(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SenderWhoLogo(size: 88),
                              const SizedBox(height: 20),
                              FadeTransition(
                                key: const ValueKey('splash-wordmark-exit'),
                                opacity: ReverseAnimation(_exitController),
                                child: const SenderWhoWordmark(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BrandRipple extends CustomPainter {
  _BrandRipple(this.animation) : super(repaint: animation);
  final Animation<double> animation;
  @override
  void paint(Canvas canvas, Size size) {
    final progress = Curves.easeOutCubic.transform(animation.value);
    final center = size.center(Offset.zero) - const Offset(0, 24);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 2; i++) {
      paint.color = AppColors.darkPrimary.withValues(
        alpha: (1 - progress) * .26,
      );
      canvas.drawCircle(center, 64 + progress * (100 + i * 45), paint);
    }
  }

  @override
  bool shouldRepaint(_BrandRipple oldDelegate) =>
      animation != oldDelegate.animation;
}
