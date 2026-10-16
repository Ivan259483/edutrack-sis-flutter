// Form rules shared by every screen. They mirror the EduTrack API
// (edutrack-sis backend/validators/index.js) and the web portals
// (frontend/src/services/validation.js, admin/src/lib/validation.ts), which
// enforce them again, so a message reads the same from either side.
// Each rule returns an error message, or null when the value is fine.

final namePattern = RegExp(r"^[\p{L}\p{M}]+(?:[ .'’-]+[\p{L}\p{M}]+)*\.?$", unicode: true);
final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
final phonePattern = RegExp(r'^\+?[0-9][0-9 ()-]{6,24}$');
final studentIdPattern = RegExp(r'^\d{4}-\d{5}$');
final roomPattern = RegExp(r'^[\p{L}\d][\p{L}\d .#-]*$', unicode: true);

/// Registration codes stay 5 digits (the API keeps them for this app); reset codes are 6.
const registrationCodeLength = 5;
const resetCodeLength = 6;
const resendSeconds = 60;

/// Records created at registration carry this until the student fills them in.
const notProvided = 'Not provided';

const passwordMessage =
    'Password must be at least 8 characters and include an uppercase letter, a lowercase letter, a number and a symbol.';

/// The live checklist under "new password" fields.
final passwordChecks = <(String, bool Function(String))>[
  ('At least 8 characters', (v) => v.length >= 8),
  ('An uppercase letter', (v) => RegExp('[A-Z]').hasMatch(v)),
  ('A lowercase letter', (v) => RegExp('[a-z]').hasMatch(v)),
  ('A number', (v) => RegExp(r'\d').hasMatch(v)),
  ('A symbol (e.g. ! @ # \$)', (v) => RegExp('[^A-Za-z0-9]').hasMatch(v)),
];

/// Trims and collapses inner spaces, as the API does.
String clean(String? value) => (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');

String? requiredField(String? value, String label) => clean(value).isEmpty ? '$label is required.' : null;

String? lengthBetween(String? value, String label, int min, int max) {
  final v = clean(value);
  if (v.isEmpty) return '$label is required.';
  return v.length < min || v.length > max ? '$label must be $min–$max characters.' : null;
}

/// Letters (including ñ and accents), spaces, hyphens, apostrophes and periods,
/// e.g. "Peñaflor", "Ma. Clara", "Dela Cruz".
String? personName(String? value, String label, {int max = 50}) {
  final v = clean(value);
  if (v.isEmpty) return '$label is required.';
  if (v.length < 2 || v.length > max) return '$label must be 2–$max characters.';
  return namePattern.hasMatch(v) ? null : '$label may only contain letters, spaces, hyphens, apostrophes and periods.';
}

/// Optional name-like text (e.g. "Relationship (optional)").
String? optionalName(String? value, String label, {int max = 60}) {
  final v = clean(value);
  if (v.isEmpty) return null;
  if (v.length < 2 || v.length > max) return '$label must be 2–$max characters.';
  return namePattern.hasMatch(v) ? null : '$label may only contain letters, spaces, hyphens, apostrophes and periods.';
}

String? email(String? value, {String label = 'Email'}) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return '$label is required.';
  if (v.length > 254) return '$label must be at most 254 characters.';
  if (emailPattern.hasMatch(v)) return null;
  return label == 'Email' ? 'Enter a valid email address.' : 'Enter a valid ${label.toLowerCase()} address.';
}

/// Phone numbers like 0917 123 4567 or +63 917 123 4567 (7–15 digits).
String? phone(String? value, String label, {bool allowPlaceholder = false}) {
  final v = clean(value);
  if (v.isEmpty) return '$label is required.';
  if (allowPlaceholder && v == notProvided) return null;
  final digits = v.replaceAll(RegExp(r'\D'), '').length;
  return phonePattern.hasMatch(v) && digits >= 7 && digits <= 15
      ? null
      : 'Enter a valid phone number for ${label.toLowerCase()}, e.g. 0917 123 4567.';
}

String? studentId(String? value) {
  final v = clean(value);
  if (v.isEmpty) return 'Student ID is required.';
  return studentIdPattern.hasMatch(v) ? null : 'Student ID must use the format YYYY-NNNNN, e.g. 2024-00115.';
}

/// YYYY-MM-DD, 1990 or later, not after [today] (also YYYY-MM-DD).
String? pastDate(String? value, String label, String today) {
  final v = clean(value);
  if (v.isEmpty) return '$label is required.';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v) || DateTime.tryParse(v) == null) return '$label must be a valid date (YYYY-MM-DD).';
  if (v.compareTo('1990-01-01') < 0) return '$label must be in 1990 or later.';
  return v.compareTo(today) > 0 ? '$label cannot be in the future.' : null;
}

/// Register, reset and change password (never login, so older accounts can still sign in).
String? strongPassword(String value) {
  if (value.isEmpty) return 'Password is required.';
  if (value.length > 128) return 'Password must be at most 128 characters.';
  return passwordChecks.every((c) => c.$2(value)) ? null : passwordMessage;
}

String? confirmPassword(String value, String password) {
  if (value.isEmpty) return 'Confirm your password.';
  return value == password ? null : 'Passwords do not match.';
}

String? digitsCode(String? value, int length) =>
    RegExp('^\\d{$length}\$').hasMatch((value ?? '').trim()) ? null : 'Enter the $length-digit code from your email.';

String? room(String? value) {
  final v = clean(value);
  if (v.isEmpty) return 'Room is required.';
  if (v.length > 30) return 'Room must be at most 30 characters.';
  return roomPattern.hasMatch(v) ? null : 'Room may only contain letters, numbers, spaces, periods, # and hyphens.';
}

/// Only the entries that carry a message.
Map<String, String> onlyErrors(Map<String, String?> errors) => {
  for (final e in errors.entries)
    if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
};
