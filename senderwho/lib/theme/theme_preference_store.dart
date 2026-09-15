import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class ThemePreferenceStore {
  Future<ThemeMode?> read();
  Future<void> write(ThemeMode mode);
}

class SecureThemePreferenceStore implements ThemePreferenceStore {
  SecureThemePreferenceStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'senderwho_theme_mode';
  final FlutterSecureStorage _storage;

  @override
  Future<ThemeMode?> read() async {
    final value = await _storage.read(key: _key);
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => null,
    };
  }

  @override
  Future<void> write(ThemeMode mode) {
    return _storage.write(key: _key, value: mode.name);
  }
}

class MemoryThemePreferenceStore implements ThemePreferenceStore {
  MemoryThemePreferenceStore([this.mode]);

  ThemeMode? mode;

  @override
  Future<ThemeMode?> read() async => mode;

  @override
  Future<void> write(ThemeMode mode) async {
    this.mode = mode;
  }
}
