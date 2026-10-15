import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/pdf_docs.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/loader.dart';
import 'student_shell.dart';

const maxUnits = 24;

/// One catalog subject as shown on the page.
class CatalogSubject {
  CatalogSubject.fromJson(Map<String, dynamic> json)
    : code = json['code'] as String,
      title = json['title'] as String,
      units = json['units'] as num,
      passed = json['passed'] == true,
      description = (json['description'] as String?)?.isNotEmpty == true
          ? json['description'] as String
          : '${json['title']} (${num0(json['units'] as num)} units).',
      classes = asList(json['classes']),
      prerequisite = json['prerequisite'] as String?,
      prerequisiteMet = json['prerequisiteMet'] != false;

  final String code;
  final String title;
  final num units;
  final bool passed;
  final String description;
  final List<Map<String, dynamic>> classes;
  final String? prerequisite;
  final bool prerequisiteMet;

  String get category => code.startsWith('GE') ? 'General' : (code.startsWith('PE') ? 'PE' : 'Major');
  Color get categoryColor => switch (category) {
    'Major' => AppColors.blue500,
    'PE' => AppColors.amber500,
    _ => AppColors.emerald500,
  };
  String get schedule => classes.isEmpty
      ? 'Schedule to be announced'
      : classes.map((c) => '${shortDay('${c['day']}')} ${formatTime(c['startTime'] as String?)} - ${formatTime(c['endTime'] as String?)}').join(' / ');
  String get room => _unique('room', 'TBA');
  String get professor => _unique('instructor', 'TBA');
  String get capacity => classes.isEmpty ? 'Not offered for your section' : 'Offered for your section';
  String get prerequisiteText =>
      prerequisite == null || prerequisite!.isEmpty ? 'None' : '$prerequisite${prerequisiteMet ? ' (completed)' : ' (not yet passed)'}';

  String _unique(String key, String fallback) {
    final values = classes.map((c) => '${c[key]}').toSet();
    return values.isEmpty ? fallback : values.join(', ');
  }
}

/// frontend/src/pages/StudentEnrollment.jsx
class StudentEnrollmentPage extends StatefulWidget {
  const StudentEnrollmentPage({super.key, this.search = ''});

  /// Subject search from the top bar (?search=).
  final String search;

  @override
  State<StudentEnrollmentPage> createState() => _StudentEnrollmentPageState();
}

class _StudentEnrollmentPageState extends State<StudentEnrollmentPage> with ApiLoader {
  List<CatalogSubject> _catalog = [];
  Map<String, dynamic> _current = {};
  List<String>? _draftCodes;
  bool _submitting = false;
  String _actionError = '';
  late final _searchController = TextEditingController(text: widget.search);
  String _category = 'All';

  @override
  void didUpdateWidget(StudentEnrollmentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new top-bar search replaces the current filter.
    if (widget.search != oldWidget.search) _searchController.text = widget.search;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Future<void> fetch() async {
    final results = await Future.wait([api.get('/portal/subjects'), api.get('/portal/enrollment')]);
    _catalog = [for (final s in asList(results[0])) CatalogSubject.fromJson(s)];
    _current = asMap(results[1]) ?? {};
  }

  Map<String, dynamic>? get _enrollment => asMap(_current['enrollment']);
  Map<String, dynamic> get _period => asMap(_current['period']) ?? {};
  bool get _open => _current['enrollmentOpen'] == true;
  String get _periodLabel => 'AY ${_period['academicYear']} • ${_period['semester']}';

  /// Server status, or 'Draft' while (re)selecting subjects.
  String get _status => (_draftCodes != null || _enrollment == null) ? 'Draft' : '${_enrollment!['status']}';
  List<String> get _selectedCodes => _draftCodes ?? [for (final s in asList(_enrollment?['subjects'])) s['code'] as String];
  List<CatalogSubject> get _selected => _catalog.where((s) => _selectedCodes.contains(s.code)).toList();
  num get _totalUnits => _selected.fold<num>(0, (sum, s) => sum + s.units);

  void _toggle(CatalogSubject subject) {
    if (_status != 'Draft') return;
    setState(() {
      _actionError = '';
      final codes = _selectedCodes;
      if (codes.contains(subject.code)) {
        _draftCodes = codes.where((c) => c != subject.code).toList();
      } else if (subject.passed) {
        _actionError = 'You have already passed ${subject.code}.';
      } else if (_totalUnits + subject.units > maxUnits) {
        _actionError = 'You can enroll in at most $maxUnits units.';
      } else {
        _draftCodes = [...codes, subject.code];
      }
    });
  }

  Future<void> _submit() async {
    if (_selectedCodes.isEmpty) {
      setState(() => _actionError = 'Please select at least one subject before submitting.');
      return;
    }
    setState(() {
      _submitting = true;
      _actionError = '';
    });
    try {
      final data = await api.post('/portal/enrollment', {'subjectCodes': _selectedCodes});
      _current = {..._current, 'enrollment': data};
      _draftCodes = null;
    } catch (error) {
      _actionError = apiErrorMessage(error);
    }
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _withdraw() async {
    final ok = await confirmDialog(
      context,
      title: 'Withdraw request',
      message: 'Withdraw your pending enrollment request?',
      confirmLabel: 'Withdraw',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() {
      _submitting = true;
      _actionError = '';
    });
    try {
      final codes = _selectedCodes;
      await api.delete('/portal/enrollment');
      _draftCodes = codes;
      await fetch();
    } catch (error) {
      _actionError = apiErrorMessage(error);
    }
    if (mounted) setState(() => _submitting = false);
  }

  void _revise() => setState(() => _draftCodes = _selectedCodes);

  @override
  Widget build(BuildContext context) {
    if (loading) return const StudentPage(children: [Loading()]);
    if (loadError != null) {
      return StudentPage(
        children: [LoadError(message: loadError!, onRetry: () => reload(showSpinner: true))],
      );
    }
    final term = _searchController.text.toLowerCase();
    final filtered = _catalog.where((s) {
      final matchesSearch = s.code.toLowerCase().contains(term) || s.title.toLowerCase().contains(term) || s.professor.toLowerCase().contains(term);
      return matchesSearch && (_category == 'All' || s.category == _category);
    }).toList();
    final wide = MediaQuery.sizeOf(context).width >= 1100;

    final catalogPanel = Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResponsiveGrid(
            minItemWidth: 260,
            children: [
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 18), hintText: 'Search by code, title, or professor...'),
              ),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.filter_alt, size: 18)),
                items: [
                  DropdownMenuItem(value: 'All', child: Text('All Categories (${_catalog.length})')),
                  const DropdownMenuItem(value: 'Major', child: Text('Major Subjects')),
                  const DropdownMenuItem(value: 'General', child: Text('General Education')),
                  const DropdownMenuItem(value: 'PE', child: Text('Physical Education')),
                ],
                onChanged: (v) => setState(() => _category = v!),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty) const Empty('No subjects match your search.'),
          for (final sub in filtered) _subjectCard(sub),
        ],
      ),
    );

    return StudentPage(
      onRefresh: reload,
      children: [
        if (!_open && _status == 'Draft') AlertBox('Enrollment for $_periodLabel is currently closed by the Registrar.', type: AlertType.secondary),
        if (_actionError.isNotEmpty) AlertBox(_actionError),
        ..._banner(),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: catalogPanel),
              const SizedBox(width: 16),
              Expanded(child: _selectedPanel()),
            ],
          )
        else ...[
          _selectedPanel(),
          const SizedBox(height: 16),
          catalogPanel,
        ],
      ],
    );
  }

  List<Widget> _banner() {
    final status = _status;
    if (status == 'Approved') {
      return [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.emerald800, AppColors.emerald600, AppColors.emerald500]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(0x33FFFFFF),
                    child: Icon(Icons.check_circle, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your enrollment has been approved!',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        Text(
                          'Total Units: ${num0(_totalUnits)} Units • ${_selected.length} Subjects • $_periodLabel',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.success),
                onPressed: _showCor,
                icon: const Icon(Icons.description, size: 16),
                label: const Text('View Official COR'),
              ),
            ],
          ),
        ),
      ];
    }
    if (status == 'Pending') {
      return [
        _statusCard(
          color: AppColors.warning,
          icon: Icons.schedule,
          iconColor: AppColors.dark,
          title: 'Your enrollment application is pending review',
          message: 'The Office of the Registrar is evaluating your subjects and prerequisites. You will be notified once approved.',
          trailing: const Pill('Pending Approval', color: AppColors.warning, solid: true, fontSize: 12, dot: true),
        ),
      ];
    }
    if (status == 'Rejected') {
      final remarks = '${_enrollment?['remarks'] ?? ''}';
      return [
        _statusCard(
          color: AppColors.danger,
          icon: Icons.cancel,
          iconColor: Colors.white,
          title: 'Enrollment Application Returned / Rejected',
          titleColor: AppColors.danger,
          message: 'Registrar Remarks: ${remarks.isEmpty ? 'Please review your subjects.' : remarks}',
          trailing: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: _revise,
            child: const Text('Revise & Resubmit'),
          ),
        ),
      ];
    }
    return [];
  }

  Widget _statusCard({
    required Color color,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required Widget trailing,
    Color? titleColor,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      border: Border.all(color: color.withValues(alpha: 0.5)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color,
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: titleColor ?? AppColors.dark),
                  ),
                  const SizedBox(height: 2),
                  Text(message, style: const TextStyle(fontSize: 13, color: AppColors.dark)),
                ],
              ),
            ),
          ],
        ),
        trailing,
      ],
    ),
  );

  Widget _subjectCard(CatalogSubject sub) {
    final selected = _selectedCodes.contains(sub.code);
    final status = _status;
    Widget? action;
    if (selected && status == 'Approved') {
      action = const Pill('✓ Enrolled', color: AppColors.success, fontSize: 12);
    } else if (selected && status == 'Pending') {
      action = const Pill('Selected', color: AppColors.amber600, fontSize: 12);
    } else if (selected) {
      action = OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: const BorderSide(color: AppColors.danger),
        ),
        onPressed: () => _toggle(sub),
        icon: const Icon(Icons.delete, size: 14),
        label: const Text('Remove'),
      );
    } else if (sub.passed) {
      action = Tooltip(
        message: 'You already passed this subject',
        child: OutlinedButton(
          onPressed: null,
          child: Text('✓ Passed', style: TextStyle(color: AppColors.success.withValues(alpha: 0.7))),
        ),
      );
    } else if (status == 'Draft') {
      action = FilledButton.icon(onPressed: () => _toggle(sub), icon: const Icon(Icons.add, size: 14), label: const Text('Add'));
    }
    return AccentBox(
      margin: const EdgeInsets.only(bottom: 10),
      accent: sub.categoryColor,
      color: selected ? AppColors.pageBg : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CodeBadge(sub.code),
              Pill(sub.category, color: sub.categoryColor),
              Text(sub.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _meta(Icons.co_present, sub.professor),
              _meta(Icons.schedule, sub.schedule),
              _meta(Icons.place, sub.room),
              Text('• ${num0(sub.units)} Units', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(onPressed: () => _showDetails(sub), child: const Text('Details')),
              if (action != null) ...[const SizedBox(width: 8), action],
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: AppColors.muted),
      const SizedBox(width: 4),
      Flexible(
        child: Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      ),
    ],
  );

  Widget _selectedPanel() {
    final status = _status;
    final units = _totalUnits;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Selected Subjects', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              Pill('${_selected.length} subjects • ${num0(units)} units', color: AppColors.primary, solid: true),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text('Unit Capacity Load', style: TextStyle(color: AppColors.muted, fontSize: 11)),
              ),
              Text('${num0(units)} / $maxUnits Max Units', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: (units / maxUnits).clamp(0, 1).toDouble(), minHeight: 6, backgroundColor: AppColors.light),
          ),
          const SizedBox(height: 12),
          for (final sub in _selected)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.light,
                border: Border.all(color: AppColors.borderLight),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sub.code,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 13),
                        ),
                        Text(
                          sub.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Pill('${num0(sub.units)} u', color: AppColors.muted, solid: true),
                  if (status == 'Draft')
                    IconButton(
                      tooltip: 'Remove',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _toggle(sub),
                      icon: const Icon(Icons.close, color: AppColors.danger, size: 18),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          if (status == 'Draft')
            FilledButton(
              onPressed: _submitting || !_open ? null : _submit,
              child: Text(_submitting ? 'Submitting…' : (_enrollment?['status'] == 'Pending' ? 'Save Revised Application' : 'Submit Enrollment Application')),
            ),
          if (status == 'Pending') ...[
            FilledButton(
              onPressed: null,
              style: FilledButton.styleFrom(disabledBackgroundColor: AppColors.warning.withValues(alpha: 0.6), disabledForegroundColor: AppColors.dark),
              child: const Text('Pending Registrar Approval'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: _submitting || !_open ? null : _revise, child: const Text('Edit Subjects')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                    onPressed: _submitting ? null : _withdraw,
                    child: const Text('Withdraw Request'),
                  ),
                ),
              ],
            ),
          ],
          if (status == 'Approved')
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: _showCor,
              icon: const Icon(Icons.description, size: 16),
              label: const Text('View / Download Official COR'),
            ),
        ],
      ),
    );
  }

  void _showDetails(CatalogSubject sub) => showSheetDialog<void>(
    context,
    title: sub.title,
    titleWidget: Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        CodeBadge(sub.code),
        Text(sub.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    ),
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveGrid(
          minItemWidth: 200,
          children: [
            _detail('Subject Code', Text(sub.code, style: const TextStyle(fontWeight: FontWeight.bold))),
            _detail(
              'Credit Units',
              Text(
                '${num0(sub.units)} Academic Units',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
            _detail(
              'Category',
              Align(
                alignment: Alignment.centerLeft,
                child: Pill(sub.category, color: AppColors.primary),
              ),
            ),
            _detail('Instructor', Text(sub.professor, style: const TextStyle(fontWeight: FontWeight.bold))),
            _detail('Class Schedule', Text(sub.schedule)),
            _detail('Room Assignment', Text(sub.room)),
            _detail(
              'Class Capacity',
              Align(
                alignment: Alignment.centerLeft,
                child: Pill(sub.capacity, color: AppColors.muted, solid: true),
              ),
            ),
            _detail(
              'Prerequisite',
              Text(
                sub.prerequisiteText,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.light,
            border: Border.all(color: AppColors.borderLight),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Course Description',
                style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(sub.description, style: const TextStyle(color: AppColors.muted, height: 1.5)),
            ],
          ),
        ),
      ],
    ),
    actions: (context) => [OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
  );

  Widget _detail(String label, Widget value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
      const SizedBox(height: 2),
      value,
    ],
  );

  PrintableDoc _corDoc() {
    final user = context.read<Session>().user;
    final e = _enrollment ?? {};
    return PrintableDoc(
      title: 'COR - ${user?.studentId ?? ''}',
      subtitle: 'Office of the University Registrar • Student Records Division',
      badge: 'Official Certificate of Registration',
      info: [
        ('Student Name', user?.name ?? ''),
        ('Student ID', user?.studentId ?? ''),
        ('Degree Program', '${programName(e['program'] as String?)} (${e['program']})'),
        ('Year & Section', '${e['yearLevel']} • ${e['section']}'),
        ('Academic Term', _periodLabel),
        ('Status', 'OFFICIALLY ENROLLED'),
      ],
      sections: [
        DocSection(
          headers: const ['Subject Code', 'Subject Title', 'Units', 'Schedule', 'Room', 'Professor'],
          rows: [
            for (final s in _selected) [s.code, s.title, num0(s.units), s.schedule, s.room, s.professor],
          ],
          footer: ['', 'Total Academic Units:', num0(_totalUnits), '', '', ''],
        ),
      ],
      signatures: [(user?.name ?? '', "Student's Signature"), ('', 'University Registrar')],
    );
  }

  void _showCor() {
    final user = context.read<Session>().user;
    final e = _enrollment ?? {};
    showSheetDialog<void>(
      context,
      title: 'Official Certificate of Registration (COR)',
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: Text('🎓', style: TextStyle(fontSize: 30))),
          const Center(
            child: Text('EDUTRACK UNIVERSITY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1)),
          ),
          const Center(
            child: Text(
              'Office of the University Registrar • Student Records Division',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 6),
          const Center(child: CodeBadge('OFFICIAL CERTIFICATE OF REGISTRATION')),
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
                _kv('Student Name', user?.name ?? ''),
                _kv('Student ID', user?.studentId ?? ''),
                _kv('Degree Program', '${programName(e['program'] as String?)} (${e['program']})'),
                _kv('Year & Section', '${e['yearLevel']} • ${e['section']}'),
                _kv('Academic Term', _periodLabel),
                Row(
                  children: [
                    const Text('Status: ', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                    const Pill('OFFICIALLY ENROLLED', color: AppColors.success, solid: true),
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
                DataColumn(label: Text('Schedule')),
                DataColumn(label: Text('Room')),
                DataColumn(label: Text('Professor')),
              ],
              rows: [
                for (final s in _selected)
                  DataRow(
                    cells: [
                      DataCell(
                        Text(
                          s.code,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        ),
                      ),
                      DataCell(Text(s.title)),
                      DataCell(Text(num0(s.units), style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(s.schedule)),
                      DataCell(Text(s.room)),
                      DataCell(Text(s.professor)),
                    ],
                  ),
                DataRow(
                  cells: [
                    const DataCell(Text('')),
                    const DataCell(Text('Total Academic Units:', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(
                      Text(
                        num0(_totalUnits),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    const DataCell(Text('')),
                    const DataCell(Text('')),
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
            children: [_signature(user?.name ?? '', "Student's Signature"), _signature('', 'University Registrar')],
          ),
        ],
      ),
      actions: (context) => [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        FilledButton.icon(onPressed: () => _corDoc().print(), icon: const Icon(Icons.print, size: 16), label: const Text('Print / Save as PDF')),
      ],
    );
  }
}

Widget _kv(String label, String value) => Text.rich(
  TextSpan(
    style: const TextStyle(fontSize: 13),
    children: [
      TextSpan(
        text: '$label: ',
        style: const TextStyle(color: AppColors.muted),
      ),
      TextSpan(
        text: value,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ],
  ),
);

Widget _signature(String name, String caption) => SizedBox(
  width: 200,
  child: Column(
    children: [
      Container(
        width: 180,
        padding: const EdgeInsets.only(bottom: 4),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.dark)),
        ),
        child: Text(
          name.isEmpty ? ' ' : name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(height: 4),
      Text(caption, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
    ],
  ),
);

/// Shared by the transcript and schedule documents.
Widget kvText(String label, String value) => _kv(label, value);
Widget signatureLine(String name, String caption) => _signature(name, caption);
