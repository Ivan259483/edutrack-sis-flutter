// Admin business rules, ported from admin/src/lib/domain.ts and
// admin/src/data/transitions.ts so the app rejects the same input the web
// portal does (the API checks them again).

const programOptions = ['BSIT', 'BSBA', 'BSEd'];
const yearLevelOptions = ['1st Year', '2nd Year', '3rd Year', '4th Year'];
const academicStatusOptions = ['Active', 'On Leave', 'Graduated', 'Suspended'];
const semesterOptions = ['1st Semester', '2nd Semester', 'Summer'];
const announcementCategoryOptions = ['Academic', 'Enrollment', 'Event', 'General', 'Urgent'];
const targetAudienceOptions = ['All Students', 'Specific Program', 'Specific Year Level', 'Specific Section'];
const ticketCategoryOptions = ['Enrollment', 'Grades', 'Technical', 'General'];

/// admin/src/data/mock-data.ts `instructorOptions`.
const instructorOptions = ['Prof. Antonio Rivera', 'Prof. Maria Santos', 'Prof. Juan Dela Cruz', 'Prof. Cristina Lim', 'Prof. Rosario Mendoza'];

final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

String normalize(String value) => value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// "AY 2024-2025 · 1st Semester"
String periodLabel(Map<String, dynamic> settings) => 'AY ${settings['academicYear'] ?? ''} · ${settings['semester'] ?? ''}';

/// Sections offered for a program and year level, e.g. BSIT + 3rd Year -> BSIT 3A, BSIT 3B.
List<String> sectionsFor(List<String> sections, String program, String yearLevel) =>
    sections.where((s) => yearLevel.isNotEmpty && s.startsWith('$program ${yearLevel[0]}')).toList();

// ─── Grades ──────────────────────────────────────────────────────────

/// Parses a grade field: empty -> null; otherwise 1.00–5.00 with up to two decimals.
num? parseGrade(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) {
    throw const FormatException('Enter a numerical grade from 1.00 to 5.00, with up to two decimal places.');
  }
  final result = num.parse(text);
  if (!validGrade(result)) throw const FormatException('Grades must be between 1.00 and 5.00.');
  return result;
}

bool validGrade(Object? grade) => grade is num && grade.isFinite && grade >= 1 && grade <= 5;

String calculateRemark(num? grade) => grade == null ? 'Incomplete' : (grade <= 3 ? 'Passed' : 'Failed');

bool canPublishGrade(Map<String, dynamic> grade) => validGrade(grade['finalGrade']) && (grade['midtermGrade'] == null || validGrade(grade['midtermGrade']));

class TranscriptSummary {
  const TranscriptSummary(this.records, this.completedUnits, this.passedUnits, this.gpa);
  final List<Map<String, dynamic>> records;
  final num completedUnits;
  final num passedUnits;
  final double? gpa;
}

TranscriptSummary transcriptSummary(Iterable<Map<String, dynamic>> grades) {
  final records = grades.where((g) => g['publishStatus'] == 'Published' && canPublishGrade(g)).toList();
  num units(Iterable<Map<String, dynamic>> list) => list.fold<num>(0, (sum, g) => sum + (g['units'] as num));
  final completed = units(records);
  final passed = units(records.where((g) => (g['finalGrade'] as num) <= 3));
  final gpa = completed > 0 ? records.fold<num>(0, (sum, g) => sum + (g['finalGrade'] as num) * (g['units'] as num)) / completed : null;
  return TranscriptSummary(records, completed, passed, gpa?.toDouble());
}

// ─── Schedules ───────────────────────────────────────────────────────

/// "13:30" -> 810; NaN when not HH:MM.
double timeToMinutes(String? time) {
  final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(time ?? '');
  if (match == null) return double.nan;
  return int.parse(match[1]!) * 60.0 + int.parse(match[2]!);
}

bool classesOverlap(Map<String, dynamic> a, Map<String, dynamic> b) =>
    a['day'] == b['day'] &&
    timeToMinutes(a['startTime'] as String?) < timeToMinutes(b['endTime'] as String?) &&
    timeToMinutes(b['startTime'] as String?) < timeToMinutes(a['endTime'] as String?);

/// Which resources of [item] are double-booked: room, instructor, section.
List<String> scheduleConflicts(Map<String, dynamic> item, List<Map<String, dynamic>> schedules) {
  final overlapping = schedules.where((s) => s['id'] != item['id'] && classesOverlap(s, item)).toList();
  bool clash(String field) => overlapping.any((s) => normalize('${s[field]}') == normalize('${item[field]}'));
  return [if (clash('room')) 'room', if (clash('instructor')) 'instructor', if (clash('section')) 'section'];
}

/// Throws a [FormatException] with the web's message when [item] can't be saved.
void validateSchedule(Map<String, dynamic> item, List<Map<String, dynamic>> schedules) {
  if (![item['subjectCode'], item['section'], item['instructor'], item['day'], item['room']].every((v) => '${v ?? ''}'.trim().isNotEmpty)) {
    throw const FormatException('Complete all schedule fields.');
  }
  final start = timeToMinutes(item['startTime'] as String?), end = timeToMinutes(item['endTime'] as String?);
  if (!start.isFinite || !end.isFinite || start >= end) throw const FormatException('Start time must be before end time.');
  if (start < 420 || end > 1080) throw const FormatException('Classes must be within 07:00–18:00.');
  final reasons = scheduleConflicts(item, schedules);
  if (reasons.isNotEmpty) {
    throw FormatException('Schedule conflict: ${reasons.join(', ')} already booked on ${item['day']} at that time.');
  }
}

/// "BSIT 3A" -> BSIT
String programOfSection(String section) => section.startsWith('BSIT') ? 'BSIT' : (section.startsWith('BSBA') ? 'BSBA' : 'BSEd');

// ─── Enrollments ─────────────────────────────────────────────────────

List<Map<String, dynamic>> enrollmentSubjects(Map<String, dynamic> e) => [
  for (final s in (e['subjects'] as List? ?? const [])) Map<String, dynamic>.from(s as Map),
];

bool hasPrerequisiteConcerns(Map<String, dynamic> e) =>
    e['hasPrerequisiteConcerns'] == true || enrollmentSubjects(e).any((s) => s['hasPrerequisiteMet'] != true);

bool canIssueCor(Map<String, dynamic> e) => e['status'] == 'Approved';

/// The full enrollment record after an approve/reject decision.
Map<String, dynamic> transitionEnrollment(Map<String, dynamic> e, String status, {String remarks = '', bool override = false}) {
  if (e['status'] != 'Pending') throw const FormatException('Only pending enrollments can be reviewed.');
  if (status == 'Approved' && hasPrerequisiteConcerns(e) && !override) {
    throw const FormatException('Resolve prerequisite concerns or confirm an admin override.');
  }
  if (status == 'Rejected' && remarks.trim().isEmpty) throw const FormatException('Rejection remarks are required.');
  return {
    ...e,
    'status': status,
    'remarks': status == 'Rejected' ? remarks.trim() : '',
    'prerequisiteOverride': status == 'Approved' && hasPrerequisiteConcerns(e) && override,
  };
}

// ─── Announcements ───────────────────────────────────────────────────

/// Throws when the audience value doesn't belong to the chosen audience.
void validateTarget(String audience, String value, List<String> sections) {
  final allowed = switch (audience) {
    'All Students' => const ['All Students'],
    'Specific Program' => programOptions,
    'Specific Year Level' => yearLevelOptions,
    'Specific Section' => sections,
    _ => const <String>[],
  };
  if (!allowed.contains(value)) throw FormatException('Choose a valid value for ${audience.toLowerCase()}.');
}

// ─── Students ────────────────────────────────────────────────────────

/// Student Directory CSV export (admin `studentCsv`), with spreadsheet
/// formula injection neutralised.
String studentCsv(List<Map<String, dynamic>> students) {
  String cell(Object? value) {
    var text = '${value ?? ''}';
    if (RegExp(r'^[=+\-@\t\r]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  final rows = [
    ['Student ID', 'Name', 'Email', 'Program', 'Year Level', 'Section', 'Status'],
    for (final s in students) [s['studentId'], s['fullName'], s['email'], s['program'], s['yearLevel'], s['section'], s['academicStatus']],
  ];
  return '﻿${rows.map((row) => row.map(cell).join(',')).join('\r\n')}';
}

/// Message for a [FormatException] thrown by the rules above.
String ruleMessage(Object error) => error is FormatException ? error.message : '$error';
