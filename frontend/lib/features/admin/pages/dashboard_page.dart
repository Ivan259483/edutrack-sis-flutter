import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../widgets/common.dart';
import '../admin_widgets.dart';
import '../data/admin_store.dart';

/// Admin overview: KPIs, charts, quick actions and recent activity
/// (admin/src/pages/DashboardPage.tsx).
class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  static const _amber = Color(0xFFF5A00B); // hsl(38, 92%, 50%)
  static const _green = Color(0xFF22C35D); // hsl(142, 71%, 45%)
  static const _red = Color(0xFFEF4444); // hsl(0, 84%, 60%)

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final settings = store.settings;
    int count(List<Map<String, dynamic>> list, String field, String value) => list.where((r) => r[field] == value).length;

    final kpis = [
      (
        label: 'Total Students',
        value: '${store.students.length}',
        sub: null,
        change: null,
        icon: Icons.people_outline,
        color: AppColors.blue600,
        bg: AppColors.blue50,
      ),
      (
        label: 'Pending Enrollments',
        value: '${count(store.enrollments, 'status', 'Pending')}',
        sub: null,
        change: null,
        icon: Icons.assignment_turned_in_outlined,
        color: AppColors.amber600,
        bg: AppColors.amber50,
      ),
      (
        label: 'Published Grades',
        value: '${count(store.grades, 'publishStatus', 'Published')}',
        sub: null,
        change: null,
        icon: Icons.school_outlined,
        color: AppColors.green600,
        bg: AppColors.green50,
      ),
      (
        label: 'Open Support Tickets',
        value: '${count(store.tickets, 'status', 'Open')}',
        sub: null,
        change: null,
        icon: Icons.support_outlined,
        color: const Color(0xFFDC2626),
        bg: const Color(0xFFFEF2F2),
      ),
      (
        label: 'Active Announcements',
        value: '${count(store.announcements, 'status', 'Published')}',
        sub: null,
        change: null,
        icon: Icons.campaign_outlined,
        color: AppColors.blue600,
        bg: AppColors.blue50,
      ),
      (
        label: 'Current Semester',
        value: '${settings['academicYear'] ?? ''}',
        sub: '${settings['semester'] ?? ''}',
        change: settings['enrollmentOpen'] == true ? 'Enrollment open' : 'Enrollment closed',
        icon: Icons.calendar_month_outlined,
        color: AppColors.blue600,
        bg: AppColors.blue50,
      ),
    ];

    final enrollmentData = [
      ('Pending', count(store.enrollments, 'status', 'Pending'), _amber),
      ('Approved', count(store.enrollments, 'status', 'Approved'), _green),
      ('Rejected', count(store.enrollments, 'status', 'Rejected'), _red),
    ];
    final programData = [
      for (final p in ['BSIT', 'BSBA', 'BSEd']) (p, count(store.students, 'program', p)),
    ];
    final ticketData = [
      ('Open', count(store.tickets, 'status', 'Open'), AppColors.adminPrimary),
      ('In Progress', count(store.tickets, 'status', 'In Progress'), _amber),
      ('Resolved', count(store.tickets, 'status', 'Resolved'), _green),
    ];

    int byDesc(Map<String, dynamic> a, Map<String, dynamic> b, String field) => '${b[field] ?? ''}'.compareTo('${a[field] ?? ''}');
    final recentEnrollments = ([...store.enrollments]..sort((a, b) => byDesc(a, b, 'submittedDate'))).take(4).toList();
    final recentTickets = ([...store.tickets]..sort((a, b) => byDesc(a, b, 'dateUpdated'))).take(4).toList();
    final recentAnnouncements = (store.announcements.where((a) => a['status'] == 'Published').toList()..sort((a, b) => byDesc(a, b, 'datePublished')))
        .take(3)
        .toList();
    final recentActivity = ([...store.activityLogs]..sort((a, b) => byDesc(a, b, 'timestamp'))).take(6).toList();

    Widget viewAll(String path) => TextButton.icon(
      onPressed: () => context.go(path),
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.arrow_forward, size: 16),
      label: const Text('View all'),
    );

    return AdminPage(
      onRefresh: store.refresh,
      children: [
        const AdminPageHeader(title: 'Dashboard', description: 'Overview of university administration activities'),
        ResponsiveGrid(
          minItemWidth: 160,
          children: [
            for (final kpi in kpis)
              AdminCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: kpi.bg, borderRadius: BorderRadius.circular(8)),
                      child: Icon(kpi.icon, color: kpi.color, size: 20),
                    ),
                    const SizedBox(height: 12),
                    Text(kpi.value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    if (kpi.sub != null) Text(kpi.sub!, style: const TextStyle(fontSize: 12, color: AppColors.adminMutedFg)),
                    Text(kpi.label, style: const TextStyle(fontSize: 12, color: AppColors.adminMutedFg)),
                    if (kpi.change != null)
                      Text(
                        kpi.change!,
                        style: const TextStyle(fontSize: 11, color: AppColors.green600, fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          minItemWidth: 300,
          spacing: 16,
          children: [
            _ChartCard(
              title: 'Enrollment Status',
              description: 'All stored enrollment requests',
              empty: store.enrollments.isEmpty ? 'No enrollment requests yet.' : null,
              chart: _Donut(enrollmentData),
              legend: enrollmentData,
            ),
            _ChartCard(
              title: 'Students by Program',
              description: 'Enrollment distribution',
              empty: store.students.isEmpty ? 'No students yet.' : null,
              chart: _Bars(programData),
            ),
            _ChartCard(
              title: 'Ticket Status Overview',
              description: 'Support helpdesk summary',
              empty: store.tickets.isEmpty ? 'No support tickets yet.' : null,
              chart: _Donut(ticketData),
              legend: ticketData,
            ),
          ],
        ),
        const SizedBox(height: 16),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CardHeading('Quick Actions'),
              ResponsiveGrid(
                minItemWidth: 150,
                spacing: 8,
                children: [
                  for (final (label, icon, path) in [
                    ('Add Student', Icons.add, '/admin/students?action=add'),
                    ('Review Enrollments', Icons.assignment_turned_in_outlined, '/admin/enrollment'),
                    ('New Announcement', Icons.campaign_outlined, '/admin/announcements?action=create'),
                    ('Encode Grades', Icons.school_outlined, '/admin/grades?action=encode'),
                  ])
                    OutlinedButton.icon(
                      onPressed: () => context.go(path),
                      icon: Icon(icon, size: 18),
                      label: Text(label, textAlign: TextAlign.center),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          minItemWidth: 340,
          spacing: 16,
          children: [
            AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CardHeading('Recent Enrollment Requests', description: 'Latest enrollment submissions', trailing: viewAll('/admin/enrollment')),
                  if (recentEnrollments.isEmpty) const Empty('No enrollment requests yet.'),
                  for (final e in recentEnrollments)
                    _PersonRow(
                      name: '${e['studentName']}',
                      title: '${e['studentName']}',
                      detail: '${e['program']} · ${e['yearLevel']} · ${num0(e['totalUnits'] as num? ?? 0)} units',
                      status: '${e['status']}',
                    ),
                ],
              ),
            ),
            AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CardHeading('Recent Support Tickets', description: 'Latest student concerns', trailing: viewAll('/admin/helpdesk')),
                  if (recentTickets.isEmpty) const Empty('No support tickets yet.'),
                  for (final t in recentTickets)
                    _PersonRow(
                      name: '${t['studentName']}',
                      title: '${t['subject']}',
                      detail: '${t['studentName']} · ${t['category']}',
                      status: '${t['status']}',
                    ),
                ],
              ),
            ),
            AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CardHeading('Recent Announcements', description: 'Latest published posts', trailing: viewAll('/admin/announcements')),
                  if (recentAnnouncements.isEmpty) const Empty('No published announcements yet.'),
                  for (final a in recentAnnouncements)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.adminBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${a['title']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                ),
                              ),
                              StatusBadge('${a['status']}'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${a['message']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.adminMutedFg),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.campaign_outlined, size: 14, color: AppColors.adminMutedFg),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${a['category']} · ${a['targetValue']} · ${formatDate((a['datePublished'] ?? a['dateCreated']) as String?)}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.adminMutedFg),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CardHeading('Recent Activity', description: 'System action log'),
                  if (recentActivity.isEmpty) const Empty('No activity recorded yet.'),
                  for (final log in recentActivity) _ActivityRow(log),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.name, required this.title, required this.detail, required this.status});
  final String name;
  final String title;
  final String detail;
  final String status;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.adminBorder),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        InitialsAvatar(name, radius: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.adminMutedFg),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        StatusBadge(status, dot: true),
      ],
    ),
  );
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow(this.log);
  final Map<String, dynamic> log;

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg) = switch (log['type']) {
      'grade' => (Icons.school_outlined, AppColors.green600, AppColors.green50),
      'ticket' => (Icons.support_outlined, AppColors.amber600, AppColors.amber50),
      'enrollment' => (Icons.assignment_turned_in_outlined, AppColors.blue600, AppColors.blue50),
      'announcement' => (Icons.campaign_outlined, AppColors.blue600, AppColors.blue50),
      'student' => (Icons.people_outline, AppColors.blue600, AppColors.blue50),
      'schedule' => (Icons.calendar_month_outlined, AppColors.blue600, AppColors.blue50),
      _ => (Icons.trending_up, AppColors.blue600, AppColors.blue50),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${log['action']}', style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 12, color: AppColors.adminMutedFg),
                    const SizedBox(width: 4),
                    Text('${log['actor']} · ${formatDate(log['timestamp'] as String?)}', style: const TextStyle(fontSize: 11, color: AppColors.adminMutedFg)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.description, required this.chart, this.empty, this.legend});
  final String title;
  final String description;
  final Widget chart;
  final String? empty;
  final List<(String, int, Color)>? legend;

  @override
  Widget build(BuildContext context) => AdminCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardHeading(title, description: description),
        if (empty != null)
          Text(
            empty!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.adminMutedFg),
          ),
        SizedBox(height: 180, child: chart),
        if (legend != null) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 4,
            children: [
              for (final (name, value, color) in legend!)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('$name: $value', style: const TextStyle(fontSize: 12, color: AppColors.adminMutedFg)),
                  ],
                ),
            ],
          ),
        ],
      ],
    ),
  );
}

/// Donut chart (the web's Recharts PieChart, inner radius 50, outer 80).
class _Donut extends StatelessWidget {
  const _Donut(this.data);
  final List<(String, int, Color)> data;

  @override
  Widget build(BuildContext context) => Semantics(
    label: data.map((d) => '${d.$1}: ${d.$2}').join(', '),
    child: CustomPaint(painter: _DonutPainter(data), size: Size.infinite),
  );
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.data);
  final List<(String, int, Color)> data;

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.fold<int>(0, (sum, d) => sum + d.$2);
    if (total == 0) return;
    final center = size.center(Offset.zero);
    final outer = math.min(80.0, size.shortestSide / 2);
    final stroke = outer * 30 / 80;
    final rect = Rect.fromCircle(center: center, radius: outer - stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const gap = 0.035; // paddingAngle 2°
    final shown = data.where((d) => d.$2 > 0).toList();
    var start = -math.pi / 2;
    for (final (_, value, color) in shown) {
      final sweep = value / total * 2 * math.pi;
      canvas.drawArc(rect, start + (shown.length > 1 ? gap / 2 : 0), sweep - (shown.length > 1 ? gap : 0), false, paint..color = color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.data.toString() != data.toString();
}

/// Bar chart (the web's Recharts BarChart).
class _Bars extends StatelessWidget {
  const _Bars(this.data);
  final List<(String, int)> data;

  @override
  Widget build(BuildContext context) {
    final maxValue = data.fold<int>(0, (m, d) => math.max(m, d.$2));
    final top = math.max(1, maxValue);
    return Semantics(
      label: data.map((d) => '${d.$1}: ${d.$2}').join(', '),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (name, value) in data)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('$value', style: const TextStyle(fontSize: 12, color: AppColors.adminMutedFg)),
                    const SizedBox(height: 4),
                    Flexible(
                      child: FractionallySizedBox(
                        heightFactor: value / top,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: AppColors.adminPrimary,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(name, style: const TextStyle(fontSize: 12, color: AppColors.adminMutedFg)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
