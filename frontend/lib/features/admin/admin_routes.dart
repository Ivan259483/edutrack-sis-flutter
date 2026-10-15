import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';

/// /admin screens (built after the student side).
GoRoute adminRoutes() => GoRoute(
  path: '/admin',
  builder: (context, state) => Scaffold(
    body: Center(
      child: FilledButton(onPressed: () => context.read<Session>().logout(), child: const Text('Sign out')),
    ),
  ),
);
