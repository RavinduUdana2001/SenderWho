import 'package:flutter/material.dart';

class ThemeModeController extends InheritedWidget {
  const ThemeModeController({
    super.key,
    required this.mode,
    required this.setThemeMode,
    required super.child,
  });

  final ThemeMode mode;
  final ValueChanged<ThemeMode> setThemeMode;

  static ThemeModeController of(BuildContext context) {
    final controller = context
        .dependOnInheritedWidgetOfExactType<ThemeModeController>();
    assert(controller != null, 'ThemeModeController not found in context');
    return controller!;
  }

  void setDarkMode(bool enabled) {
    setThemeMode(enabled ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  bool updateShouldNotify(ThemeModeController oldWidget) {
    return mode != oldWidget.mode;
  }
}
