import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_routes.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/auth/simple_pages.dart';
import '../features/student/student_routes.dart';
import 'session.dart';

const _public = {'/login', '/register'};

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

GoRouter buildRouter(Session session) => GoRouter(
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
  late final GoRouter _router = buildRouter(widget.session);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _router);
}
