import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SessionStore {
  Future<String?> readRefreshToken();
  Future<void> writeRefreshToken(String token);
  Future<String?> readDeviceId();
  Future<void> writeDeviceId(String deviceId);
  Future<String?> readRememberedEmail();
  Future<void> writeRememberedEmail(String email);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _refreshTokenKey = 'senderwho_refresh_token';
  static const _deviceIdKey = 'senderwho_device_id';
  static const _rememberedEmailKey = 'senderwho_remembered_email';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  @override
  Future<void> writeRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);

  @override
  Future<String?> readDeviceId() => _storage.read(key: _deviceIdKey);

  @override
  Future<void> writeDeviceId(String deviceId) =>
      _storage.write(key: _deviceIdKey, value: deviceId);

  @override
  Future<String?> readRememberedEmail() =>
      _storage.read(key: _rememberedEmailKey);

  @override
  Future<void> writeRememberedEmail(String email) =>
      _storage.write(key: _rememberedEmailKey, value: email);

  @override
  Future<void> clear() => _storage.delete(key: _refreshTokenKey);
}

class MemorySessionStore implements SessionStore {
  String? refreshToken;
  String? deviceId;
  String? rememberedEmail;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> writeRefreshToken(String token) async {
    refreshToken = token;
  }

  @override
  Future<String?> readDeviceId() async => deviceId;

  @override
  Future<void> writeDeviceId(String value) async {
    deviceId = value;
  }

  @override
  Future<String?> readRememberedEmail() async => rememberedEmail;

  @override
  Future<void> writeRememberedEmail(String email) async {
    rememberedEmail = email;
  }

  @override
  Future<void> clear() async {
    refreshToken = null;
  }
}
