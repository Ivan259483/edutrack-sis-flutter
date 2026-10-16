// Form rules (they must match the EduTrack API and the web portals), the
// API error helpers, Forgot Password, and what happens when the API refuses
// an old token.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:edutrack_mobile/app.dart';
import 'package:edutrack_mobile/core/api.dart';
import 'package:edutrack_mobile/core/validation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryTokens extends TokenStore {
  MemoryTokens(this.stored);
  String? stored;
  @override
  Future<String?> readPersisted() async => stored;
  @override
  Future<void> writePersisted(String token) async => stored = token;
  @override
  Future<void> deletePersisted() async => stored = null;
}

/// Answers each request with `handler`, and records them.
class ScriptedApi implements HttpClientAdapter {
  ScriptedApi(this.handler);
  final (int, Object) Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final (status, body) = handler(options);
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

DioException apiError(int status, Map<String, dynamic> body) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: status, data: body),
);

Future<(ScriptedApi, MemoryTokens)> pumpWith(WidgetTester tester, ScriptedApi fake, {String? token}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  final tokens = MemoryTokens(token);
  final dio = Dio(BaseOptions(baseUrl: 'http://test/api'))..httpClientAdapter = fake;
  await tester.pumpWidget(EduTrackApp(api: ApiClient(tokens, dio: dio)));
  await tester.pumpAndSettle();
  return (fake, tokens);
}

Future<void> enter(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// Real Roboto metrics, as in screens_test.dart (the default test font's
/// square glyphs are about twice as wide, so layouts would overflow).
Future<void> loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (root == null || !dir.existsSync()) return;
  ByteData read(String name) => ByteData.sublistView(File('${dir.path}/$name').readAsBytesSync());
  final roboto = FontLoader('Roboto');
  for (final weight in ['Light', 'Regular', 'Medium', 'Bold']) {
    roboto.addFont(Future.value(read('Roboto-$weight.ttf')));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(Future.value(read('MaterialIcons-Regular.otf')))).load();
}

void main() {
  setUpAll(loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('rules match the API and the web', () {
    test('names allow ñ, accents, periods, hyphens and apostrophes', () {
      for (final name in ['Peñaflor', 'Ma. Clara', 'Dela Cruz', "O'Neil", 'José-María']) {
        expect(personName(name, 'First name'), isNull, reason: name);
      }
      expect(personName('J', 'First name'), 'First name must be 2–50 characters.');
      expect(personName('Cruz2', 'Last name'), 'Last name may only contain letters, spaces, hyphens, apostrophes and periods.');
      expect(personName('', 'First name'), 'First name is required.');
    });

    test('passwords need upper and lower case, a number and a symbol', () {
      expect(strongPassword('Passw0rd!'), isNull);
      for (final weak in ['password', 'Password1', 'PASSWORD1!', 'Pa1!']) {
        expect(strongPassword(weak), passwordMessage, reason: weak);
      }
      expect(confirmPassword('Passw0rd?', 'Passw0rd!'), 'Passwords do not match.');
      expect(passwordChecks.where((c) => c.$2('abc')).map((c) => c.$1), ['A lowercase letter']);
    });

    test('student IDs, phones, emails and codes', () {
      expect(studentId('2024-00115'), isNull);
      expect(studentId('24-115'), 'Student ID must use the format YYYY-NNNNN, e.g. 2024-00115.');
      expect(phone('0917 123 4567', 'Mobile number'), isNull);
      expect(phone('+63 917 123 4567', 'Mobile number'), isNull);
      expect(phone('call me', 'Mobile number'), 'Enter a valid phone number for mobile number, e.g. 0917 123 4567.');
      expect(phone('Not provided', 'Contact number', allowPlaceholder: true), isNull);
      expect(email('juan@'), 'Enter a valid email address.');
      expect(digitsCode('12345', resetCodeLength), 'Enter the 6-digit code from your email.');
      expect(pastDate('2999-01-01', 'Date enrolled', '2026-10-16'), 'Date enrolled cannot be in the future.');
      expect(room('Rm <401>'), 'Room may only contain letters, numbers, spaces, periods, # and hyphens.');
    });

    test('API field errors and wait times are read from the error body', () {
      final error = apiError(409, {
        'message': 'Email is already registered.',
        'errors': [
          {'field': 'email', 'message': 'Email is already registered.'},
        ],
      });
      expect(apiFieldErrors(error), {'email': 'Email is already registered.'});
      expect(apiRetryAfter(apiError(429, {'message': 'Please wait 42 seconds before requesting another code.', 'retryAfter': 42})), 42);
      expect(apiRetryAfter(error), isNull);
    });
  });

  testWidgets('login shows the website messages and links to Forgot Password', (tester) async {
    await pumpWith(tester, ScriptedApi((o) => (404, {'message': 'not found'})));
    await tapKey(tester, 'login-submit');
    expect(find.text('Enter your email or Student ID.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    await tapKey(tester, 'login-forgot');
    expect(find.text('Reset Your Password'), findsOneWidget);
  });

  testWidgets('forgot password: code, new password, then back to login with a notice', (tester) async {
    final fake = ScriptedApi((o) {
      if (o.path.endsWith('/auth/forgot-password')) {
        return (200, {'status': 'success', 'message': 'If an account matches, we sent a code to its email.', 'retryAfter': 60});
      }
      if (o.path.endsWith('/auth/reset-password')) {
        final body = o.data as Map;
        if (body['code'] != '123456') {
          return (400, {
            'message': 'The code is incorrect or has expired.',
            'errors': [
              {'field': 'code', 'message': 'The code is incorrect or has expired. Check your latest email or request a new code.'},
            ],
          });
        }
        return (200, {'status': 'success', 'message': 'Your password has been reset.'});
      }
      return (404, {'message': 'not found'});
    });
    await pumpWith(tester, fake);
    await tapKey(tester, 'login-forgot');
    await enter(tester, 'forgot-identifier', '2024-00115');
    await tapKey(tester, 'forgot-send');
    expect(find.textContaining('If an account matches, we sent a code to its email.'), findsOneWidget);
    expect(find.text('Resend Code in 60s'), findsOneWidget);

    // Weak password and mismatched confirmation are caught before the API.
    await enter(tester, 'forgot-code', '123456');
    await enter(tester, 'forgot-password', 'weakpass');
    await enter(tester, 'forgot-confirm', 'weakpas');
    await tapKey(tester, 'forgot-reset');
    expect(find.text(passwordMessage), findsOneWidget);
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(fake.requests.where((r) => r.path.endsWith('/auth/reset-password')), isEmpty);

    // A wrong code comes back from the API under the code field.
    await enter(tester, 'forgot-code', '000000');
    await enter(tester, 'forgot-password', 'Fresh#Pass9');
    await enter(tester, 'forgot-confirm', 'Fresh#Pass9');
    await tapKey(tester, 'forgot-reset');
    expect(find.textContaining('The code is incorrect or has expired.'), findsOneWidget);

    await enter(tester, 'forgot-code', '123456');
    await tapKey(tester, 'forgot-reset');
    expect(find.text('Your password has been reset. Sign in with your new password.'), findsOneWidget);
    expect(find.text('EduTrack SIS'), findsOneWidget);
    final sent = fake.requests.last.data as Map;
    expect(sent, containsPair('identifier', '2024-00115'));
    expect(sent, containsPair('confirmPassword', 'Fresh#Pass9'));
  });

  testWidgets('forgot password shows how long to wait when the API says to slow down', (tester) async {
    await pumpWith(
      tester,
      ScriptedApi((o) => (429, {'message': 'Please wait 42 seconds before requesting another code.', 'retryAfter': 42})),
    );
    await tapKey(tester, 'login-forgot');
    await enter(tester, 'forgot-identifier', 'juan@example.com');
    await tapKey(tester, 'forgot-send');
    expect(find.text('Please wait 42 seconds before requesting another code.'), findsOneWidget);
  });

  testWidgets('a token refused after a password reset goes back to login with the reason', (tester) async {
    final (_, tokens) = await pumpWith(
      tester,
      ScriptedApi((o) => (401, {'message': 'Your password was changed. Please sign in again.'})),
      token: 'old-token',
    );
    expect(find.text('Your password was changed. Please sign in again.'), findsOneWidget);
    expect(find.text('EduTrack SIS'), findsOneWidget);
    expect(tokens.stored, isNull);
  });
}
