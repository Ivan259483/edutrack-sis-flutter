import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';
import '../../core/theme.dart';

/// Student navigation (frontend/src/components/layout/Sidebar.jsx).
const studentNav = [
  (label: 'Dashboard', path: '/student/dashboard', icon: Icons.dashboard),
  (label: 'My Profile', path: '/student/profile', icon: Icons.person),
  (label: 'My Enrollment', path: '/student/enrollment', icon: Icons.assignment),
  (label: 'My Grades', path: '/student/grades', icon: Icons.school),
  (label: 'My Schedule', path: '/student/schedule', icon: Icons.calendar_month),
  (label: 'Notifications', path: '/student/notifications', icon: Icons.notifications),
  (label: 'Help and Support', path: '/student/support', icon: Icons.help),
];

/// Bootstrap "md": the sidebar is always visible from this width up.
const studentWideBreakpoint = 768.0;

/// Sidebar + top bar around every student screen; a drawer on phones
/// (frontend/src/components/layout/AppLayout.jsx).
class StudentShell extends StatelessWidget {
  const StudentShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  String get _title {
    for (final item in studentNav) {
      if (location.startsWith(item.path)) return item.label;
    }
    return 'EduTrack';
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= studentWideBreakpoint;
    final body = Column(
      children: [
        _StudentTopBar(title: _title, showMenu: !wide),
        Expanded(child: child),
      ],
    );
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      drawer: wide
          ? null
          : Drawer(
              width: 260,
              backgroundColor: AppColors.slate900,
              child: StudentSidebar(location: location, inDrawer: true),
            ),
      body: SafeArea(
        bottom: false,
        child: wide
            ? Row(
                children: [
                  StudentSidebar(location: location),
                  Expanded(child: body),
                ],
              )
            : body,
      ),
    );
  }
}

class StudentSidebar extends StatelessWidget {
  const StudentSidebar({super.key, required this.location, this.inDrawer = false});
  final String location;
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final user = session.user;
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppColors.slate900,
        border: Border(right: BorderSide(color: Color(0x14FFFFFF))),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            // Brand header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 8, 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0x406C757D))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.school, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EduTrack',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text('Student Portal', style: TextStyle(color: AppColors.slate400, fontSize: 11)),
                      ],
                    ),
                  ),
                  if (inDrawer)
                    IconButton(
                      tooltip: 'Close navigation menu',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                ],
              ),
            ),
            // Navigation menu
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (final item in studentNav)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _NavTile(
                        label: item.label,
                        icon: item.icon,
                        selected: location.startsWith(item.path),
                        onTap: () {
                          if (inDrawer) Navigator.of(context).pop();
                          context.go(item.path);
                        },
                      ),
                    ),
                ],
              ),
            ),
            // User card & logout
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0x406C757D))),
              ),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.slate800, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.25),
                      child: Text(
                        (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : 'U',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'User',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(user?.studentId ?? 'Student', style: const TextStyle(color: AppColors.slate400, fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Log out',
                      onPressed: () => session.logout(),
                      icon: const Icon(Icons.logout, color: AppColors.danger, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.primary : Colors.transparent,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : AppColors.slate400),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(color: selected ? Colors.white : AppColors.slate400, fontWeight: selected ? FontWeight.w600 : FontWeight.normal, fontSize: 14),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Top bar: menu button (phones), breadcrumb title, subject search,
/// notifications and the account menu (frontend/src/components/layout/Navbar.jsx).
class _StudentTopBar extends StatelessWidget {
  const _StudentTopBar({required this.title, required this.showMenu});
  final String title;
  final bool showMenu;

  Future<void> _search(BuildContext context) async {
    final controller = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search subjects'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search subjects...'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Search')),
        ],
      ),
    );
    if (query != null && query.trim().isNotEmpty && context.mounted) {
      context.go(Uri(path: '/student/enrollment', queryParameters: {'search': query.trim()}).toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final user = session.user;
    final initials = (user?.name ?? '?').split(' ').where((n) => n.isNotEmpty).map((n) => n[0]).take(2).join();
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
        boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          if (showMenu)
            IconButton(tooltip: 'Open navigation menu', icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(context).openDrawer())
          else
            const SizedBox(width: 12),
          if (MediaQuery.sizeOf(context).width >= 576) ...[
            const Text('EduTrack', style: TextStyle(color: AppColors.muted, fontSize: 13)),
            const Text('  /  ', style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ],
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          IconButton(
            tooltip: 'Search subjects',
            icon: const Icon(Icons.search, color: AppColors.muted),
            onPressed: () => _search(context),
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none, color: AppColors.muted),
            onPressed: () => context.go('/student/notifications'),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account menu',
            offset: const Offset(0, 48),
            onSelected: (value) {
              if (value == 'logout') {
                session.logout();
              } else {
                context.go(value);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.dark, fontSize: 13),
                    ),
                    Text(user?.email ?? '', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: '/student/profile', child: _MenuRow(Icons.person, 'My Profile')),
              const PopupMenuItem(value: '/student/profile?section=security', child: _MenuRow(Icons.settings, 'Settings')),
              const PopupMenuItem(value: '/student/support', child: _MenuRow(Icons.help, 'Help & Support')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: _MenuRow(Icons.logout, 'Logout', color: AppColors.danger),
              ),
            ],
            child: Container(
              margin: const EdgeInsets.only(right: 8, left: 4),
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderLight),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      initials,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more, size: 16, color: AppColors.muted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label, {this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: color ?? AppColors.muted),
      const SizedBox(width: 10),
      Text(
        label,
        style: TextStyle(color: color ?? AppColors.dark, fontSize: 14, fontWeight: color != null ? FontWeight.w600 : null),
      ),
    ],
  );
}

/// Scrollable page body with pull-to-refresh and the web's padding.
class StudentPage extends StatelessWidget {
  const StudentPage({super.key, required this.children, this.onRefresh, this.dark = false, this.controller});
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final bool dark;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.sizeOf(context).width >= studentWideBreakpoint ? 24.0 : 12.0;
    // Built in full (not lazily) so a section further down can be scrolled into view.
    final list = SingleChildScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(padding, padding, padding, padding + MediaQuery.paddingOf(context).bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
    return Container(
      color: dark ? AppColors.slate900 : AppColors.pageBg,
      child: onRefresh == null ? list : RefreshIndicator(onRefresh: onRefresh!, child: list),
    );
  }
}
