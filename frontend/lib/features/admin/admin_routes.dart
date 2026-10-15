import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'admin_shell.dart';
import 'pages/announcements_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/enrollment_page.dart';
import 'pages/grades_page.dart';
import 'pages/helpdesk_page.dart';
import 'pages/schedules_page.dart';
import 'pages/settings_page.dart';
import 'pages/students_page.dart';

/// /admin/... screens inside the admin shell (admin/src/App.tsx). Like the
/// web, `?record=<id>` opens a record and `?action=` starts an action
/// (links from notifications, global search and dashboard quick actions).
ShellRoute adminRoutes() => ShellRoute(
  builder: (context, state, child) => AdminShell(location: state.matchedLocation, child: child),
  routes: [
    GoRoute(path: '/admin', builder: (context, state) => const AdminDashboardPage()),
    GoRoute(
      path: '/admin/students',
      builder: (context, state) =>
          StudentDirectoryPage(key: ValueKey(state.uri.toString()), recordId: state.uri.queryParameters['record'], action: state.uri.queryParameters['action']),
    ),
    GoRoute(
      path: '/admin/enrollment',
      builder: (context, state) => AdminEnrollmentPage(key: ValueKey(state.uri.toString()), recordId: state.uri.queryParameters['record']),
    ),
    GoRoute(
      path: '/admin/grades',
      builder: (context, state) => AcademicRecordsPage(key: ValueKey(state.uri.toString()), action: state.uri.queryParameters['action']),
    ),
    GoRoute(path: '/admin/schedules', builder: (context, state) => const ClassSchedulesPage()),
    GoRoute(
      path: '/admin/announcements',
      builder: (context, state) =>
          AnnouncementsPage(key: ValueKey(state.uri.toString()), recordId: state.uri.queryParameters['record'], action: state.uri.queryParameters['action']),
    ),
    GoRoute(
      path: '/admin/helpdesk',
      builder: (context, state) => SupportHelpdeskPage(key: ValueKey(state.uri.toString()), recordId: state.uri.queryParameters['record']),
    ),
    GoRoute(path: '/admin/settings', builder: (context, state) => const AdminSettingsPage()),
  ],
);
