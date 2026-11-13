import 'package:flutter/material.dart';

class ThemeModeController extends InheritedWidget {
  const ThemeModeController({
    super.key,
    required this.mode,
    required this.setThemeMode,
    this.updateThemeMode,
    required super.child,
  });

  final ThemeMode mode;
  final ValueChanged<ThemeMode> setThemeMode;
  final Future<bool> Function(ThemeMode mode, Future<bool> Function() save)?
  updateThemeMode;

  static ThemeModeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeModeController>();

  Future<bool> changeThemeMode(
    ThemeMode next, {
    required Future<bool> Function() save,
  }) async {
    if (updateThemeMode != null) return updateThemeMode!(next, save);
    final previous = mode;
    setThemeMode(next);
    var saved = false;
    try {
      saved = await save();
    } on Object {
      saved = false;
    }
    if (!saved) setThemeMode(previous);
    return saved;
  }

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
