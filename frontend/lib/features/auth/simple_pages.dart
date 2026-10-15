import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import 'auth_card.dart';

/// Unknown route (frontend/src/pages/NotFoundPage.jsx).
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<Session>().user;
    final home = user == null ? '/login' : (user.isAdmin ? '/admin' : '/student/dashboard');
    return AuthCard(
      maxWidth: 440,
      child: Column(
        children: [
          const AuthIcon(Icons.explore),
          const SizedBox(height: 14),
          const Text(
            'Error 404',
            style: TextStyle(color: AppColors.slate400, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text('Page not found', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: const TextStyle(color: AppColors.slate400, fontSize: 13),
              children: [
                const TextSpan(text: 'There is no page at '),
                TextSpan(
                  text: path,
                  style: const TextStyle(color: AppColors.info, fontFamily: 'monospace'),
                ),
                const TextSpan(text: '.'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () => context.go(home),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: Text(user == null ? 'Back to Login' : 'Back to Dashboard'),
          ),
        ],
      ),
    );
  }
}

/// Shown while a remembered session is checked with the server.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: AppColors.slate900,
    body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
  );
}
