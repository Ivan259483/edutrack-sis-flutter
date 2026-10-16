import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_routes.dart';
import '../features/auth/forgot_password_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/auth/simple_pages.dart';
import '../features/student/student_routes.dart';
import 'session.dart';

const _public = {'/login', '/register', '/forgot-password'};

/// Home screen for the signed-in account's role.
String homeFor(AppUser user) => user.isAdmin ? '/admin' : '/student/dashboard';

/// Route guard (the web's ProtectedRoute / RequireAdmin): signed-out users go
/// to the login screen, and each role only reaches its own screens.
String? guard(Session session, String location) {
  if (session.status == SessionStatus.loading) return location == '/loading' ? null : '/loading';
  final user = session.user;
  if (session.status == SessionStatus.signedOut || user == null) {
    return _public.contains(location) ? null : '/login';
  }
  final home = homeFor(user);
  if (_public.contains(location) || location == '/loading' || location == '/') return home;
  if (location.startsWith('/admin') && !user.isAdmin) return home;
  if (location.startsWith('/student') && user.isAdmin) return home;
  return null;
}

GoRouter buildRouter(Session session, {GlobalKey<NavigatorState>? navigatorKey}) => GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/loading',
  refreshListenable: session,
  redirect: (context, state) => guard(session, state.matchedLocation),
  errorBuilder: (context, state) => NotFoundPage(path: state.uri.path),
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/login'),
    GoRoute(path: '/loading', builder: (context, state) => const SplashPage()),
    GoRoute(
      path: '/login',
      builder: (context, state) => LoginPage(key: ValueKey(state.uri.queryParameters['role']), initialRole: state.uri.queryParameters['role'] ?? 'student'),
    ),
    GoRoute(path: '/register', builder: (context, state) => const RegisterPage()),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => ForgotPasswordPage(initialRole: state.uri.queryParameters['role'] ?? 'student'),
    ),
    studentRoutes(),
    adminRoutes(),
  ],
);

/// Hosts the router and rebuilds it only when the session object changes.
class AppRouterScope extends StatefulWidget {
  const AppRouterScope({super.key, required this.session, required this.builder});
  final Session session;
  final Widget Function(BuildContext, GoRouter) builder;

  @override
  State<AppRouterScope> createState() => _AppRouterScopeState();
}

class _AppRouterScopeState extends State<AppRouterScope> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final GoRouter _router = buildRouter(widget.session, navigatorKey: _navigatorKey);
  late SessionStatus _status = widget.session.status;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_sessionChanged);
  }

  /// Signing out (or the server ending the session) closes any open dialog or
  /// sheet first, so the login screen isn't left underneath one.
  void _sessionChanged() {
    final next = widget.session.status;
    if (_status == SessionStatus.signedIn && next == SessionStatus.signedOut) {
      _navigatorKey.currentState?.popUntil((route) => route is! PopupRoute);
    }
    _status = next;
  }

  @override
  void dispose() {
    widget.session.removeListener(_sessionChanged);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _router);
}
