import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/loader.dart';
import 'student_shell.dart';

/// frontend/src/pages/StudentDashboard.jsx
class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> with ApiLoader {
  Map<String, dynamic> _profile = {};
  List<Map<String, dynamic>> _grades = [];
  List<Map<String, dynamic>> _schedule = [];
  Map<String, dynamic> _enrollment = {};

  @override
  Future<void> fetch() async {
    final results = await Future.wait([api.get('/portal/profile'), api.get('/portal/grades'), api.get('/portal/schedule'), api.get('/portal/enrollment')]);
    _profile = asMap(results[0]) ?? {};
    _grades = asList(results[1]);
    _schedule = asList(results[2]);
    _enrollment = asMap(results[3]) ?? {};
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const StudentPage(children: [Loading()]);
    if (loadError != null) {
      return StudentPage(
        children: [LoadError(message: loadError!, onRetry: () => reload(showSpinner: true))],
      );
    }
    final user = context.watch<Session>().user;
    final summary = gradeSummary(_grades);
    final period = asMap(_enrollment['period']);
    final current = asMap(_enrollment['enrollment']);
    final today = todayName();
    final todaysClasses = _schedule.where((c) => c['day'] == today).toList();
    final recentGrades = _grades.take(4).toList();
    final passed = _grades.where((g) => g['remark'] == 'Passed').length;
    final firstName = ((_profile['fullName'] as String?) ?? user?.name ?? '').split(' ').first;
    final enrolledCount = current?['status'] == 'Approved' ? (current!['subjects'] as List).length : 0;

    return StudentPage(
      onRefresh: reload,
      children: [
        // 1. Welcome banner
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.blue700, AppColors.blue600], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat('EEEE, MMMM d, y').format(manilaNow()), style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                'Welcome back, $firstName!',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                "Here's an overview of your academic progress for ${period?['academicYear'] ?? ''}, ${period?['semester'] ?? ''}.",
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 2. KPI cards
        ResponsiveGrid(
          minItemWidth: 220,
          children: [
            StatCard(icon: Icons.show_chart, color: AppColors.blue600, background: AppColors.blue50, label: 'GPA', value: Text(formatGrade(summary.gpa))),
            StatCard(icon: Icons.menu_book, color: AppColors.green600, background: AppColors.green50, label: 'Units Earned', value: Text(num0(summary.earned))),
            StatCard(icon: Icons.school, color: AppColors.violet500, background: AppColors.violet50, label: 'Enrolled Subjects', value: Text('$enrolledCount')),
            StatCard(
              icon: Icons.emoji_events,
              color: AppColors.amber600,
              background: AppColors.amber50,
              label: 'Academic Status',
              value: Text('${_profile['academicStatus'] ?? '—'}', style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 3. Academic progress & student information
        ResponsiveGrid(
          minItemWidth: 340,
          spacing: 16,
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PanelTitle('Academic Progress', subtitle: 'Based on your published grades'),
                  Row(
                    children: [
                      _Figure(formatGrade(summary.gpa), 'Current GPA'),
                      _Figure(num0(summary.earned), 'Units Earned'),
                      _Figure('$passed', 'Subjects Passed', last: true),
                    ],
                  ),
                  const Divider(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Program', style: TextStyle(color: AppColors.muted, fontSize: 11)),
                            Text(programName(_profile['program'] as String?), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                      Pill('${_profile['yearLevel'] ?? ''}', color: AppColors.primary),
                    ],
                  ),
                ],
              ),
            ),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PanelTitle('Student Information'),
                  InfoRow('Student ID', '${_profile['studentId'] ?? ''}'),
                  InfoRow('Program', programName(_profile['program'] as String?)),
                  InfoRow('Year & Section', '${_profile['yearLevel'] ?? ''} · ${_profile['section'] ?? ''}'),
                  InfoRow('Semester', '${period?['semester'] ?? ''}'),
                  InfoRow('Academic Year', '${period?['academicYear'] ?? ''}'),
                  InfoRow('Status', '${_profile['academicStatus'] ?? ''}'),
                  InfoRow('Enrollment', current != null ? '${current['status']}' : 'Not submitted', last: true),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 4. Today's classes & recent grades
        ResponsiveGrid(
          minItemWidth: 340,
          spacing: 16,
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PanelTitle(
                    "Today's Classes",
                    subtitle: '$today: ${todaysClasses.length} class(es) scheduled',
                    trailing: IconButton(
                      tooltip: 'Open schedule',
                      icon: const Icon(Icons.arrow_forward, color: AppColors.muted),
                      onPressed: () => context.go('/student/schedule'),
                    ),
                  ),
                  if (todaysClasses.isEmpty) const Text('No classes today. 🎉', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  for (final item in todaysClasses)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.borderLight),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(color: AppColors.blue50, shape: BoxShape.circle),
                            child: const Icon(Icons.schedule, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item['subjectTitle']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text(
                                  '${item['subjectCode']} | ${formatTime(item['startTime'] as String?)} to ${formatTime(item['endTime'] as String?)} | ${item['instructor']}',
                                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Pill('📍 ${item['room']}', color: AppColors.muted),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PanelTitle(
                    'Recent Grades',
                    subtitle: 'Latest posted grades',
                    trailing: IconButton(
                      tooltip: 'Open grades',
                      icon: const Icon(Icons.arrow_forward, color: AppColors.muted),
                      onPressed: () => context.go('/student/grades'),
                    ),
                  ),
                  if (recentGrades.isEmpty) const Text('No grades have been published yet.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  for (final grade in recentGrades)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFF1F3F5))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${grade['subjectCode']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('${grade['subjectTitle']}', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatGrade(grade['finalGrade']),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: grade['remark'] == 'Passed' ? AppColors.success : AppColors.danger,
                                ),
                              ),
                              Text(
                                '${grade['remark']}',
                                style: TextStyle(fontSize: 10, color: grade['remark'] == 'Passed' ? AppColors.success : AppColors.danger),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.value, this.label, {this.last = false});
  final String value;
  final String label;
  final bool last;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(right: BorderSide(color: AppColors.borderLight)),
            ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
        ],
      ),
    ),
  );
}
