import 'package:go_router/go_router.dart';

import 'dashboard_page.dart';
import 'enrollment_page.dart';
import 'grades_page.dart';
import 'notifications_page.dart';
import 'profile_page.dart';
import 'schedule_page.dart';
import 'student_shell.dart';
import 'support_page.dart';

/// /student/... screens inside the student shell (frontend/src/App.jsx).
ShellRoute studentRoutes() => ShellRoute(
      builder: (context, state, child) => StudentShell(location: state.matchedLocation, child: child),
      routes: [
        GoRoute(path: '/student', redirect: (context, state) => '/student/dashboard'),
        GoRoute(path: '/student/dashboard', builder: (context, state) => const StudentDashboardPage()),
        GoRoute(
          path: '/student/profile',
          builder: (context, state) => StudentProfilePage(section: state.uri.queryParameters['section']),
        ),
        GoRoute(
          path: '/student/enrollment',
          builder: (context, state) => StudentEnrollmentPage(search: state.uri.queryParameters['search'] ?? ''),
        ),
        GoRoute(path: '/student/grades', builder: (context, state) => const StudentGradesPage()),
        GoRoute(path: '/student/schedule', builder: (context, state) => const StudentSchedulePage()),
        GoRoute(path: '/student/notifications', builder: (context, state) => const StudentNotificationsPage()),
        GoRoute(path: '/student/support', builder: (context, state) => const StudentSupportPage()),
      ],
    );
