import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../core/pdf_docs.dart';
import '../../../core/theme.dart';
import '../../../widgets/common.dart';
import '../admin_widgets.dart';
import '../data/admin_rules.dart';
import '../data/admin_store.dart';

/// Encode, publish and print grades (admin/src/pages/AcademicRecordsPage.tsx).
class AcademicRecordsPage extends StatefulWidget {
  const AcademicRecordsPage({super.key, this.action});

  /// `encode` opens the grade picker (dashboard quick action).
  final String? action;

  @override
  State<AcademicRecordsPage> createState() => _AcademicRecordsPageState();
}

class _AcademicRecordsPageState extends State<AcademicRecordsPage> {
  String _search = '';
  String _semester = 'all';
  String _publishFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.action == 'encode') _chooseGrade();
    });
  }

  Future<void> _chooseGrade() async {
    final store = context.read<AdminStore>();
    final open = store.settings['gradeEncodingOpen'] == true;
    final grade = await showSheetDialog<Map<String, dynamic>>(
      context,
      title: 'Select a grade to encode',
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            open ? 'Choose a student and subject.' : 'Grade encoding is disabled. Enable it in Settings first.',
            style: const TextStyle(color: AppColors.adminMutedFg, fontSize: 13),
          ),
          const SizedBox(height: 8),
          for (final g in store.grades)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
                onPressed: open ? () => Navigator.pop(context, g) : null,
                child: Text('${g['studentName']} · ${g['subjectTitle']}'),
              ),
            ),
          if (store.grades.isEmpty) const Empty('No grade records are available for encoding.'),
        ],
      ),
    );
    if (grade != null && mounted) _encode(grade);
  }

  void _encode(Map<String, dynamic> grade) {
    showSheetDialog<void>(
      context,
      title: 'Encode Grade',
      builder: (_) => _EncodeForm(grade: grade),
    );
  }

  Future<void> _publish(Map<String, dynamic> g) async {
    if (!canPublishGrade(g)) {
      showToast(context, 'A valid final grade is required before publication.', error: true);
      return;
    }
    await runChange(
      context,
      () => context.read<AdminStore>().save(AdminCollection.grades, {
        ...g,
        'publishStatus': 'Published',
      }, action: 'Published grade for ${g['studentName']}: ${g['subjectTitle']}'),
      success: 'Grade published',
      description: '${g['subjectTitle']} grade for ${g['studentName']} has been marked as published.',
    );
  }

  void _transcript(String studentId) {
    final store = context.read<AdminStore>();
    final summary = transcriptSummary(store.grades.where((g) => g['studentId'] == studentId));
    if (summary.records.isEmpty) return;
    final first = summary.records.first;
    final gpa = summary.gpa?.toStringAsFixed(2) ?? 'N/A';
    String finalText(Map<String, dynamic> g) => g['finalGrade'] is num ? (g['finalGrade'] as num).toStringAsFixed(2) : 'INC';
    showSheetDialog<void>(
      context,
      title: 'Transcript of Records',
      builder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Printable preview', style: TextStyle(color: AppColors.adminMutedFg, fontSize: 13)),
          const SizedBox(height: 12),
          InfoGrid([('Student Name', '${first['studentName']}'), ('Student Number', '${first['studentNumber']}')], minItemWidth: 200),
          const SizedBox(height: 8),
          InfoGrid([('Completed Units', num0(summary.completedUnits)), ('Units Passed', num0(summary.passedUnits)), ('GPA', gpa)], minItemWidth: 100),
          const SectionLabel('Subjects'),
          for (final g in summary.records)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.adminBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${g['subjectCode']} · ${g['subjectTitle']}', style: const TextStyle(fontSize: 13)),
                        Text(
                          '${g['academicYear']} · ${g['semester']} · ${num0(g['units'] as num)} units',
                          style: const TextStyle(fontSize: 11, color: AppColors.adminMutedFg),
                        ),
                      ],
                    ),
                  ),
                  Text(finalText(g), style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  StatusBadge('${g['remark']}'),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Print'),
              onPressed: () => PrintableDoc(
                title: 'Transcript of Records - ${first['studentNumber']}',
                subtitle: 'Office of the Registrar',
                badge: 'Transcript of Records',
                info: [
                  ('Student Name', '${first['studentName']}'),
                  ('Student Number', '${first['studentNumber']}'),
                  ('Completed Units', num0(summary.completedUnits)),
                  ('Units Passed', num0(summary.passedUnits)),
                  ('GPA', gpa),
                ],
                sections: [
                  DocSection(
                    headers: const ['Code', 'Subject', 'Units', 'Final Grade', 'Remark'],
                    rows: [
                      for (final g in summary.records)
                        [
                          '${g['subjectCode']}',
                          '${g['subjectTitle']}\n${g['academicYear']} · ${g['semester']}',
                          num0(g['units'] as num),
                          finalText(g),
                          '${g['remark']}',
                        ],
                    ],
                  ),
                ],
              ).print(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final grades = store.grades;
    final open = store.settings['gradeEncodingOpen'] == true;
    final query = _search.toLowerCase();
    final filtered = grades.where((g) {
      final matchSearch = ['studentName', 'subjectTitle', 'section'].any((f) => '${g[f]}'.toLowerCase().contains(query));
      return matchSearch && (_semester == 'all' || g['semester'] == _semester) && (_publishFilter == 'all' || g['publishStatus'] == _publishFilter);
    }).toList();
    int count(String field, String value) => grades.where((g) => g[field] == value).length;
    bool hasTranscript(String id) => grades.any((g) => g['studentId'] == id && g['publishStatus'] == 'Published' && canPublishGrade(g));
    String gradeText(Object? v) => v is num ? v.toStringAsFixed(2) : '-';

    return AdminPage(
      onRefresh: store.refresh,
      children: [
        AdminPageHeader(title: 'Academic Records', description: '${periodLabel(store.settings)} · Grade encoding ${open ? 'enabled' : 'disabled'}'),
        ResponsiveGrid(
          minItemWidth: 150,
          children: [
            for (final (label, value, color) in [
              ('Published Grades', count('publishStatus', 'Published'), AppColors.adminFg),
              ('Draft Grades', count('publishStatus', 'Draft'), AppColors.adminFg),
              ('Passed', count('remark', 'Passed'), AppColors.green600),
              ('Failed / Incomplete', count('remark', 'Failed') + count('remark', 'Incomplete'), const Color(0xFFDC2626)),
            ])
              AdminCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 12, color: AppColors.adminMutedFg)),
                    const SizedBox(height: 4),
                    Text(
                      '$value',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        FilterGrid(
          children: [
            SearchBox(hint: 'Search by student, subject, or section...', value: _search, onChanged: (v) => setState(() => _search = v)),
            FilterSelect(
              label: 'Semester',
              allLabel: 'All Semesters',
              value: _semester,
              options: semesterOptions,
              onChanged: (v) => setState(() => _semester = v),
            ),
            FilterSelect(
              label: 'Status',
              allLabel: 'All Statuses',
              value: _publishFilter,
              options: const ['Published', 'Draft'],
              onChanged: (v) => setState(() => _publishFilter = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AdminCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CardHeading('${filtered.length} grade record${filtered.length != 1 ? 's' : ''}'),
              if (filtered.isEmpty) const Empty('No grade records found\nTry adjusting your search or filters.', icon: Icons.school_outlined),
              for (final g in filtered)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.adminBorder)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${g['studentName']}', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                                Text(
                                  '${g['studentNumber']}',
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.adminMutedFg),
                                ),
                                const SizedBox(height: 2),
                                Text('${g['subjectTitle']} (${g['subjectCode']}) · ${g['section']}', style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          StatusBadge('${g['publishStatus']}'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text('Midterm ${gradeText(g['midtermGrade'])}', style: const TextStyle(fontSize: 12)),
                                Text('Final ${gradeText(g['finalGrade'])}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                StatusBadge('${g['remark']}', dot: true),
                              ],
                            ),
                          ),
                          IconButton(tooltip: 'Encode grade', onPressed: open ? () => _encode(g) : null, icon: const Icon(Icons.edit_outlined, size: 20)),
                          if (g['publishStatus'] == 'Draft')
                            IconButton(
                              tooltip: canPublishGrade(g) ? 'Publish grade' : 'A valid final grade is required',
                              onPressed: open && canPublishGrade(g) ? () => _publish(g) : null,
                              icon: const Icon(Icons.upload_outlined, size: 20),
                            ),
                          IconButton(
                            tooltip: 'Transcript of Records',
                            onPressed: hasTranscript('${g['studentId']}') ? () => _transcript('${g['studentId']}') : null,
                            icon: const Icon(Icons.description_outlined, size: 20),
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
    );
  }
}

/// Midterm/final entry with the live remark preview.
class _EncodeForm extends StatefulWidget {
  const _EncodeForm({required this.grade});
  final Map<String, dynamic> grade;

  @override
  State<_EncodeForm> createState() => _EncodeFormState();
}

class _EncodeFormState extends State<_EncodeForm> {
  late final _midterm = TextEditingController(text: _initial('midtermGrade'));
  late final _final = TextEditingController(text: _initial('finalGrade'));
  String _error = '';
  bool _saving = false;
  // Messages under each grade: after leaving the field (blur) or on save, plus the API's.
  final Set<String> _touched = {};
  Map<String, String> _serverErrors = const {};

  String _initial(String field) => widget.grade[field] is num ? '${widget.grade[field]}' : '';

  @override
  void dispose() {
    _midterm.dispose();
    _final.dispose();
    super.dispose();
  }

  /// Same rule as the API: empty, or 1.00–5.00 with up to two decimals.
  String? _gradeError(String field) {
    if (_serverErrors[field] != null) return _serverErrors[field];
    try {
      parseGrade((field == 'midtermGrade' ? _midterm : _final).text);
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }

  String? _shown(String field) => _touched.contains(field) ? _gradeError(field) : null;

  Future<void> _save() async {
    if (_saving) return; // no double submits
    final g = widget.grade;
    setState(() => _touched.addAll(['midtermGrade', 'finalGrade']));
    if (_gradeError('midtermGrade') != null || _gradeError('finalGrade') != null) return;
    final midterm = parseGrade(_midterm.text);
    final finalGrade = parseGrade(_final.text);
    setState(() {
      _error = '';
      _saving = true;
    });
    final navigator = Navigator.of(context);
    final ok = await runChange(
      context,
      () => context.read<AdminStore>().save(AdminCollection.grades, {
        ...g,
        'midtermGrade': midterm,
        'finalGrade': finalGrade,
        'numericalGrade': finalGrade,
        'remark': calculateRemark(finalGrade),
        'publishStatus': 'Draft',
      }, action: 'Encoded grade for ${g['studentName']}: ${g['subjectTitle']}'),
      success: 'Grade saved',
      description: '${g['subjectTitle']} grade for ${g['studentName']} has been encoded.',
      onError: (message) => _error = message,
      onFieldErrors: (errors) => _serverErrors = errors,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.grade;
    String? preview;
    try {
      preview = calculateRemark(parseGrade(_final.text));
    } on FormatException {
      preview = null;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${g['studentName']} · ${g['subjectTitle']}', style: const TextStyle(color: AppColors.adminMutedFg, fontSize: 13)),
        const SizedBox(height: 12),
        if (_error.isNotEmpty) AlertBox(_error),
        InfoGrid([('Student', '${g['studentName']}'), ('Subject', '${g['subjectTitle']}')]),
        const SizedBox(height: 12),
        ResponsiveGrid(
          minItemWidth: 200,
          children: [
            for (final (field, controller, label, hint) in [
              ('midtermGrade', _midterm, 'Midterm Grade (1.00 - 5.00)', 'e.g. 1.50'),
              ('finalGrade', _final, 'Final Grade (1.00 - 5.00)', 'e.g. 1.25'),
            ])
              Focus(
                onFocusChange: (focused) => focused ? null : setState(() => _touched.add(field)),
                child: TextField(
                  key: Key(field == 'midtermGrade' ? 'grade-midterm' : 'grade-final'),
                  controller: controller,
                  maxLength: 4,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: label, hintText: hint, errorText: _shown(field), errorMaxLines: 3, counterText: ''),
                  onChanged: (_) => setState(() => _serverErrors = const {}),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.adminMuted, borderRadius: BorderRadius.circular(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Auto-calculated Remark', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  if (preview == null)
                    const Text('Enter a valid grade from 1.00 to 5.00.', style: TextStyle(fontSize: 12, color: AppColors.adminDestructive))
                  else
                    StatusBadge(preview, dot: true),
                ],
              ),
              const SizedBox(height: 4),
              const Text('1.00-3.00 = Passed · Above 3.00 = Failed · No final = Incomplete', style: TextStyle(fontSize: 11, color: AppColors.adminMutedFg)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          children: [
            OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(key: const Key('grade-save'), onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save Grade')),
          ],
        ),
      ],
    );
  }
}
