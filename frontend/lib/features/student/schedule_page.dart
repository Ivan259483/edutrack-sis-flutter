import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/pdf_docs.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/loader.dart';
import 'student_shell.dart';

const _palette = [
  (color: Color(0xFF3B82F6), border: Color(0xFF2563EB)),
  (color: Color(0xFF10B981), border: Color(0xFF059669)),
  (color: Color(0xFF8B5CF6), border: Color(0xFF7C3AED)),
  (color: Color(0xFFF59E0B), border: Color(0xFFD97706)),
  (color: Color(0xFFEF4444), border: Color(0xFFDC2626)),
  (color: Color(0xFFEC4899), border: Color(0xFFDB2777)),
];

/// One class meeting pattern; the same class on several days is merged.
class ClassEntry {
  ClassEntry({
    required this.code,
    required this.title,
    required this.units,
    required this.section,
    required this.room,
    required this.instructor,
    required this.days,
    required this.start,
    required this.end,
    required this.color,
    required this.border,
  });
  final String code;
  final String title;
  final num units;
  final String section;
  final String room;
  final String instructor;
  final List<String> days;
  final String start;
  final String end;
  final Color color;
  final Color border;

  double get startHour => toHours(start);
  double get durationHours => ((toHours(end) - toHours(start)) * 10).round() / 10;
  String get time => '${formatTime(start)} – ${formatTime(end)}';
}

/// frontend/src/pages/StudentSchedule.jsx
class StudentSchedulePage extends StatefulWidget {
  const StudentSchedulePage({super.key});

  @override
  State<StudentSchedulePage> createState() => _StudentSchedulePageState();
}

class _StudentSchedulePageState extends State<StudentSchedulePage> with ApiLoader {
  List<Map<String, dynamic>> _schedule = [];
  Map<String, num> _units = {};
  Map<String, dynamic> _period = {};
  String _view = 'grid';
  String _dayFilter = 'All';

  @override
  Future<void> fetch() async {
    final results = await Future.wait([api.get('/portal/schedule'), api.get('/subjects?limit=500'), api.get('/portal/enrollment')]);
    _schedule = asList(results[0]);
    _units = {for (final s in asList(asMap(results[1])?['items'])) '${s['code']}': s['units'] as num};
    _period = asMap(asMap(results[2])?['period']) ?? {};
  }

  String get _term => _period.isEmpty ? 'Current term' : '${_period['semester']} ${_period['academicYear']} (Current)';

  List<ClassEntry> get _entries {
    final groups = <String, Map<String, dynamic>>{};
    for (final c in _schedule) {
      final key = [c['subjectCode'], c['startTime'], c['endTime'], c['room'], c['instructor']].join('|');
      groups.putIfAbsent(key, () => {...c, 'days': <String>[]});
      (groups[key]!['days'] as List<String>).add('${c['day']}');
    }
    final list = groups.values.toList()..sort((a, b) => '${a['subjectCode']}'.compareTo('${b['subjectCode']}'));
    return [
      for (final (i, c) in list.indexed)
        ClassEntry(
          code: '${c['subjectCode']}',
          title: '${c['subjectTitle']}',
          units: _units['${c['subjectCode']}'] ?? 3,
          section: '${c['section']}',
          room: '${c['room']}',
          instructor: '${c['instructor']}',
          days: (c['days'] as List<String>)..sort((a, b) => days.indexOf(a).compareTo(days.indexOf(b))),
          start: '${c['startTime']}',
          end: '${c['endTime']}',
          color: _palette[i % _palette.length].color,
          border: _palette[i % _palette.length].border,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const StudentPage(dark: true, children: [Loading()]);
    if (loadError != null) {
      return StudentPage(
        dark: true,
        children: [LoadError(message: loadError!, onRetry: () => reload(showSpinner: true))],
      );
    }
    final profile = context.watch<Session>().user?.profile;
    final entries = _entries;
    final weeklyHours = _schedule.fold<double>(0, (sum, c) => sum + toHours('${c['endTime']}') - toHours('${c['startTime']}'));
    final classDays = _schedule.map((c) => c['day']).toSet().length;
    // Same rule the API uses when saving schedules: same day and overlapping times.
    var conflicts = 0;
    for (var i = 0; i < _schedule.length; i++) {
      final a = _schedule[i];
      final overlaps = _schedule
          .skip(i + 1)
          .any(
            (b) =>
                a['day'] == b['day'] && toHours('${a['startTime']}') < toHours('${b['endTime']}') && toHours('${b['startTime']}') < toHours('${a['endTime']}'),
          );
      if (overlaps) conflicts++;
    }
    final totalUnits = entries.fold<num>(0, (sum, e) => sum + e.units);
    final section = profile?['section'] ?? (_schedule.isNotEmpty ? _schedule.first['section'] : null) ?? '—';

    return StudentPage(
      dark: true,
      onRefresh: reload,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Class Schedule & Timetable',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Current term (schedules are kept for the current term only)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.slate800,
                    border: Border.all(color: AppColors.muted),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_term, style: const TextStyle(color: Color(0xFFF8F9FA), fontSize: 13)),
                ),
                _viewToggle(),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.blue500,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  onPressed: () => _showPrint(entries, totalUnits, profile),
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('Print Official Schedule'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          minItemWidth: 220,
          children: [
            StatCard(
              dark: true,
              icon: Icons.menu_book,
              color: AppColors.primary,
              background: AppColors.primary.withValues(alpha: 0.1),
              label: 'Enrolled Subjects',
              value: Text('${entries.length} Subjects'),
              caption: '${num0(totalUnits)}.0 Total Academic Units',
            ),
            StatCard(
              dark: true,
              icon: Icons.schedule,
              color: AppColors.success,
              background: AppColors.success.withValues(alpha: 0.1),
              label: 'Weekly Class Hours',
              value: Text('${weeklyHours.toStringAsFixed(1)} Hrs'),
              caption: 'Across $classDays day(s)',
            ),
            StatCard(
              dark: true,
              icon: Icons.check_circle,
              color: AppColors.info,
              background: AppColors.info.withValues(alpha: 0.1),
              label: 'Schedule Verification',
              value: Text(
                conflicts > 0 ? '$conflicts Conflict(s)' : 'Conflict-Free',
                style: TextStyle(color: conflicts > 0 ? AppColors.danger : AppColors.success, fontSize: 18),
              ),
              caption: conflicts > 0 ? 'Overlapping class times found' : 'No overlapping class times',
            ),
            StatCard(
              dark: true,
              icon: Icons.school,
              color: AppColors.warning,
              background: AppColors.warning.withValues(alpha: 0.1),
              label: 'Assigned Section',
              value: Text('$section', style: const TextStyle(color: AppColors.blue500, fontSize: 18)),
              caption: departments[profile?['program']] ?? '',
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_view == 'grid') _grid(entries) else _list(entries),
      ],
    );
  }

  Widget _viewToggle() => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: AppColors.slate800,
      border: Border.all(color: AppColors.slate700),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (value, label, icon) in [('grid', 'Timetable Grid', Icons.calendar_view_week), ('list', 'Subject List', Icons.list)])
          Material(
            color: _view == value ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            child: InkWell(
              borderRadius: BorderRadius.circular(7),
              onTap: () => setState(() => _view = value),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    Icon(icon, size: 14, color: _view == value ? Colors.white : AppColors.slate400),
                    const SizedBox(width: 6),
                    Text(label, style: TextStyle(color: _view == value ? Colors.white : AppColors.slate400, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _darkCard({required Widget header, required Widget child}) => Container(
    decoration: BoxDecoration(color: AppColors.slate800, borderRadius: BorderRadius.circular(16)),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x406C757D))),
          ),
          child: header,
        ),
        child,
      ],
    ),
  );

  // VIEW 1: weekly timetable grid (07:00 AM to 06:00 PM)
  Widget _grid(List<ClassEntry> entries) {
    const slotHeight = 70.0;
    const timeColumn = 90.0;
    const totalWidth = 920.0;
    const dayWidth = (totalWidth - timeColumn) / 6;
    const hours = [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18];
    String label(int h) => '${(((h + 11) % 12) + 1).toString().padLeft(2, '0')}:00 ${h < 12 ? 'AM' : 'PM'}';
    return _darkCard(
      header: const Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.calendar_month, color: AppColors.primary, size: 18),
          Text(
            'Weekly Academic Timetable Matrix',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          Text('Tap any subject card to view classroom and instructor details', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalWidth,
          child: Column(
            children: [
              Container(
                color: AppColors.slate900,
                child: Row(
                  children: [
                    const SizedBox(
                      width: timeColumn,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'TIME',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                    for (final day in days)
                      SizedBox(
                        width: dayWidth,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            day.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFFF8F9FA), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: hours.length * slotHeight,
                child: Stack(
                  children: [
                    for (final (i, h) in hours.indexed)
                      Positioned(
                        top: i * slotHeight,
                        left: 0,
                        right: 0,
                        height: slotHeight,
                        child: Row(
                          children: [
                            Container(
                              width: timeColumn,
                              color: AppColors.slate900,
                              alignment: Alignment.center,
                              child: Text(label(h), style: const TextStyle(color: AppColors.slate400, fontSize: 11)),
                            ),
                            Expanded(
                              child: Container(
                                decoration: const BoxDecoration(
                                  border: Border(bottom: BorderSide(color: Color(0x406C757D))),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    for (final cls in entries)
                      for (final day in cls.days)
                        if (days.contains(day))
                          Positioned(
                            top: (cls.startHour - 7) * slotHeight + 2,
                            left: timeColumn + days.indexOf(day) * dayWidth + 3,
                            width: dayWidth - 6,
                            height: cls.durationHours * slotHeight - 4,
                            child: GestureDetector(
                              onTap: () => _showClass(cls),
                              child: AccentBox(
                                accent: cls.border,
                                fillHeight: true,
                                radius: 8,
                                padding: const EdgeInsets.all(8),
                                color: Color.alphaBlend(cls.color.withValues(alpha: 0.15), AppColors.slate800),
                                borderColor: cls.border.withValues(alpha: 0.27),
                                // Short classes show what fits; the details dialog has everything.
                                child: SingleChildScrollView(
                                  physics: const NeverScrollableScrollPhysics(),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cls.code,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Text(
                                        cls.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Color(0xFFF8F9FA), fontSize: 11),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${formatTime(cls.start)} - ${formatTime(cls.end)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: AppColors.slate400, fontSize: 10),
                                      ),
                                      Text(
                                        cls.room,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: AppColors.slate400, fontSize: 10),
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
            ],
          ),
        ),
      ),
    );
  }

  // VIEW 2: subject list with day filter
  Widget _list(List<ClassEntry> entries) {
    final filtered = _dayFilter == 'All' ? entries : entries.where((e) => e.days.contains(_dayFilter)).toList();
    return _darkCard(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.list, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'Enrolled Subjects Schedule Directory',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final day in ['All', ...days])
                ChoiceChip(
                  label: Text(day, style: TextStyle(fontSize: 12, color: _dayFilter == day ? Colors.white : const Color(0xFFF8F9FA))),
                  selected: _dayFilter == day,
                  showCheckmark: false,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.slate800,
                  side: BorderSide(color: _dayFilter == day ? AppColors.primary : AppColors.muted),
                  onSelected: (_) => setState(() => _dayFilter = day),
                ),
            ],
          ),
        ],
      ),
      child: Column(
        children: [
          if (filtered.isEmpty) const Empty('No classes on this day.'),
          for (final item in filtered)
            InkWell(
              onTap: () => _showClass(item),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.slate700)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 54,
                      decoration: BoxDecoration(color: item.color, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.code,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          Text(item.title, style: const TextStyle(color: AppColors.slate400, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            '${item.days.join(' / ')} • ${item.time}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Text('${item.room} • ${item.instructor} • ${item.section}', style: const TextStyle(color: AppColors.slate400, fontSize: 11)),
                        ],
                      ),
                    ),
                    Text(
                      '${num0(item.units)}.0',
                      style: const TextStyle(color: Color(0xFFF8F9FA), fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFF8F9FA)),
                      ),
                      onPressed: () => _showClass(item),
                      child: const Text('Details'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showClass(ClassEntry cls) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppColors.slate800,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: cls.border, width: 6)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Pill(cls.code, color: cls.color),
                          const SizedBox(height: 4),
                          Text(
                            cls.title,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _box('Class Section', Text(cls.section, style: _boxValue))),
                        const SizedBox(width: 10),
                        Expanded(child: _box('Academic Units', Text('${num0(cls.units)}.0 Units', style: _boxValue))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _box(
                      'Schedule & Days',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cls.days.join(' & '), style: _boxValue),
                          Text('${cls.time} (${cls.durationHours} Hours)', style: const TextStyle(color: AppColors.slate400, fontSize: 12)),
                        ],
                      ),
                      icon: Icons.schedule,
                      iconColor: AppColors.primary,
                    ),
                    const SizedBox(height: 10),
                    _box(
                      'Classroom Venue',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cls.room, style: _boxValue),
                          const Text('Campus Main Wing • Air-conditioned Laboratory & Facilities', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
                        ],
                      ),
                      icon: Icons.place,
                      iconColor: AppColors.danger,
                    ),
                    const SizedBox(height: 10),
                    _box(
                      'Assigned Faculty',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cls.instructor, style: _boxValue),
                          const Text('Contact via Help and Support', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
                        ],
                      ),
                      icon: Icons.co_present,
                      iconColor: AppColors.success,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.muted),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close Details'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  static const _boxValue = TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15);

  Widget _box(String label, Widget child, {IconData? icon, Color? iconColor}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.dark,
      border: Border.all(color: const Color(0x406C757D)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: iconColor), const SizedBox(width: 6)],
            Text(label, style: const TextStyle(color: AppColors.slate400, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        child,
      ],
    ),
  );

  void _showPrint(List<ClassEntry> entries, num totalUnits, Map<String, dynamic>? profile) {
    final user = context.read<Session>().user;
    final program = programName(profile?['program'] as String?);
    final yearSection = '${profile?['yearLevel'] ?? ''} — Section ${profile?['section'] ?? ''}';
    final doc = PrintableDoc(
      title: 'Class Schedule - ${user?.studentId ?? ''}',
      subtitle: 'Office of the University Registrar & Admissions',
      badge: 'Official Certificate of Student Class Schedule',
      info: [
        ('Student Name', user?.name ?? ''),
        ('Student ID Number', user?.studentId ?? ''),
        ('Degree Program', program),
        ('Year Level & Section', yearSection),
        ('Academic Term', _term),
      ],
      sections: [
        DocSection(
          headers: const ['Subject Code', 'Subject Description', 'Units', 'Days', 'Time', 'Room', 'Instructor'],
          rows: [
            for (final e in entries)
              [e.code, e.title, '${num0(e.units)}.0', e.days.join(', '), '${formatTime(e.start)} - ${formatTime(e.end)}', e.room, e.instructor],
          ],
          footer: ['', 'Total Academic Load:', '${num0(totalUnits)}.0 Units', '', '', '', 'Status: Officially Validated'],
        ),
      ],
      signatures: [('', 'University Registrar'), (user?.name ?? '', 'Student Signature')],
    );
    doc.print();
  }
}
