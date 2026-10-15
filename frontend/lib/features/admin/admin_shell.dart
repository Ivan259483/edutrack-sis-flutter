import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../student/profile_page.dart' show ChangePasswordCard;
import 'admin_widgets.dart';
import 'data/admin_rules.dart';
import 'data/admin_store.dart';

/// Admin navigation (admin/src/components/layout/Sidebar.tsx).
const adminNav = [
  (label: 'Dashboard', path: '/admin', icon: Icons.dashboard_outlined),
  (label: 'Student Directory', path: '/admin/students', icon: Icons.people_outline),
  (label: 'Enrollment & COR', path: '/admin/enrollment', icon: Icons.assignment_turned_in_outlined),
  (label: 'Academic Records', path: '/admin/grades', icon: Icons.school_outlined),
  (label: 'Class Schedules', path: '/admin/schedules', icon: Icons.calendar_month_outlined),
  (label: 'Announcements', path: '/admin/announcements', icon: Icons.campaign_outlined),
  (label: 'Support Helpdesk', path: '/admin/helpdesk', icon: Icons.support_outlined),
  (label: 'Settings', path: '/admin/settings', icon: Icons.settings_outlined),
];

bool _isActive(String location, String path) => path == '/admin' ? location == '/admin' : location.startsWith(path);

/// Turns a web admin link ("/enrollment?record=x") into an app route.
String adminRoute(String? href) {
  if (href == null || href.isEmpty || href == '/') return '/admin';
  return '/admin$href';
}

/// Sidebar + header around every admin screen, a drawer on phones
/// (admin/src/components/layout/AdminLayout.tsx). Loads the admin data once
/// and refreshes it every 20 seconds and when the app returns to the
/// foreground, like the web portal.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AdminStore>().ensureLoaded());
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => context.read<AdminStore>().refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) context.read<AdminStore>().refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final wide = MediaQuery.sizeOf(context).width >= adminWideBreakpoint;
    final Widget content;
    if (!store.loaded) {
      content = store.error != null
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [LoadError(message: store.error!, onRetry: store.load)],
              ),
            )
          : const Center(child: Loading(label: 'Loading admin data…'));
    } else {
      content = widget.child;
    }
    final body = Column(
      children: [
        _AdminHeader(showMenu: !wide),
        Expanded(child: content),
      ],
    );
    return Theme(
      data: adminTheme,
      child: Scaffold(
        backgroundColor: AppColors.adminBg,
        drawer: wide
            ? null
            : Drawer(
                width: 264,
                backgroundColor: Colors.white,
                child: AdminSidebar(location: widget.location, inDrawer: true),
              ),
        body: SafeArea(
          bottom: false,
          child: wide
              ? Row(
                  children: [
                    AdminSidebar(location: widget.location),
                    Expanded(child: body),
                  ],
                )
              : body,
        ),
      ),
    );
  }
}

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({super.key, required this.location, this.inDrawer = false});
  final String location;
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AdminStore>().settings;
    return Container(
      width: 264,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.adminBorder)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            Container(
              height: 64,
              padding: const EdgeInsets.only(left: 24, right: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.adminBorder)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: AppColors.adminPrimary, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.school, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'University Admin',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.adminFg),
                        ),
                        Text('Portal', style: TextStyle(color: AppColors.adminMutedFg, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (inDrawer) IconButton(tooltip: 'Close navigation menu', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                children: [
                  for (final item in adminNav)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Material(
                        color: _isActive(location, item.path) ? AppColors.adminPrimary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            if (inDrawer) Navigator.of(context).pop();
                            context.go(item.path);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Icon(item.icon, size: 20, color: _isActive(location, item.path) ? Colors.white : AppColors.adminMutedFg),
                                const SizedBox(width: 12),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: _isActive(location, item.path) ? Colors.white : AppColors.adminMutedFg,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.adminBorder)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AY ${settings['academicYear'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.adminMutedFg)),
                  Text(
                    '${settings['semester'] ?? ''}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.adminFg),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Menu button, global search, notifications and the profile menu
/// (admin/src/components/layout/Header.tsx).
class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.showMenu});
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final user = context.watch<Session>().user;
    final unread = store.notifications.where((n) => n['read'] != true).length;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.adminBorder)),
      ),
      child: Row(
        children: [
          if (showMenu) IconButton(tooltip: 'Open navigation menu', icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(context).openDrawer()),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: store.loaded ? () => _openSearch(context) : null,
              child: Container(
                height: 40,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: AppColors.adminMuted, borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  children: [
                    Icon(Icons.search, size: 18, color: AppColors.adminMutedFg),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Search the Admin Portal…',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.adminMutedFg, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: store.loaded ? () => _openNotifications(context) : null,
            icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_none)),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account',
            offset: const Offset(0, 48),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  _openProfile(context);
                case 'settings':
                  context.go('/admin/settings');
                case 'logout':
                  context.read<Session>().logout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.adminFg),
                    ),
                    Text(user?.email ?? '', style: const TextStyle(fontSize: 12, color: AppColors.adminMutedFg)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'profile',
                child: ListTile(leading: Icon(Icons.person_outline), title: Text('Profile'), contentPadding: EdgeInsets.zero),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(leading: Icon(Icons.settings_outlined), title: Text('Settings'), contentPadding: EdgeInsets.zero),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: AppColors.adminDestructive),
                  title: Text('Sign out', style: TextStyle(color: AppColors.adminDestructive)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: InitialsAvatar(user?.name ?? 'Admin', radius: 16, text: user == null ? 'AD' : null),
            ),
          ),
        ],
      ),
    );
  }

  void _openNotifications(BuildContext context) {
    showSheetDialog<void>(context, title: 'Notifications', builder: (_) => const _NotificationList());
  }

  void _openProfile(BuildContext context) {
    final user = context.read<Session>().user;
    showSheetDialog<void>(
      context,
      title: 'Admin Profile',
      builder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Signed in to the EduTrack backend.', style: TextStyle(color: AppColors.adminMutedFg, fontSize: 13)),
          const SizedBox(height: 12),
          InfoGrid([('Name', user?.name ?? ''), ('Email', user?.email ?? ''), ('Role', 'Administrator')]),
          const SizedBox(height: 20),
          const Text('Change password', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const ChangePasswordCard(dense: true),
        ],
      ),
    );
  }

  void _openSearch(BuildContext context) {
    showSheetDialog<void>(
      context,
      title: 'Search Admin Portal',
      builder: (_) => _SearchPanel(store: context.read<AdminStore>()),
    );
  }
}

class _NotificationList extends StatelessWidget {
  const _NotificationList();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final list = store.notifications;
    final unread = list.where((n) => n['read'] != true).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (unread > 0)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => runChange(context, () => store.markRead(list)), child: const Text('Mark all read')),
          ),
        if (list.isEmpty) const Empty('No notifications'),
        for (final n in list)
          InkWell(
            onTap: () async {
              final saved = await runChange(context, () => store.markRead([n]));
              if (saved && context.mounted) {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.go(adminRoute(n['href'] as String?));
              }
            },
            child: Container(
              color: n['read'] == true ? null : const Color(0x80EFF6FF),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6, right: 10),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: n['read'] == true ? Colors.transparent : AppColors.adminPrimary, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${n['title']}', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                        Text('${n['description']}', style: const TextStyle(color: AppColors.adminMutedFg, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(formatDate(n['timestamp'] as String?), style: const TextStyle(color: AppColors.adminMutedFg, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Global search over students, enrollments, tickets and announcements
/// (admin/src/lib/search.ts).
class _SearchPanel extends StatefulWidget {
  const _SearchPanel({required this.store});
  final AdminStore store;

  @override
  State<_SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<_SearchPanel> {
  String _query = '';

  List<({String label, String detail, String href})> get _results {
    final q = normalize(_query);
    if (q.isEmpty) return const [];
    final s = widget.store;
    String record(String page, Object? id) => '$page?record=${Uri.encodeComponent('$id')}';
    final all = [
      for (final r in s.students)
        (
          label: '${r['fullName']}',
          detail: 'Student · ${r['studentId']}',
          search: '${r['fullName']} ${r['studentId']} ${r['email']}',
          href: record('/students', r['id']),
        ),
      for (final r in s.enrollments)
        (
          label: '${r['studentName']}',
          detail: 'Enrollment · ${r['status']}',
          search: '${r['studentName']} ${r['studentNumber']}',
          href: record('/enrollment', r['id']),
        ),
      for (final r in s.tickets)
        (
          label: '${r['subject']}',
          detail: 'Ticket · ${r['ticketNumber']}',
          search: '${r['subject']} ${r['studentName']} ${r['ticketNumber']}',
          href: record('/helpdesk', r['id']),
        ),
      for (final r in s.announcements)
        (label: '${r['title']}', detail: 'Announcement · ${r['status']}', search: '${r['title']} ${r['message']}', href: record('/announcements', r['id'])),
    ];
    return [for (final r in all.where((r) => normalize(r.search).contains(q)).take(30)) (label: r.label, detail: r.detail, href: r.href)];
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Find students, enrollments, tickets, and announcements.', style: TextStyle(color: AppColors.adminMutedFg, fontSize: 13)),
        const SizedBox(height: 12),
        TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Search by name, ID, subject, or title…', prefixIcon: Icon(Icons.search, size: 18)),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 8),
        for (final r in results)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(r.label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            subtitle: Text(r.detail, style: const TextStyle(fontSize: 12)),
            onTap: () {
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              router.go(adminRoute(r.href));
            },
          ),
        if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              _query.trim().isNotEmpty ? 'No matching records. Try a different name, ID, or keyword.' : 'Type to search across Admin records.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.adminMutedFg, fontSize: 13),
            ),
          ),
      ],
    );
  }
}
