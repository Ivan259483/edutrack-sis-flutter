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
  bool _remembered = false;

  String? get token => _token;

  /// Reads a remembered token at startup.
  Future<String?> load() async {
    try {
      _token = await readPersisted();
    } catch (_) {
      _token = null;
    }
    _remembered = _token != null;
    return _token;
  }

  /// Swaps in a new token, kept the same way as the current one. Changing the
  /// password signs out every older token, and the API returns this one.
  Future<void> replace(String token) => save(token, remember: _remembered);

  Future<void> save(String token, {required bool remember}) async {
    _token = token;
    _remembered = remember;
    try {
      remember ? await writePersisted(token) : await deletePersisted();
    } catch (_) {
      // Storage unavailable: the session lasts until the app closes.
    }
  }

  Future<void> clear() async {
    _token = null;
    _remembered = false;
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
            // e.g. "Your password was changed. Please sign in again."
            onUnauthorized?.call(apiErrorMessage(error, 'Your session has ended. Please sign in again.'));
          }
          handler.next(error);
        },
      ),
    );
  }

  final TokenStore tokens;
  final Dio dio;

  /// Set by the session: ends it when the server rejects the token, with the
  /// server's reason.
  void Function(String message)? onUnauthorized;

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

/// Field messages from an API error, keyed by field. The API answers every
/// failure as { message, errors?: [{ field, message }] }.
Map<String, String> apiFieldErrors(Object error) {
  if (error is! DioException) return const {};
  final data = error.response?.data;
  final errors = data is Map ? data['errors'] : null;
  if (errors is! List) return const {};
  return {
    for (final e in errors)
      if (e is Map && e['field'] is String && e['message'] is String) e['field'] as String: e['message'] as String,
  };
}

/// Seconds the API asks to wait before trying again (rate limits), if any.
int? apiRetryAfter(Object error) {
  if (error is! DioException) return null;
  final data = error.response?.data;
  final value = data is Map ? data['retryAfter'] : null;
  return value is num && value > 0 ? value.ceil() : null;
}

/// A business rule the app checks before calling the API (same messages as the web).
class RuleError implements Exception {
  RuleError(this.message);
  final String message;
  @override
  String toString() => message;
}
