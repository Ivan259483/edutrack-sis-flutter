import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/loader.dart';
import 'student_shell.dart';

const _announcementStyle = {
  'Academic': (icon: Icons.school, color: Color(0xFF10B981)),
  'Enrollment': (icon: Icons.assignment_turned_in, color: Color(0xFF3B82F6)),
  'Event': (icon: Icons.event, color: Color(0xFF8B5CF6)),
  'Urgent': (icon: Icons.info, color: Color(0xFFEF4444)),
  'General': (icon: Icons.campaign, color: Color(0xFFF59E0B)),
};

class StudentNotice {
  StudentNotice({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.fullContent,
    required this.date,
    required this.sortDate,
    required this.icon,
    required this.color,
    required this.sender,
    this.actionLabel,
    this.actionPath,
    this.unread = true,
  });
  final String id;
  final String category;
  final String title;
  final String description;
  final String fullContent;
  final String date;
  final String sortDate;
  final IconData icon;
  final Color color;
  final String sender;
  final String? actionLabel;
  final String? actionPath;
  bool unread;
}

/// Turns announcements, the enrollment decision and released grades into
/// notifications (same rules as frontend/src/pages/StudentNotifications.jsx).
List<StudentNotice> buildNotifications(List<Map<String, dynamic>> announcements, Map<String, dynamic>? enrollment, List<Map<String, dynamic>> grades) {
  final items = <StudentNotice>[];
  for (final a in announcements) {
    final category = '${a['category']}';
    final style = _announcementStyle[category] ?? _announcementStyle['General']!;
    final message = '${a['message']}';
    final date = '${a['datePublished'] ?? a['dateCreated'] ?? ''}';
    items.add(
      StudentNotice(
        id: 'announcement-${a['id']}',
        category: category == 'Enrollment' ? 'Enrollment & Registrar' : (category == 'Academic' ? 'Academic & Grades' : 'Administrative & Advisories'),
        title: '${a['title']}',
        description: message.length > 160 ? '${message.substring(0, 157)}…' : message,
        fullContent: message,
        date: formatDate(date),
        sortDate: date,
        icon: style.icon,
        color: style.color,
        actionLabel: category == 'Enrollment' ? 'Go to My Enrollment' : null,
        actionPath: category == 'Enrollment' ? '/student/enrollment' : null,
        sender: a['author'] == 'Admin' ? 'Office of the University Registrar' : '${a['author']}',
      ),
    );
  }
  if (enrollment != null && enrollment['status'] != 'Pending') {
    final approved = enrollment['status'] == 'Approved';
    final subjects = (enrollment['subjects'] as List?)?.length ?? 0;
    final updated = '${enrollment['updatedAt'] ?? ''}';
    items.add(
      StudentNotice(
        id: 'enrollment-${enrollment['id']}-${enrollment['status']}',
        category: 'Enrollment & Registrar',
        title: approved ? 'Enrollment Approved — COR Available' : 'Enrollment Application Returned',
        description: approved
            ? 'Your enrollment for ${enrollment['totalUnits']} units has been approved by the Registrar.'
            : 'Registrar remarks: ${enrollment['remarks']}',
        fullContent: approved
            ? 'Your enrollment ($subjects subjects, ${enrollment['totalUnits']} units) has been approved. Your Certificate of Registration (COR) is ready to view and print.'
            : 'Your enrollment application was returned with these remarks: "${enrollment['remarks']}". Please revise your subjects and resubmit.',
        date: formatDate(updated),
        sortDate: updated,
        icon: Icons.assignment_turned_in,
        color: approved ? const Color(0xFF3B82F6) : const Color(0xFFEF4444),
        actionLabel: 'View Enrollment & COR',
        actionPath: '/student/enrollment',
        sender: 'University Registrar',
      ),
    );
  }
  final terms = <String>{for (final g in grades) '${g['semester']} ${g['academicYear']}'};
  for (final term in terms) {
    final termGrades = grades.where((g) => '${g['semester']} ${g['academicYear']}' == term).toList();
    final latest = (termGrades.map((g) => '${g['updatedAt'] ?? ''}').toList()..sort()).last;
    items.add(
      StudentNotice(
        id: 'grades-$term-${termGrades.length}',
        category: 'Academic & Grades',
        title: 'Grades Released for $term',
        description: '${termGrades.length} subject grade(s) have been published: ${termGrades.map((g) => g['subjectCode']).join(', ')}.',
        fullContent:
            'The Registrar has published ${termGrades.length} grade(s) for $term. Your term GPA is ${formatGrade(gradeSummary(termGrades).gpa)}. View the full breakdown on the My Grades page.',
        date: formatDate(latest),
        sortDate: latest,
        icon: Icons.school,
        color: const Color(0xFF10B981),
        actionLabel: 'View My Grades',
        actionPath: '/student/grades',
        sender: 'Office of the University Registrar',
      ),
    );
  }
  items.sort((a, b) => b.sortDate.compareTo(a.sortDate));
  return items;
}

/// frontend/src/pages/StudentNotifications.jsx
class StudentNotificationsPage extends StatefulWidget {
  const StudentNotificationsPage({super.key});

  @override
  State<StudentNotificationsPage> createState() => _StudentNotificationsPageState();
}

class _StudentNotificationsPageState extends State<StudentNotificationsPage> with ApiLoader {
  List<Map<String, dynamic>> _announcements = [];
  Map<String, dynamic> _enrollment = {};
  List<Map<String, dynamic>> _grades = [];
  Set<String> _read = {};
  Set<String> _dismissed = {};
  String _filter = 'All';

  /// Read/dismissed flags are a per-device convenience; the records come from the server.
  String get _prefsKey => 'edutrack_notifications_${context.read<Session>().user?.id}';

  @override
  Future<void> fetch() async {
    final results = await Future.wait([api.get('/portal/announcements'), api.get('/portal/enrollment'), api.get('/portal/grades')]);
    _announcements = asList(results[0]);
    _enrollment = asMap(results[1]) ?? {};
    _grades = asList(results[2]);
    try {
      final stored = (await SharedPreferences.getInstance()).getString(_prefsKey);
      if (stored != null) {
        final prefs = jsonDecode(stored) as Map<String, dynamic>;
        _read = {...(prefs['read'] as List? ?? []).cast<String>()};
        _dismissed = {...(prefs['dismissed'] as List? ?? []).cast<String>()};
      }
    } catch (_) {
      // Storage unavailable: flags last for this visit only.
    }
  }

  Future<void> _savePrefs() async {
    try {
      await (await SharedPreferences.getInstance()).setString(_prefsKey, jsonEncode({'read': _read.toList(), 'dismissed': _dismissed.toList()}));
    } catch (_) {}
  }

  List<StudentNotice> get _notifications => buildNotifications(
    _announcements,
    asMap(_enrollment['enrollment']),
    _grades,
  ).where((n) => !_dismissed.contains(n.id)).map((n) => n..unread = !_read.contains(n.id)).toList();

  void _markAllRead(List<StudentNotice> notices) {
    setState(() => _read.addAll(notices.map((n) => n.id)));
    _savePrefs();
    showToast(context, 'All notifications marked as read');
  }

  void _markRead(StudentNotice notice) {
    setState(() => _read.add(notice.id));
    _savePrefs();
  }

  void _dismiss(StudentNotice notice) {
    setState(() => _dismissed.add(notice.id));
    _savePrefs();
    showToast(context, 'Notification removed');
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const StudentPage(dark: true, children: [Loading()]);
    final notices = _notifications;
    final unread = notices.where((n) => n.unread).length;
    final filtered = notices.where((n) => _filter == 'All' || (_filter == 'Unread' ? n.unread : n.category == _filter)).toList();
    final period = asMap(_enrollment['period']);
    return StudentPage(
      dark: true,
      onRefresh: reload,
      children: [
        if (loadError != null) ...[LoadError(message: loadError!, onRetry: () => reload(showSpinner: true)), const SizedBox(height: 16)],
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Notifications & Bulletins',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (unread > 0) ...[const SizedBox(width: 8), Pill('$unread New', color: AppColors.danger, solid: true)],
              ],
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFF8F9FA)),
              ),
              onPressed: unread == 0 ? null : () => _markAllRead(notices),
              icon: const Icon(Icons.done_all, size: 16),
              label: const Text('Mark All Read'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          minItemWidth: 220,
          children: [
            StatCard(
              dark: true,
              icon: Icons.notifications,
              color: AppColors.primary,
              background: AppColors.primary.withValues(alpha: 0.1),
              label: 'Total Alerts',
              value: Text('${notices.length} Notices'),
              caption: period != null ? 'Academic Year ${period['academicYear']}' : '',
            ),
            StatCard(
              dark: true,
              icon: Icons.info,
              color: AppColors.danger,
              background: AppColors.danger.withValues(alpha: 0.1),
              label: 'Unread Messages',
              value: Text('$unread Pending', style: const TextStyle(color: AppColors.danger)),
              caption: 'Action required on recent items',
            ),
            StatCard(
              dark: true,
              icon: Icons.school,
              color: AppColors.success,
              background: AppColors.success.withValues(alpha: 0.1),
              label: 'Academic & Grades',
              value: Text('${notices.where((n) => n.category == 'Academic & Grades').length} Updates', style: const TextStyle(color: AppColors.success)),
              caption: 'Evaluation records synced',
            ),
            StatCard(
              dark: true,
              icon: Icons.check,
              color: AppColors.info,
              background: AppColors.info.withValues(alpha: 0.1),
              label: 'Delivery Channel',
              value: const Text('Active & Synced', style: TextStyle(color: AppColors.info, fontSize: 17)),
              caption: 'In-App & Email OTP Enabled',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, count) in [
              ('All', notices.length),
              ('Unread', unread),
              ('Academic & Grades', 0),
              ('Enrollment & Registrar', 0),
              ('Administrative & Advisories', 0),
            ])
              ChoiceChip(
                selected: _filter == label,
                showCheckmark: false,
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.dark,
                side: BorderSide(color: _filter == label ? AppColors.primary : const Color(0x406C757D)),
                onSelected: (_) => setState(() => _filter = label),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: TextStyle(color: _filter == label ? Colors.white : AppColors.slate400, fontSize: 13)),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Pill('$count', color: _filter == label ? Colors.white : AppColors.muted, solid: true, fontSize: 10),
                    ],
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.slate800,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x406C757D)),
            ),
            child: const Column(
              children: [
                Icon(Icons.notifications, size: 40, color: Color(0x4DFFFFFF)),
                SizedBox(height: 12),
                Text(
                  'No Notifications Found',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17),
                ),
                SizedBox(height: 4),
                Text(
                  'You have caught up with all alerts under this category.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.slate400, fontSize: 13),
                ),
              ],
            ),
          ),
        for (final notice in filtered) _card(notice),
      ],
    );
  }

  Widget _card(StudentNotice n) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: n.unread ? AppColors.slate800 : const Color(0xFF141E30),
      border: Border.all(color: n.unread ? AppColors.blue500 : const Color(0x14FFFFFF)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _open(n),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: n.color.withValues(alpha: 0.13),
              child: Icon(n.icon, color: n.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Pill(n.category, color: n.color),
                      if (n.unread) const Pill('New', color: AppColors.danger, solid: true, fontSize: 10),
                      Text(n.date, style: const TextStyle(color: AppColors.slate400, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    n.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.slate400, fontSize: 13, height: 1.5),
                  ),
                  const Divider(color: Color(0x1A6C757D), height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(color: AppColors.slate400, fontSize: 11),
                            children: [
                              const TextSpan(text: 'From: '),
                              TextSpan(
                                text: n.sender,
                                style: const TextStyle(color: Color(0xFFF8F9FA), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (n.actionPath != null)
                        TextButton(
                          onPressed: () => context.go(n.actionPath!),
                          child: Text('${n.actionLabel} ›', style: const TextStyle(fontSize: 12)),
                        ),
                      IconButton(
                        tooltip: 'Dismiss',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _dismiss(n),
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.slate400),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _open(StudentNotice n) {
    _markRead(n);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.slate800,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: n.color, width: 6)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: n.color.withValues(alpha: 0.13),
                        child: Icon(n.icon, color: n.color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Pill(n.category, color: n.color),
                            const SizedBox(height: 4),
                            Text(
                              n.title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.dark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0x406C757D)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  style: const TextStyle(fontSize: 13),
                                  children: [
                                    const TextSpan(
                                      text: 'Sender: ',
                                      style: TextStyle(color: AppColors.slate400),
                                    ),
                                    TextSpan(
                                      text: n.sender,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Text(
                              n.date,
                              style: const TextStyle(color: AppColors.slate400, fontFamily: 'monospace', fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0x80212529),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0x406C757D)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'NOTICE DETAILS',
                              style: TextStyle(color: AppColors.slate400, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(n.fullContent, style: const TextStyle(color: Color(0xFFF8F9FA), height: 1.7, fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                        ),
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _dismiss(n);
                        },
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Delete Alert'),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.muted),
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Close'),
                          ),
                          if (n.actionPath != null)
                            FilledButton.icon(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                context.go(n.actionPath!);
                              },
                              icon: const Icon(Icons.open_in_new, size: 14),
                              label: Text(n.actionLabel!),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
