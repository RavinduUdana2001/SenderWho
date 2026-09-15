import 'package:flutter/material.dart';

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.disabled,
    required this.onDisabled,
  });

  const AppSemanticColors.light()
    : success = const Color(0xFF167C66),
      onSuccess = Colors.white,
      successContainer = const Color(0xFFDDF9F2),
      onSuccessContainer = const Color(0xFF0B5C4A),
      warning = const Color(0xFF966515),
      onWarning = Colors.white,
      warningContainer = const Color(0xFFFFEEC9),
      onWarningContainer = const Color(0xFF65420B),
      info = const Color(0xFF176FC7),
      onInfo = Colors.white,
      infoContainer = const Color(0xFFE1EFFF),
      onInfoContainer = const Color(0xFF174E83),
      disabled = const Color(0xFFE3E9F3),
      onDisabled = const Color(0xFF5F6C85);

  const AppSemanticColors.dark()
    : success = const Color(0xFF36D399),
      onSuccess = const Color(0xFF062D23),
      successContainer = const Color(0xFF12382F),
      onSuccessContainer = const Color(0xFF9AEBD5),
      warning = const Color(0xFFFBBF24),
      onWarning = const Color(0xFF332303),
      warningContainer = const Color(0xFF3A2C13),
      onWarningContainer = const Color(0xFFFFE09A),
      info = const Color(0xFF60A5FA),
      onInfo = const Color(0xFF08213D),
      infoContainer = const Color(0xFF142D4F),
      onInfoContainer = const Color(0xFFB7D7FF),
      disabled = const Color(0xFF22324E),
      onDisabled = const Color(0xFF64748B);

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;
  final Color disabled;
  final Color onDisabled;

  static AppSemanticColors of(BuildContext context) {
    return Theme.of(context).extension<AppSemanticColors>()!;
  }

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? disabled,
    Color? onDisabled,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      disabled: disabled ?? this.disabled,
      onDisabled: onDisabled ?? this.onDisabled,
    );
  }

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other == null) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      onDisabled: Color.lerp(onDisabled, other.onDisabled, t)!,
    );
  }
}
