import 'package:flutter/foundation.dart';

import 'api.dart';

enum SessionStatus { loading, signedOut, signedIn }

/// The signed-in account (`publicUser` in backend/controllers/authController.js).
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.studentId,
    this.profile,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        name: (json['name'] ?? '') as String,
        email: (json['email'] ?? '') as String,
        role: (json['role'] ?? 'student') as String,
        studentId: json['studentId'] as String?,
        profile: json['profile'] is Map ? Map<String, dynamic>.from(json['profile'] as Map) : null,
      );

  final String id;
  final String name;
  final String email;
  final String role;
  final String? studentId;

  /// The student's record for student accounts.
  final Map<String, dynamic>? profile;

  bool get isAdmin => role == 'admin';
}

/// Signed-in user and auth actions (the web's AuthContext / admin SessionProvider).
class Session extends ChangeNotifier {
  Session(this.api) {
    api.onUnauthorized = _expire;
  }

  final ApiClient api;
  SessionStatus status = SessionStatus.loading;
  AppUser? user;

  /// Re-validates a remembered token with the server when the app starts.
  Future<void> restore() async {
    final token = await api.tokens.load();
    if (token == null) {
      _set(SessionStatus.signedOut, null);
      return;
    }
    try {
      final data = await api.get('/auth/me') as Map<String, dynamic>;
      _set(SessionStatus.signedIn, AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map)));
    } catch (_) {
      await api.tokens.clear();
      _set(SessionStatus.signedOut, null);
    }
  }

  /// Returns null on success, or the error message to show.
  Future<String?> login(String identifier, String password, String role, {bool remember = false}) async {
    try {
      final data = await api.post('/auth/login', {
        'identifier': identifier,
        'password': password,
        'role': role,
      }) as Map<String, dynamic>;
      await api.tokens.save(data['token'] as String, remember: remember);
      _set(SessionStatus.signedIn, AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map)));
      return null;
    } catch (error) {
      return apiErrorMessage(error, 'Login failed. Please check your credentials.');
    }
  }

  /// Refreshes the stored profile after it changes on the server.
  Future<void> refreshUser() async {
    final data = await api.get('/auth/me') as Map<String, dynamic>;
    _set(SessionStatus.signedIn, AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map)));
  }

  Future<void> logout() async {
    await api.tokens.clear();
    _set(SessionStatus.signedOut, null);
  }

  void _expire() {
    if (status == SessionStatus.signedIn) logout();
  }

  void _set(SessionStatus next, AppUser? nextUser) {
    status = next;
    user = nextUser;
    notifyListeners();
  }
}
