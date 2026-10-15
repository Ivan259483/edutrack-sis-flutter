import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/pdf_docs.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/loader.dart';
import 'enrollment_page.dart' show kvText, signatureLine;
import 'student_shell.dart';

/// frontend/src/pages/StudentGrades.jsx
class StudentGradesPage extends StatefulWidget {
  const StudentGradesPage({super.key});

  @override
  State<StudentGradesPage> createState() => _StudentGradesPageState();
}

class _GradeRow {
  _GradeRow(Map<String, dynamic> g, this.instructor)
    : code = '${g['subjectCode']}',
      title = '${g['subjectTitle']}',
      units = g['units'] as num,
      midterm = formatGrade(g['midtermGrade']),
      grade = formatGrade(g['finalGrade']),
      remark = '${g['remark']}';
  final String code;
  final String title;
  final num units;
  final String midterm;
  final String grade;
  final String remark;
  final String instructor;
  bool get passed => remark == 'Passed';
}

class _StudentGradesPageState extends State<StudentGradesPage> with ApiLoader {
  List<Map<String, dynamic>> _grades = [];
  List<Map<String, dynamic>> _schedule = [];
  String _term = '';

  @override
  Future<void> fetch() async {
    final results = await Future.wait([api.get('/portal/grades'), api.get('/portal/schedule')]);
    _grades = asList(results[0]);
    _schedule = asList(results[1]);
  }

  static String _termOf(Map<String, dynamic> g) => '${g['semester']} ${g['academicYear']}';

  /// Latest academic year first, then by semester name.
  List<String> get _terms {
    final terms = _grades.map(_termOf).toSet().toList();
    String year(String t) => t.length >= 9 ? t.substring(t.length - 9) : t;
    terms.sort((a, b) {
      final byYear = year(b).compareTo(year(a));
      return byYear != 0 ? byYear : b.compareTo(a);
    });
    return terms;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const StudentPage(children: [Loading()]);
    if (loadError != null) {
      return StudentPage(
        children: [LoadError(message: loadError!, onRetry: () => reload(showSpinner: true))],
      );
    }
    final terms = _terms;
    final selectedTerm = _term.isNotEmpty ? _term : (terms.isNotEmpty ? terms.first : 'No published grades');
    final instructors = {for (final c in _schedule) '${c['subjectCode']}': '${c['instructor']}'};
    final termGrades = _grades.where((g) => _termOf(g) == selectedTerm).toList();
    final rows = [for (final g in termGrades) _GradeRow(g, instructors['${g['subjectCode']}'] ?? 'Faculty')];
    final summary = gradeSummary(termGrades);
    final gpa = formatGrade(summary.gpa);
    final notPassed = rows.where((r) => !r.passed).length;
    final passText = rows.isEmpty ? '' : (notPassed > 0 ? '• $notPassed subject(s) not passed' : '• All Subjects Passed');
    final passColor = notPassed > 0 ? AppColors.danger : AppColors.success;
    final profile = context.watch<Session>().user?.profile;

    return StudentPage(
      onRefresh: reload,
      children: [
        // 1. Term selector & transcript
        Panel(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Academic Term:',
                    style: TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  // Up to 240 wide; narrower on small phones.
                  Flexible(
                    child: SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(selectedTerm),
                        initialValue: selectedTerm,
                        isExpanded: true,
                        decoration: const InputDecoration(fillColor: AppColors.light),
                        items: terms.isEmpty
                            ? [DropdownMenuItem(value: selectedTerm, child: Text(selectedTerm))]
                            : [
                                for (final (i, t) in terms.indexed)
                                  DropdownMenuItem(
                                    value: t,
                                    child: Text('$t${i == 0 ? ' (Latest)' : ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                              ],
                        onChanged: (v) => setState(() => _term = v ?? ''),
                      ),
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () => _showTranscript(selectedTerm, rows, summary.units, gpa, passText, passColor, profile),
                icon: const Icon(Icons.description, size: 16),
                label: const Text('Official Transcript of Records'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 2. KPI cards
        ResponsiveGrid(
          minItemWidth: 240,
          children: [
            StatCard(
              icon: Icons.show_chart,
              color: AppColors.primary,
              background: AppColors.blue50,
              label: 'Term GPA',
              value: Text(gpa),
              caption: 'Weighted by units',
            ),
            StatCard(
              icon: Icons.menu_book,
              color: AppColors.success,
              background: AppColors.green50,
              label: 'Total Enrolled Units',
              value: Text('${num0(summary.units)} Units'),
              caption: '${rows.length} Subjects Evaluated',
            ),
            StatCard(
              icon: Icons.emoji_events,
              color: AppColors.amber600,
              background: AppColors.amber50,
              label: 'Academic Status',
              value: Text('${profile?['academicStatus'] ?? '—'}', style: const TextStyle(fontSize: 18)),
              caption: profile != null ? '${profile['yearLevel']} • ${profile['section']}' : '',
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 3. Subject grades
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PanelTitle(
                'Subject Grade Evaluation',
                subtitle: 'Grading Scale: 1.00 (Highest) to 3.00 (Passing) • 5.00 (Failed)',
                trailing: Pill(selectedTerm, color: AppColors.muted),
              ),
              if (rows.isEmpty) const Empty('No grades have been published for you yet.'),
              for (final row in rows) _gradeTile(row),
              if (rows.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.light, borderRadius: BorderRadius.circular(8)),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Weighted Semester Average (GPA):', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${num0(summary.units)} Units', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        gpa,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16),
                      ),
                      Text(
                        passText,
                        style: TextStyle(color: passColor, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gradeTile(_GradeRow row) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.borderLight)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.code,
                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              ),
              Text(row.title, style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(
                '${num0(row.units)} units • Midterm ${row.midterm} • Final ${row.grade} • ${row.instructor}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              row.grade,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
            ),
            const SizedBox(height: 4),
            Pill(row.remark, color: row.passed ? AppColors.success : AppColors.danger, icon: row.passed ? Icons.check_circle : null),
          ],
        ),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: () => _showDetail(row), child: const Text('Details')),
      ],
    ),
  );

  void _showDetail(_GradeRow row) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ),
              CodeBadge(row.code),
              const SizedBox(height: 8),
              Text(
                row.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(row.instructor, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(color: AppColors.blue50, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    const Text('FINAL NUMERICAL GRADE', style: TextStyle(color: AppColors.muted, fontSize: 12, letterSpacing: 1)),
                    Text(
                      row.grade,
                      style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    Pill(row.remark, color: AppColors.success, solid: true),
                  ],
                ),
              ),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [_figure('Midterm Exam', row.midterm), _figure('Final Exam', row.grade), _figure('Credits', '${num0(row.units)} Units')],
              ),
              const Divider(height: 32),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _figure(String label, String value) => Column(
    children: [
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    ],
  );

  void _showTranscript(String term, List<_GradeRow> rows, num units, String gpa, String passText, Color passColor, Map<String, dynamic>? profile) {
    final user = context.read<Session>().user;
    final program = profile != null ? '${programName(profile['program'] as String?)} (${profile['program']})' : '—';
    final yearSection = profile != null ? '${profile['yearLevel']} • ${profile['section']}' : '—';
    final doc = PrintableDoc(
      title: 'Transcript - ${user?.studentId ?? ''}',
      subtitle: 'Office of the University Registrar • Academic Records Division',
      badge: 'Official Transcript of Records',
      info: [
        ('Student Name', user?.name ?? ''),
        ('Student ID', user?.studentId ?? ''),
        ('Degree Program', program),
        ('Year & Section', yearSection),
        ('Academic Term', term),
        ('Academic Status', '${profile?['academicStatus'] ?? '—'}'),
      ],
      sections: [
        DocSection(
          headers: const ['Subject Code', 'Subject Title', 'Units', 'Final Grade', 'Remarks', 'Professor'],
          rows: [
            for (final r in rows) [r.code, r.title, num0(r.units), r.grade, r.remark, r.instructor],
          ],
          footer: ['', 'Cumulative Term GPA:', num0(units), gpa, passText, ''],
        ),
      ],
      signatures: [(user?.name ?? '', "Student's Signature"), ('', 'University Registrar')],
    );
    showSheetDialog<void>(
      context,
      title: 'Official Transcript of Records / Certificate of Grades',
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: Text('🎓', style: TextStyle(fontSize: 30))),
          const Center(
            child: Text('EDUTRACK UNIVERSITY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1)),
          ),
          const Center(
            child: Text(
              'Office of the University Registrar • Academic Records Division',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 6),
          const Center(child: CodeBadge('OFFICIAL TRANSCRIPT OF RECORDS')),
          const Divider(height: 28),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.light,
              border: Border.all(color: AppColors.borderLight),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ResponsiveGrid(
              minItemWidth: 240,
              spacing: 6,
              children: [
                kvText('Student Name', user?.name ?? ''),
                kvText('Student ID', user?.studentId ?? ''),
                kvText('Degree Program', program),
                kvText('Year & Section', yearSection),
                kvText('Academic Term', term),
                Row(
                  children: [
                    const Text('Academic Status: ', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                    Pill('${profile?['academicStatus'] ?? '—'}', color: AppColors.muted, solid: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.light),
              border: TableBorder.all(color: AppColors.borderLight),
              columns: const [
                DataColumn(label: Text('Subject Code')),
                DataColumn(label: Text('Subject Title')),
                DataColumn(label: Text('Units'), numeric: true),
                DataColumn(label: Text('Final Grade')),
                DataColumn(label: Text('Remarks')),
                DataColumn(label: Text('Professor')),
              ],
              rows: [
                for (final r in rows)
                  DataRow(
                    cells: [
                      DataCell(
                        Text(
                          r.code,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        ),
                      ),
                      DataCell(Text(r.title)),
                      DataCell(Text(num0(r.units))),
                      DataCell(Text(r.grade, style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(
                        Text(
                          r.remark,
                          style: TextStyle(fontWeight: FontWeight.w600, color: r.passed ? AppColors.success : AppColors.danger),
                        ),
                      ),
                      DataCell(Text(r.instructor)),
                    ],
                  ),
                DataRow(
                  cells: [
                    const DataCell(Text('')),
                    const DataCell(Text('Cumulative Term GPA:', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(num0(units), style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(
                      Text(
                        gpa,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    DataCell(Text(passText, style: TextStyle(color: passColor, fontSize: 12))),
                    const DataCell(Text('')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 16,
            children: [signatureLine(user?.name ?? '', "Student's Signature"), signatureLine('', 'University Registrar')],
          ),
        ],
      ),
      actions: (context) => [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        FilledButton.icon(onPressed: () => doc.print(), icon: const Icon(Icons.print, size: 16), label: const Text('Print / Save as PDF')),
      ],
    );
  }
}
