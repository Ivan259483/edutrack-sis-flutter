import 'package:flutter/foundation.dart';

/// EduTrack REST API base URL, set at build time:
///   flutter run --dart-define=API_URL=http://10.0.2.2:5001/api
///   flutter build apk --dart-define=API_URL=https://edutrack-sis-api.vercel.app/api
const String _apiUrlDefine = String.fromEnvironment('API_URL');

/// Without --dart-define the app talks to a backend on this computer
/// (the Android emulator reaches the host computer as 10.0.2.2).
String get apiUrl {
  if (_apiUrlDefine.isNotEmpty) return _apiUrlDefine.replaceAll(RegExp(r'/+$'), '');
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:5001/api';
  }
  return 'http://localhost:5001/api';
}

class DemoAccount {
  const DemoAccount(this.identifier, this.password);
  final String identifier;
  final String password;
}

/// Seeded demo accounts for the local demo only (the web shows them with
/// `import.meta.env.DEV`). kDebugMode is a compile-time constant, so release
/// builds contain neither the button nor these passwords.
const Map<String, DemoAccount>? demoAccounts = kDebugMode
    ? {'student': DemoAccount('juan.delacruz@edutrack.edu', 'Student123!'), 'admin': DemoAccount('admin@edutrack.edu', 'Admin123!')}
    : null;
