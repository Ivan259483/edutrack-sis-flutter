import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../widgets/common.dart';
import '../admin_widgets.dart';
import '../data/admin_rules.dart';
import '../data/admin_store.dart';

/// Search, filter, view, add, edit, delete and export students
/// (admin/src/pages/StudentDirectoryPage.tsx).
class StudentDirectoryPage extends StatefulWidget {
  const StudentDirectoryPage({super.key, this.recordId, this.action});

  /// Opens this student's profile (`?record=`).
  final String? recordId;

  /// `add` opens the Add Student form (dashboard quick action).
  final String? action;

  @override
  State<StudentDirectoryPage> createState() => _StudentDirectoryPageState();
}

class _StudentDirectoryPageState extends State<StudentDirectoryPage> {
  static const _pageSize = 8;
  String _search = '';
  String _program = 'all';
  String _year = 'all';
  String _section = 'all';
  String _status = 'all';
  int _page = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.action == 'add') _openForm(null);
      final student = context.read<AdminStore>().find(AdminCollection.students, widget.recordId);
      if (student != null) _openProfile(student);
    });
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> students) {
    final query = normalize(_search);
    return students.where((s) {
      return ['fullName', 'studentId', 'email'].any((f) => normalize('${s[f] ?? ''}').contains(query)) &&
          (_program == 'all' || s['program'] == _program) &&
          (_year == 'all' || s['yearLevel'] == _year) &&
          (_section == 'all' || s['section'] == _section) &&
          (_status == 'all' || s['academicStatus'] == _status);
    }).toList();
  }

  bool get _hasFilters => _search.isNotEmpty || _program != 'all' || _year != 'all' || _section != 'all' || _status != 'all';

  void _set(VoidCallback change) => setState(() {
    change();
    _page = 1;
  });

  Future<void> _export(List<Map<String, dynamic>> students) async {
    final name = 'students-${todayIso()}.csv';
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(utf8.encode(studentCsv(students)), mimeType: 'text/csv', name: name)],
          fileNameOverrides: [name],
          subject: 'EduTrack student directory',
        ),
      );
      if (mounted) showToast(context, 'CSV export ready', description: '${students.length} matching student records prepared.');
    } catch (error) {
      if (mounted) showToast(context, 'Export failed', error: true, description: '$error');
    }
  }

  void _openForm(Map<String, dynamic>? student) {
    showSheetDialog<void>(
      context,
      title: student == null ? 'Add Student' : 'Edit Student',
      builder: (_) => StudentForm(student: student),
    );
  }

  void _openProfile(Map<String, dynamic> s) {
    showSheetDialog<void>(
      context,
      title: 'Student Profile',
      builder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Detailed student information', style: TextStyle(color: AppColors.adminMutedFg, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            children: [
              InitialsAvatar('${s['fullName']}', radius: 28, text: '${s['avatarInitials'] ?? initials('${s['fullName']}')}'),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${s['fullName']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${s['studentId']}',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: AppColors.adminMutedFg),
                        ),
                        StatusBadge('${s['academicStatus']}', dot: true),
                        Text('${s['program']} · ${s['section']}', style: const TextStyle(fontSize: 13, color: AppColors.adminMutedFg)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SectionLabel('Contact Information'),
          InfoGrid([
            ('Email', '${s['email']}'),
            ('Contact Number', '${s['contactNumber']}'),
            ('Address', '${s['address']}'),
            ('Date Enrolled', formatDate(s['dateEnrolled'] as String?)),
          ], minItemWidth: 200),
          const SectionLabel('Emergency Contact'),
          InfoGrid([('Contact Name', '${s['emergencyContact']}'), ('Contact Number', '${s['emergencyContactNumber']}')], minItemWidth: 200),
          const SectionLabel('Academic Information'),
          InfoGrid([('Program', '${s['program']}'), ('Year Level', '${s['yearLevel']}'), ('Section', '${s['section']}')], minItemWidth: 120),
        ],
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> s) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete Student',
      message: 'Are you sure you want to delete ${s['fullName']}? This action cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final store = context.read<AdminStore>();
    await runChange(
      context,
      () async {
        // Same guard as admin/src/data/transitions.ts (the API checks it too).
        final hasHistory =
            store.enrollments.any((e) => e['studentId'] == s['id']) ||
            store.grades.any((g) => g['studentId'] == s['id']) ||
            store.tickets.any((t) => t['studentNumber'] == s['studentId']);
        if (hasHistory) {
          throw const FormatException('This student has enrollment, grade, or support history. Keep the record and update their status instead.');
        }
        await store.remove(AdminCollection.students, s, action: 'Deleted student ${s['fullName']}');
      },
      success: 'Student deleted',
      description: '${s['fullName']} has been removed from the directory.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final filtered = _filtered(store.students);
    final pages = (filtered.length / _pageSize).ceil();
    final page = _page.clamp(1, pages < 1 ? 1 : pages);
    final paginated = filtered.skip((page - 1) * _pageSize).take(_pageSize).toList();

    return AdminPage(
      onRefresh: store.refresh,
      children: [
        AdminPageHeader(
          title: 'Student Directory',
          description: 'Manage and view all student records',
          actions: [
            OutlinedButton.icon(onPressed: () => _export(filtered), icon: const Icon(Icons.download, size: 18), label: const Text('Export CSV')),
            FilledButton.icon(onPressed: () => _openForm(null), icon: const Icon(Icons.add, size: 18), label: const Text('Add Student')),
          ],
        ),
        FilterGrid(
          children: [
            SearchBox(hint: 'Search by name, ID, or email...', value: _search, onChanged: (v) => _set(() => _search = v)),
            FilterSelect(label: 'Program', allLabel: 'All Programs', value: _program, options: programOptions, onChanged: (v) => _set(() => _program = v)),
            FilterSelect(label: 'Year Level', allLabel: 'All Years', value: _year, options: yearLevelOptions, onChanged: (v) => _set(() => _year = v)),
            FilterSelect(label: 'Section', allLabel: 'All Sections', value: _section, options: store.sections, onChanged: (v) => _set(() => _section = v)),
            FilterSelect(label: 'Status', allLabel: 'All Statuses', value: _status, options: academicStatusOptions, onChanged: (v) => _set(() => _status = v)),
          ],
        ),
        if (_hasFilters)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() {
                _search = '';
                _program = _year = _section = _status = 'all';
                _page = 1;
              }),
              child: const Text('Clear filters'),
            ),
          ),
        const SizedBox(height: 12),
        AdminCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CardHeading('${filtered.length} student${filtered.length != 1 ? 's' : ''} found'),
              if (paginated.isEmpty) const Empty('No students found\nTry adjusting your search or filters.', icon: Icons.people_outline),
              for (final s in paginated) _StudentTile(student: s, onView: () => _openProfile(s), onEdit: () => _openForm(s), onDelete: () => _delete(s)),
              if (pages > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Page $page of $pages', style: const TextStyle(fontSize: 13, color: AppColors.adminMutedFg)),
                      ),
                      OutlinedButton(onPressed: page == 1 ? null : () => setState(() => _page = page - 1), child: const Text('Previous')),
                      const SizedBox(width: 8),
                      OutlinedButton(onPressed: page == pages ? null : () => setState(() => _page = page + 1), child: const Text('Next')),
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

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.student, required this.onView, required this.onEdit, required this.onDelete});
  final Map<String, dynamic> student;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = student;
    return InkWell(
      onTap: onView,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.adminBorder)),
        ),
        child: Row(
          children: [
            InitialsAvatar('${s['fullName']}', text: '${s['avatarInitials'] ?? initials('${s['fullName']}')}'),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${s['fullName']}', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                  Text(
                    '${s['email']}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.adminMutedFg),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${s['studentId']} · ${s['program']} · ${s['yearLevel']} · ${s['section']}',
                        style: const TextStyle(fontSize: 12, color: AppColors.adminMutedFg),
                      ),
                      StatusBadge('${s['academicStatus']}', dot: true),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Actions for ${s['fullName']}',
              onSelected: (v) => switch (v) {
                'view' => onView(),
                'edit' => onEdit(),
                _ => onDelete(),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'view', child: Text('View Profile')),
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: AppColors.adminDestructive)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Add/edit a student (admin/src/components/shared/StudentForm.tsx).
/// All fields are required; section must match the program and year level.
class StudentForm extends StatefulWidget {
  const StudentForm({super.key, this.student});
  final Map<String, dynamic>? student;

  @override
  State<StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends State<StudentForm> {
  static const _textFields = [
    ('studentId', 'Student ID', TextInputType.text),
    ('fullName', 'Full name', TextInputType.name),
    ('email', 'Email', TextInputType.emailAddress),
    ('contactNumber', 'Contact number', TextInputType.phone),
    ('address', 'Address', TextInputType.streetAddress),
    ('emergencyContact', 'Emergency contact', TextInputType.name),
    ('emergencyContactNumber', 'Emergency contact number', TextInputType.phone),
  ];
  static const _labels = {
    'studentId': 'Student ID',
    'fullName': 'Full name',
    'email': 'Email',
    'contactNumber': 'Contact number',
    'address': 'Address',
    'emergencyContact': 'Emergency contact',
    'emergencyContactNumber': 'Emergency contact number',
    'dateEnrolled': 'Date enrolled',
    'program': 'Program',
    'yearLevel': 'Year level',
    'section': 'Section',
    'academicStatus': 'Status',
  };

  late final Map<String, String> _form = {
    for (final key in _labels.keys) key: '${widget.student?[key] ?? ''}',
    if (widget.student == null) ...{'program': 'BSIT', 'yearLevel': '1st Year', 'section': 'BSIT 1A', 'academicStatus': 'Active', 'dateEnrolled': todayIso()},
  };
  late final Map<String, TextEditingController> _controllers = {for (final (key, _, _) in _textFields) key: TextEditingController(text: _form[key])};
  bool _submitted = false;
  bool _saving = false;
  String _error = '';

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> get _errors {
    final errors = <String, String>{};
    _labels.forEach((key, label) {
      if (_form[key]!.trim().isEmpty) errors[key] = '$label is required.';
    });
    if (!errors.containsKey('email') && !emailPattern.hasMatch(_form['email']!.trim())) {
      errors['email'] = 'Enter a valid email address, e.g. name@school.edu.';
    }
    return errors;
  }

  void _update(String key, String value, List<String> sections) => setState(() {
    _form[key] = value;
    if (key == 'program') {
      _form['yearLevel'] = yearLevelOptions.firstWhere((y) => sectionsFor(sections, value, y).isNotEmpty, orElse: () => _form['yearLevel']!);
    }
    if (key == 'program' || key == 'yearLevel') _form['section'] = '';
  });

  Future<void> _pickDate() async {
    final current = DateTime.tryParse(_form['dateEnrolled']!) ?? manilaNow();
    final picked = await showDatePicker(context: context, initialDate: current, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null) setState(() => _form['dateEnrolled'] = picked.toIso8601String().substring(0, 10));
  }

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _error = '';
    });
    if (_errors.isNotEmpty) return;
    final store = context.read<AdminStore>();
    final form = {for (final e in _form.entries) e.key: e.value.trim()};
    // Uniqueness and section rules from admin/src/data/transitions.ts.
    final others = store.students.where((s) => s['id'] != widget.student?['id']);
    if (others.any((s) => normalize('${s['studentId']}') == normalize(form['studentId']!) || normalize('${s['email']}') == normalize(form['email']!))) {
      setState(() => _error = 'Student ID and email must be unique.');
      return;
    }
    if (!form['section']!.startsWith('${form['program']} ${form['yearLevel']![0]}')) {
      setState(() => _error = 'Section must match the selected program and year level.');
      return;
    }
    setState(() => _saving = true);
    // The full record: existing fields kept, form fields replaced.
    final record = {...?widget.student, ...form, 'avatarInitials': initials(form['fullName']!)};
    final navigator = Navigator.of(context);
    final ok = await runChange(
      context,
      () => store.save(AdminCollection.students, record, action: '${widget.student != null ? 'Updated' : 'Added'} student ${form['fullName']}'),
      success: 'Student saved',
      onError: (message) => _error = message,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final sections = context.watch<AdminStore>().sections;
    final errors = _submitted ? _errors : const <String, String>{};
    final years = yearLevelOptions.where((y) => sectionsFor(sections, _form['program']!, y).isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Enter the student’s contact and academic information. All fields are required.',
          style: TextStyle(color: AppColors.adminMutedFg, fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (_error.isNotEmpty) AlertBox(_error),
        ResponsiveGrid(
          minItemWidth: 240,
          children: [
            for (final (key, label, type) in _textFields)
              TextField(
                key: Key('student-$key'),
                controller: _controllers[key],
                keyboardType: type,
                decoration: InputDecoration(labelText: label, errorText: errors[key]),
                onChanged: (v) => setState(() => _form[key] = v),
              ),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date enrolled',
                  errorText: errors['dateEnrolled'],
                  suffixIcon: const Icon(Icons.calendar_today, size: 18),
                ),
                child: Text(_form['dateEnrolled']!.isEmpty ? 'Select date' : formatDate(_form['dateEnrolled'])),
              ),
            ),
            SelectField(
              label: 'Program',
              value: _form['program'],
              options: programOptions,
              errorText: errors['program'],
              onChanged: (v) => _update('program', v!, sections),
            ),
            SelectField(
              fieldKey: ValueKey('year-${_form['program']}'),
              label: 'Year level',
              value: _form['yearLevel'],
              options: years,
              errorText: errors['yearLevel'],
              onChanged: (v) => _update('yearLevel', v!, sections),
            ),
            SelectField(
              fieldKey: ValueKey('section-${_form['program']}-${_form['yearLevel']}'),
              label: 'Section',
              value: _form['section'],
              options: sectionsFor(sections, _form['program']!, _form['yearLevel']!),
              errorText: errors['section'],
              onChanged: (v) => _update('section', v!, sections),
            ),
            SelectField(
              label: 'Status',
              value: _form['academicStatus'],
              options: academicStatusOptions,
              errorText: errors['academicStatus'],
              onChanged: (v) => _update('academicStatus', v!, sections),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          children: [
            OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            FilledButton(key: const Key('student-save'), onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save Student')),
          ],
        ),
      ],
    );
  }
}
