import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../widgets/common.dart';
import '../admin_widgets.dart';
import '../data/admin_rules.dart';
import '../data/admin_store.dart';

/// Program colors of the schedule grid (Tailwind 100/300/800).
const _programColors = {
  'BSIT': (Color(0xFFDBEAFE), Color(0xFF93C5FD), Color(0xFF1E40AF)),
  'BSBA': (Color(0xFFDCFCE7), Color(0xFF86EFAC), Color(0xFF166534)),
  'BSEd': (Color(0xFFFEF3C7), Color(0xFFFCD34D), Color(0xFF92400E)),
};
const _conflictColors = (Color(0xFFFEE2E2), Color(0xFFF87171), Color(0xFF991B1B));

/// Weekly class grid with conflict detection; add, edit and delete classes
/// (admin/src/pages/ClassSchedulesPage.tsx).
class ClassSchedulesPage extends StatefulWidget {
  const ClassSchedulesPage({super.key});

  @override
  State<ClassSchedulesPage> createState() => _ClassSchedulesPageState();
}

class _ClassSchedulesPageState extends State<ClassSchedulesPage> {
  String _section = 'all';
  String _instructor = 'all';
  String _day = 'all';

  void _openForm(Map<String, dynamic>? editing) {
    showSheetDialog<void>(
      context,
      title: editing == null ? 'Add Class' : 'Edit Class',
      builder: (_) => _ClassForm(editing: editing),
    );
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete Class',
      message:
          'Are you sure you want to delete ${c['subjectCode']} (${c['subjectTitle']}) for ${c['section']} on ${c['day']}, ${c['startTime']}–${c['endTime']}? This action cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await runChange(
      context,
      () => context.read<AdminStore>().remove(AdminCollection.schedules, c, action: 'Deleted class ${c['subjectTitle']} for ${c['section']}'),
      success: 'Class deleted',
      description: '${c['subjectTitle']} for ${c['section']} on ${c['day']} has been removed.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final schedules = store.schedules;
    final filtered = schedules
        .where(
          (s) =>
              (_section == 'all' || s['section'] == _section) &&
              (_instructor == 'all' || s['instructor'] == _instructor) &&
              (_day == 'all' || s['day'] == _day),
        )
        .toList();
    final conflictIds = {
      for (final s in schedules)
        if (scheduleConflicts(s, schedules).isNotEmpty) s['id'],
    };
    final instructors = {...instructorOptions, for (final s in schedules) '${s['instructor']}'}.toList();

    return AdminPage(
      onRefresh: store.refresh,
      children: [
        AdminPageHeader(
          title: 'Class Schedules',
          description: '${periodLabel(store.settings)} · Weekly classes, 07:00–18:00',
          actions: [FilledButton.icon(onPressed: () => _openForm(null), icon: const Icon(Icons.add, size: 18), label: const Text('Add Class'))],
        ),
        if (conflictIds.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              border: Border.all(color: const Color(0xFFFECACA)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber, color: Color(0xFFDC2626), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scheduling Conflict Detected',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                      ),
                      Text(
                        '${conflictIds.length} class${conflictIds.length > 1 ? 'es have' : ' has'} a room or instructor conflict. Conflicting classes are highlighted in the schedule grid below.',
                        style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        FilterGrid(
          children: [
            FilterSelect(label: 'Section', allLabel: 'All Sections', value: _section, options: store.sections, onChanged: (v) => setState(() => _section = v)),
            FilterSelect(
              label: 'Instructor',
              allLabel: 'All Instructors',
              value: _instructor,
              options: instructors,
              onChanged: (v) => setState(() => _instructor = v),
            ),
            FilterSelect(label: 'Day', allLabel: 'All Days', value: _day, options: days, onChanged: (v) => setState(() => _day = v)),
          ],
        ),
        const SizedBox(height: 12),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CardHeading('Weekly Schedule', description: 'Color-coded by program, conflicts highlighted in red'),
              _WeekGrid(classes: filtered, conflictIds: conflictIds, onTap: _openForm),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CardHeading('Scheduled Classes (${filtered.length})'),
              if (filtered.isEmpty) const Empty('No classes found for the selected filters.', icon: Icons.calendar_month_outlined),
              for (final c in filtered) _ClassTile(cls: c, conflict: conflictIds.contains(c['id']), onEdit: () => _openForm(c), onDelete: () => _delete(c)),
            ],
          ),
        ),
      ],
    );
  }
}

/// 07:00–18:00 grid, one column per day; scrolls sideways on phones.
class _WeekGrid extends StatelessWidget {
  const _WeekGrid({required this.classes, required this.conflictIds, required this.onTap});
  final List<Map<String, dynamic>> classes;
  final Set<Object?> conflictIds;
  final void Function(Map<String, dynamic>) onTap;

  static const _hour = 60.0;
  static const _timeWidth = 52.0;
  static const _hours = 11; // 07:00 … 17:00 rows

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final dayWidth = ((constraints.maxWidth - _timeWidth) / 6).clamp(96.0, 200.0);
      final width = _timeWidth + dayWidth * 6;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: _timeWidth,
                    child: Text('Time', style: TextStyle(fontSize: 11, color: AppColors.adminMutedFg)),
                  ),
                  for (final day in days)
                    SizedBox(
                      width: dayWidth,
                      child: Text(
                        shortDay(day),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: _hours * _hour,
                child: Stack(
                  children: [
                    for (var i = 0; i < _hours; i++) ...[
                      Positioned(
                        top: i * _hour,
                        left: 0,
                        child: Text('${(7 + i).toString().padLeft(2, '0')}:00', style: const TextStyle(fontSize: 11, color: AppColors.adminMutedFg)),
                      ),
                      Positioned(
                        top: i * _hour,
                        left: _timeWidth,
                        right: 0,
                        child: Container(height: 1, color: AppColors.adminBorder),
                      ),
                    ],
                    for (final c in classes) _block(c, dayWidth),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _block(Map<String, dynamic> c, double dayWidth) {
    final dayIndex = days.indexOf('${c['day']}');
    final start = timeToMinutes(c['startTime'] as String?), end = timeToMinutes(c['endTime'] as String?);
    if (dayIndex < 0 || !start.isFinite || !end.isFinite) return const SizedBox.shrink();
    final conflict = conflictIds.contains(c['id']);
    final (bg, border, fg) = conflict ? _conflictColors : (_programColors[c['program']] ?? _programColors['BSIT']!);
    return Positioned(
      top: (start - 420) / 60 * _hour,
      left: _timeWidth + dayIndex * dayWidth + 2,
      width: dayWidth - 4,
      height: (end - start) / 60 * _hour - 4,
      child: Tooltip(
        message: '${c['subjectTitle']}\n${c['instructor']}\n${c['room']}\n${c['startTime']}-${c['endTime']}',
        child: InkWell(
          onTap: () => onTap(c),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: border, width: conflict ? 2 : 1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${c['subjectCode']}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
                  ),
                  Text('${c['section']}', style: TextStyle(fontSize: 10, color: fg.withValues(alpha: 0.8))),
                  Text(
                    '${c['room']}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: fg.withValues(alpha: 0.8)),
                  ),
                  if (conflict)
                    const Row(
                      children: [
                        Icon(Icons.warning_amber, size: 11, color: Color(0xFFB91C1C)),
                        SizedBox(width: 2),
                        Text(
                          'Conflict',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFB91C1C)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassTile extends StatelessWidget {
  const _ClassTile({required this.cls, required this.conflict, required this.onEdit, required this.onDelete});
  final Map<String, dynamic> cls;
  final bool conflict;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = cls;
    final (bg, _, fg) = _programColors[c['program']] ?? _programColors['BSIT']!;
    Widget meta(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.adminMutedFg),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(fontSize: 12, color: AppColors.adminMutedFg)),
      ],
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: conflict ? const Color(0xFFFEF2F2) : null,
        border: Border.all(color: conflict ? const Color(0xFFFECACA) : AppColors.adminBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.calendar_month_outlined, size: 20, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c['subjectTitle']}', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                Text('${c['subjectCode']} · ${c['section']}', style: const TextStyle(fontSize: 12, color: AppColors.adminMutedFg)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  runSpacing: 2,
                  children: [
                    meta(Icons.access_time, '${c['day']} ${c['startTime']}-${c['endTime']}'),
                    meta(Icons.place_outlined, '${c['room']}'),
                    meta(Icons.person_outline, '${c['instructor']}'),
                    if (conflict) const Tag('Conflict', bg: Color(0xFFFEE2E2), fg: Color(0xFF991B1B)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(tooltip: 'Edit class', onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 20)),
          IconButton(
            tooltip: 'Delete class',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.adminDestructive),
          ),
        ],
      ),
    );
  }
}

/// Add/edit a class. Rejects missing fields, bad times, times outside
/// 07:00–18:00 and room/instructor/section conflicts, like the web.
class _ClassForm extends StatefulWidget {
  const _ClassForm({this.editing});
  final Map<String, dynamic>? editing;

  @override
  State<_ClassForm> createState() => _ClassFormState();
}

class _ClassFormState extends State<_ClassForm> {
  late String? _subject = widget.editing?['subjectCode'] as String?;
  late String? _section = widget.editing?['section'] as String?;
  late String? _instructor = widget.editing?['instructor'] as String?;
  late String? _day = widget.editing?['day'] as String?;
  late String? _start = widget.editing?['startTime'] as String?;
  late String? _end = widget.editing?['endTime'] as String?;
  late final _room = TextEditingController(text: '${widget.editing?['room'] ?? ''}');
  String _error = '';
  bool _saving = false;

  @override
  void dispose() {
    _room.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool start) async {
    final current = (start ? _start : _end) ?? (start ? '08:00' : '09:00');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(current.substring(0, 2)), minute: int.parse(current.substring(3))),
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (picked == null) return;
    final value = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() => start ? _start = value : _end = value);
  }

  Future<void> _save(List<Map<String, dynamic>> subjects) async {
    setState(() => _error = '');
    if ([_subject, _section, _instructor, _day, _start, _end].any((v) => v == null || v.isEmpty) || _room.text.trim().isEmpty) {
      setState(() => _error = 'Missing fields: Please fill in all fields before saving.');
      return;
    }
    if (timeToMinutes(_end) <= timeToMinutes(_start)) {
      setState(() => _error = 'Invalid time: End time must be after start time.');
      return;
    }
    final store = context.read<AdminStore>();
    final subject = subjects.firstWhere((s) => s['code'] == _subject);
    // The full record: existing fields kept, form fields replaced.
    final record = {
      ...?widget.editing,
      'subjectCode': subject['code'],
      'subjectTitle': subject['title'],
      'section': _section,
      'program': programOfSection(_section!),
      'instructor': _instructor,
      'day': _day,
      'startTime': _start,
      'endTime': _end,
      'room': _room.text.trim(),
    };
    try {
      validateSchedule(record, store.schedules);
    } on FormatException catch (e) {
      setState(() => _error = 'Cannot save schedule: ${e.message}');
      return;
    }
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final editing = widget.editing != null;
    final ok = await runChange(
      context,
      () => store.save(AdminCollection.schedules, record, action: '${editing ? 'Updated' : 'Added'} class ${subject['title']} for $_section'),
      success: editing ? 'Class updated' : 'Class added',
      description: editing ? '${subject['title']} for $_section has been updated.' : '${subject['title']} for $_section has been scheduled.',
      onError: (message) => _error = message,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    // A class whose subject left the catalog stays selectable while editing it.
    final subjects = [
      ...store.subjects,
      if (widget.editing != null && !store.subjects.any((s) => s['code'] == widget.editing!['subjectCode']))
        {'code': widget.editing!['subjectCode'], 'title': widget.editing!['subjectTitle']},
    ];
    final instructors = {...instructorOptions, if (widget.editing != null) '${widget.editing!['instructor']}'}.toList();
    Widget timeField(String label, String? value, bool start) => InkWell(
      onTap: () => _pickTime(start),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.access_time, size: 18)),
        child: Text(value == null ? '--:--' : '$value  (${formatTime(value)})'),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.editing != null
              ? 'Update this class. Conflicts will be detected automatically.'
              : 'Schedule a new class. Conflicts will be detected automatically.',
          style: const TextStyle(color: AppColors.adminMutedFg, fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (_error.isNotEmpty) AlertBox(_error),
        SelectField(
          label: 'Subject',
          value: _subject,
          options: [for (final s in subjects) '${s['code']}'],
          labels: {for (final s in subjects) '${s['code']}': '${s['code']} - ${s['title']}'},
          onChanged: (v) => setState(() => _subject = v),
        ),
        const SizedBox(height: 12),
        ResponsiveGrid(
          minItemWidth: 220,
          children: [
            SelectField(label: 'Section', value: _section, options: store.sections, onChanged: (v) => setState(() => _section = v)),
            SelectField(label: 'Instructor', value: _instructor, options: instructors, onChanged: (v) => setState(() => _instructor = v)),
            SelectField(label: 'Day', value: _day, options: days, onChanged: (v) => setState(() => _day = v)),
            TextField(
              controller: _room,
              decoration: const InputDecoration(labelText: 'Room', hintText: 'e.g. Rm 401'),
            ),
            timeField('Start Time', _start, true),
            timeField('End Time', _end, false),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          children: [
            OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: _saving ? null : () => _save(subjects), child: Text(_saving ? 'Saving…' : 'Save Schedule')),
          ],
        ),
      ],
    );
  }
}
