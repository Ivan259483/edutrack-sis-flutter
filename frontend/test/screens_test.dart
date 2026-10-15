// Renders every student and admin screen on a phone-sized window against
// real API responses (test/fixtures/api.json, captured from a local backend
// seeded with the demo data), and checks that admin changes send the full
// record to the API.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:edutrack_mobile/app.dart';
import 'package:edutrack_mobile/core/api.dart';
import 'package:edutrack_mobile/features/admin/data/admin_rules.dart';
import 'package:edutrack_mobile/features/admin/data/admin_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Map<String, dynamic> fixtures = jsonDecode(File('test/fixtures/api.json').readAsStringSync()) as Map<String, dynamic>;

/// Keeps the token in memory instead of the platform's secure storage.
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

/// Answers API requests from the fixtures and records every request.
class FakeApi implements HttpClientAdapter {
  FakeApi(this.role);
  final String role;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final path = options.uri.path.replaceFirst('/api', '') + (options.uri.query.isEmpty ? '' : '?${options.uri.query}');
    Object? body;
    if (options.method == 'GET') {
      body = (fixtures[role] as Map<String, dynamic>)[path];
    } else if (options.method == 'DELETE') {
      body = {'id': path.split('/').last, 'deleted': true};
    } else {
      // Echo the record back, as the API returns the saved document.
      final data = Map<String, dynamic>.from(options.data as Map);
      body = {'id': data['id'] ?? 'new-${requests.length}', ...data};
    }
    if (body == null) return ResponseBody.fromString('{"message":"Not found: $path"}', 404, headers: _json);
    return ResponseBody.fromString(jsonEncode(body), 200, headers: _json);
  }

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  void close({bool force = false}) {}
}

Future<FakeApi> pumpApp(WidgetTester tester, String role) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75; // ~393 x 873 dp, a typical phone
  addTearDown(tester.view.reset);
  final fake = FakeApi(role);
  final dio = Dio(BaseOptions(baseUrl: 'http://test/api'))..httpClientAdapter = fake;
  final api = ApiClient(MemoryTokens('token'), dio: dio);
  await tester.pumpWidget(EduTrackApp(api: api));
  await tester.pumpAndSettle();
  return fake;
}

Future<void> visit(WidgetTester tester, String location) async {
  GoRouter.of(tester.element(find.byType(Navigator).first)).go(location);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: location);
}

/// Disposes the app so its timers (the admin 20 s refresh) stop.
Future<void> unmount(WidgetTester tester) => tester.pumpWidget(const SizedBox());

/// Measures text with the real Roboto and Material Icons fonts from the
/// Flutter SDK (the default test font's square glyphs are about twice as
/// wide, so overflow checks would be meaningless).
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

  testWidgets('student screens render with real data', (tester) async {
    await pumpApp(tester, 'student');
    expect(find.text('Welcome back, Juan!'), findsOneWidget);
    for (final path in [
      '/student/profile',
      '/student/enrollment',
      '/student/grades',
      '/student/schedule',
      '/student/notifications',
      '/student/support',
      '/student/dashboard',
    ]) {
      await visit(tester, path);
    }
    await unmount(tester);
  });

  testWidgets('admin screens render with real data', (tester) async {
    await pumpApp(tester, 'admin');
    expect(find.text('Total Students'), findsOneWidget);
    final expected = {
      '/admin/students': '13 students found',
      '/admin/enrollment': 'Enrollment & COR',
      '/admin/grades': '13 grade records',
      '/admin/schedules': 'Weekly Schedule',
      '/admin/announcements': 'Create Announcement',
      '/admin/helpdesk': 'Support Helpdesk',
      '/admin/settings': 'Academic Settings',
      '/admin': 'Quick Actions',
    };
    for (final MapEntry(key: path, value: text) in expected.entries) {
      await visit(tester, path);
      expect(find.textContaining(text), findsWidgets, reason: path);
    }
    await unmount(tester);
  });

  testWidgets('each role is kept out of the other portal', (tester) async {
    await pumpApp(tester, 'admin');
    await visit(tester, '/student/grades');
    expect(find.text('Total Students'), findsOneWidget);
    await unmount(tester);

    await pumpApp(tester, 'student');
    await visit(tester, '/admin/students');
    expect(find.text('Welcome back, Juan!'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a record opened from a notification link shows its details', (tester) async {
    await pumpApp(tester, 'admin');
    final pending = (fixtures['admin']['/admin/bootstrap']['state']['enrollments'] as List).firstWhere((e) => e['status'] == 'Pending');
    await visit(tester, '/admin/enrollment?record=${pending['id']}');
    expect(find.text('Enrollment Details'), findsOneWidget);
    expect(find.byKey(const Key('enrollment-approve')), findsOneWidget);
    await unmount(tester);
  });

  group('admin changes send the full record', () {
    late FakeApi fake;
    late AdminStore store;

    setUp(() async {
      fake = FakeApi('admin');
      final dio = Dio(BaseOptions(baseUrl: 'http://test/api'))..httpClientAdapter = fake;
      store = AdminStore(ApiClient(MemoryTokens('token'), dio: dio));
      await store.load();
    });

    test('approving an enrollment PUTs every field, then logs the action', () async {
      final pending = store.enrollments.firstWhere((e) => e['status'] == 'Pending' && !hasPrerequisiteConcerns(e));
      await store.save(AdminCollection.enrollments, transitionEnrollment(pending, 'Approved'), action: 'Approved enrollment for ${pending['studentName']}');

      final put = fake.requests.firstWhere((r) => r.method == 'PUT');
      expect(put.path, '/enrollments/${pending['id']}');
      final sent = put.data as Map<String, dynamic>;
      expect(sent.keys, containsAll(pending.keys));
      expect(sent['status'], 'Approved');
      expect(sent['subjects'], pending['subjects']);
      expect(sent['studentName'], pending['studentName']);

      final log = fake.requests.firstWhere((r) => r.method == 'POST' && r.path == '/activity-logs');
      expect((log.data as Map)['action'], 'Approved enrollment for ${pending['studentName']}');
      expect((log.data as Map)['type'], 'enrollment');
    });

    test('settings are saved with every field', () async {
      await store.saveSettings({...store.settings, 'enrollmentOpen': false}, action: 'Updated academic period and system settings');
      final put = fake.requests.firstWhere((r) => r.method == 'PUT' && r.path == '/settings');
      expect(
        (put.data as Map).keys,
        containsAll(['academicYear', 'semester', 'enrollmentOpen', 'gradeEncodingOpen', 'notifyNewEnrollments', 'notifyNewTickets', 'notifySystemActivity']),
      );
    });

    test('a new record is POSTed and appears first', () async {
      final saved = await store.save(AdminCollection.announcements, {
        'title': 'Test',
        'category': 'General',
        'message': 'Hello',
        'targetAudience': 'All Students',
        'targetValue': 'All Students',
        'status': 'Draft',
        'author': 'Admin',
        'dateCreated': '2026-10-15',
        'datePublished': null,
      }, action: 'Created announcement: Test');
      expect(fake.requests.any((r) => r.method == 'POST' && r.path == '/announcements'), isTrue);
      expect(store.announcements.first['id'], saved['id']);
    });
  });

  group('admin rules match the web', () {
    test('grades', () {
      expect(parseGrade(''), isNull);
      expect(parseGrade('1.25'), 1.25);
      expect(() => parseGrade('1.255'), throwsFormatException);
      expect(() => parseGrade('5.5'), throwsFormatException);
      expect(calculateRemark(3), 'Passed');
      expect(calculateRemark(3.25), 'Failed');
      expect(calculateRemark(null), 'Incomplete');
    });

    test('schedules', () {
      final base = {
        'id': 'a',
        'subjectCode': 'IT101',
        'section': 'BSIT 1A',
        'instructor': 'Prof. A',
        'day': 'Monday',
        'room': 'Rm 1',
        'startTime': '08:00',
        'endTime': '09:00',
      };
      expect(() => validateSchedule({...base, 'startTime': '06:00'}, []), throwsFormatException);
      expect(() => validateSchedule({...base, 'endTime': '07:30'}, []), throwsFormatException);
      final clash = {...base, 'id': 'b', 'section': 'BSIT 2A', 'instructor': 'Prof. B'};
      expect(scheduleConflicts(clash, [base]), ['room']);
      validateSchedule(base, [base]);
    });

    test('enrollment review', () {
      final e = {
        'status': 'Pending',
        'hasPrerequisiteConcerns': true,
        'subjects': [
          {'hasPrerequisiteMet': false},
        ],
      };
      expect(() => transitionEnrollment(e, 'Approved'), throwsFormatException);
      expect(transitionEnrollment(e, 'Approved', override: true)['prerequisiteOverride'], isTrue);
      expect(() => transitionEnrollment(e, 'Rejected'), throwsFormatException);
      expect(transitionEnrollment(e, 'Rejected', remarks: ' Missing units ')['remarks'], 'Missing units');
    });

    test('CSV export neutralises formulas', () {
      final csv = studentCsv([
        {
          'studentId': '=1+1',
          'fullName': 'A "B"',
          'email': 'a@b.co',
          'program': 'BSIT',
          'yearLevel': '1st Year',
          'section': 'BSIT 1A',
          'academicStatus': 'Active',
        },
      ]);
      expect(csv, contains('"\'=1+1"'));
      expect(csv, contains('"A ""B"""'));
    });
  });
}
