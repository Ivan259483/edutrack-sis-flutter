import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';

/// Holds the JWT. It is kept in memory for requests and, when "Remember Me"
/// is checked, also in the platform's secure storage (Android Keystore).
class TokenStore {
  TokenStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'edutrack_token';
  final FlutterSecureStorage _storage;
  String? _token;

  String? get token => _token;

  /// Reads a remembered token at startup.
  Future<String?> load() async {
    try {
      _token = await readPersisted();
    } catch (_) {
      _token = null;
    }
    return _token;
  }

  Future<void> save(String token, {required bool remember}) async {
    _token = token;
    try {
      remember ? await writePersisted(token) : await deletePersisted();
    } catch (_) {
      // Storage unavailable: the session lasts until the app closes.
    }
  }

  Future<void> clear() async {
    _token = null;
    try {
      await deletePersisted();
    } catch (_) {
      // Nothing stored.
    }
  }

  @protected
  Future<String?> readPersisted() => _storage.read(key: _key);
  @protected
  Future<void> writePersisted(String token) => _storage.write(key: _key, value: token);
  @protected
  Future<void> deletePersisted() => _storage.delete(key: _key);
}

/// Dio instance for the EduTrack API, like the web's Axios instance: attaches
/// the JWT to every request, and an expired or rejected token (401) signs the
/// user out everywhere.
class ApiClient {
  ApiClient(this.tokens, {String? baseUrl, Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl ?? apiUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 15),
            ),
          ) {
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = tokens.token;
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401 && !error.requestOptions.path.contains('/auth/login')) {
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final TokenStore tokens;
  final Dio dio;

  /// Set by the session: ends it when the server rejects the token.
  VoidCallback? onUnauthorized;

  Future<dynamic> get(String path) async => (await dio.get<dynamic>(path)).data;
  Future<dynamic> post(String path, [Object? body]) async => (await dio.post<dynamic>(path, data: body)).data;
  Future<dynamic> put(String path, [Object? body]) async => (await dio.put<dynamic>(path, data: body)).data;
  Future<dynamic> delete(String path) async => (await dio.delete<dynamic>(path)).data;
  Future<dynamic> request(String method, String path, [Object? body]) async => (await dio.request<dynamic>(
    path,
    data: body,
    options: Options(method: method.toUpperCase()),
  )).data;
}

/// Human-readable message from an API/network error.
String apiErrorMessage(Object error, [String fallback = 'Something went wrong. Please try again.']) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String && (data['message'] as String).isNotEmpty) {
      return data['message'] as String;
    }
    if (error.response == null) return 'Cannot reach the EduTrack server at $apiUrl.';
    return fallback;
  }
  if (error is RuleError) return error.message;
  return fallback;
}

/// A business rule the app checks before calling the API (same messages as the web).
class RuleError implements Exception {
  RuleError(this.message);
  final String message;
  @override
  String toString() => message;
}
