import 'package:intl/intl.dart';

// Shared academic helpers (frontend/src/services/academic.js, admin/src/lib/domain.ts).

const programNames = {'BSIT': 'BS Information Technology', 'BSBA': 'BS Business Administration', 'BSEd': 'Bachelor of Secondary Education'};
const departments = {'BSIT': 'College of Computer Studies', 'BSBA': 'College of Business Administration', 'BSEd': 'College of Education'};
String programName(String? code) => programNames[code] ?? ((code == null || code.isEmpty) ? '—' : code);

const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

/// Current time in the Philippines (UTC+8, no daylight saving time).
DateTime manilaNow() => DateTime.now().toUtc().add(const Duration(hours: 8));
String todayName() => DateFormat('EEEE').format(manilaNow());

/// "YYYY-MM-DD" in Manila (admin `today()`).
String todayIso() => DateFormat('yyyy-MM-dd').format(manilaNow());

/// Parses the API's dates: "YYYY-MM-DD" (a Manila calendar day), ISO timestamps,
/// or "YYYY-MM-DD HH:mm" (Manila time). Returns the moment shifted to Manila
/// wall-clock fields, or null.
DateTime? _manila(String? value) {
  if (value == null || value.isEmpty) return null;
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return DateTime.tryParse('${value}T12:00:00Z');
  final iso = value.contains('T') ? value : '${value.replaceFirst(' ', 'T')}+08:00';
  final parsed = DateTime.tryParse(iso);
  return parsed?.toUtc().add(const Duration(hours: 8));
}

/// "Oct 12, 2026" in Manila time; "—" when empty.
String formatDate(String? value) {
  final date = _manila(value);
  if (date == null) return (value == null || value.isEmpty) ? '—' : value;
  return DateFormat('MMM d, y').format(date);
}

/// "13:30" -> "1:30 PM"
String formatTime(String? time) {
  if (time == null || time.isEmpty) return '';
  final parts = time.split(':').map(int.parse).toList();
  final h = parts[0], m = parts[1];
  return '${((h + 11) % 12) + 1}:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}

/// Hours as a decimal: "13:30" -> 13.5
double toHours(String time) {
  final parts = time.split(':').map(int.parse).toList();
  return parts[0] + parts[1] / 60;
}

String formatGrade(Object? value) => value is num ? value.toStringAsFixed(2) : '—';

class GradeSummary {
  const GradeSummary(this.gpa, this.units, this.earned, this.count);
  final double? gpa;
  final num units;
  final num earned;
  final int count;
}

/// Weighted GPA over published, complete grades (1.00 is highest).
GradeSummary gradeSummary(List<dynamic> grades) {
  final complete = grades.where((g) => g['finalGrade'] is num).toList();
  final num units = complete.fold<num>(0, (sum, g) => sum + (g['units'] as num));
  final num earned = complete.where((g) => (g['finalGrade'] as num) <= 3).fold<num>(0, (sum, g) => sum + (g['units'] as num));
  final gpa = units > 0 ? complete.fold<num>(0, (sum, g) => sum + (g['finalGrade'] as num) * (g['units'] as num)) / units : null;
  return GradeSummary(gpa?.toDouble(), units, earned, complete.length);
}

/// "Juan Dela Cruz" -> "JD"
String initials(String name) => name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join().toUpperCase();

/// "Monday" -> "Mon"
String shortDay(String day) => day.length >= 3 ? day.substring(0, 3) : day;

/// Formats whole numbers without decimals: 3 -> "3", 3.5 -> "3.5".
String num0(num value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();
