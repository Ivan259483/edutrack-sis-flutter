import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/pdf_docs.dart';
import '../../core/theme.dart';
import '../../core/validation.dart';
import '../../widgets/common.dart';
import '../../widgets/loader.dart';
import '../../widgets/password_checklist.dart';
import 'student_shell.dart';

/// "Not provided" is the placeholder stored for new registrations.
String _shown(Object? value) => (value is String && value.isNotEmpty && value != 'Not provided') ? value : '—';

/// frontend/src/pages/StudentProfile.jsx
class StudentProfilePage extends StatefulWidget {
  const StudentProfilePage({super.key, this.section});

  /// "security" opens the page at the Account Security card (account menu "Settings").
  final String? section;

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> with ApiLoader {
  Map<String, dynamic> _student = {};
  Map<String, dynamic> _enrollment = {};
  bool _editing = false;
  bool _saved = false;
  final _securityKey = GlobalKey();

  @override
  Future<void> fetch() async {
    final results = await Future.wait([api.get('/portal/profile'), api.get('/portal/enrollment')]);
    _student = asMap(results[0]) ?? {};
    _enrollment = asMap(results[1]) ?? {};
  }

  @override
  Future<void> reload({bool showSpinner = false}) async {
    await super.reload(showSpinner: showSpinner);
    if (widget.section == 'security') _scrollToSecurity();
  }

  @override
  void didUpdateWidget(StudentProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.section == 'security' && oldWidget.section != 'security') _scrollToSecurity();
  }

  void _scrollToSecurity() => WidgetsBinding.instance.addPostFrameCallback((_) {
    final target = _securityKey.currentContext;
    if (target != null) Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 400), alignment: 0.05);
  });

  String get _enrollmentStatus {
    final current = asMap(_enrollment['enrollment']);
    if (current == null) return 'Not Enrolled';
    return current['status'] == 'Approved' ? 'Enrolled' : 'Enrollment ${current['status']}';
  }

  PrintableDoc _profileDoc() => PrintableDoc(
    title: 'Student Profile - ${_student['studentId']}',
    subtitle: 'Office of the University Registrar • Student Records Division',
    badge: 'Student Profile',
    info: [
      ('Student Name', '${_student['fullName']}'),
      ('Student ID', '${_student['studentId']}'),
      ('Degree Program', programName(_student['program'] as String?)),
      ('Year & Section', '${_student['yearLevel']} - ${_student['section']}'),
      ('Academic Status', '${_student['academicStatus']}'),
      ('Enrollment', _enrollmentStatus),
    ],
    sections: [
      DocSection(
        heading: 'General Information',
        rows: [
          ['Full Legal Name', '${_student['fullName']}'],
          ['Date of Birth', _dob],
          ['Gender', _shown(_student['gender'])],
          ['Civil Status', _shown(_student['civilStatus'])],
          ['Nationality', _shown(_student['nationality'])],
        ],
      ),
      DocSection(
        heading: 'Contact Information',
        rows: [
          ['Institutional Email', '${_student['email']}'],
          ['Personal Email', _shown(_student['personalEmail'])],
          ['Mobile Number', _shown(_student['contactNumber'])],
          ['Residential Address', _shown(_student['address'])],
        ],
      ),
      DocSection(
        heading: 'Emergency Contact',
        rows: [
          ['Guardian / Contact Person', _shown(_student['emergencyContact'])],
          ['Relationship', _shown(_student['guardianRelationship'])],
          ['Emergency Hotline / Phone', _shown(_student['emergencyContactNumber'])],
        ],
      ),
      DocSection(
        heading: 'Academic Information',
        rows: [
          ['College Department', departments[_student['program']] ?? '—'],
          ['Degree Program', programName(_student['program'] as String?)],
          ['Year & Section', '${_student['yearLevel']} - ${_student['section']}'],
          ['Academic Status', '${_student['academicStatus']}'],
        ],
      ),
    ],
  );

  String get _dob {
    final value = _student['dateOfBirth'] as String?;
    return (value == null || value.isEmpty) ? '—' : formatDate(value);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const StudentPage(children: [Loading()]);
    if (loadError != null) {
      return StudentPage(
        children: [LoadError(message: loadError!, onRetry: () => reload(showSpinner: true))],
      );
    }
    final s = _student;
    return StudentPage(
      onRefresh: reload,
      children: [
        // 1. Profile header card
        Panel(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      '${s['avatarInitials'] ?? initials('${s['fullName']}')}',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${s['fullName']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Pill(_enrollmentStatus, color: AppColors.success, dot: true),
                            Pill('${s['academicStatus']}', color: AppColors.primary),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(
                            style: const TextStyle(color: AppColors.muted, fontSize: 13),
                            children: [
                              const TextSpan(text: 'Student ID: '),
                              TextSpan(
                                text: '${s['studentId']}',
                                style: const TextStyle(color: AppColors.dark, fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: ' • ${programName(s['program'] as String?)} (${s['section']})'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!_editing)
                    FilledButton.icon(
                      onPressed: () => setState(() {
                        _saved = false;
                        _editing = true;
                      }),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit Contact Details'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _profileDoc().print(),
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('Print Profile'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_saved) const AlertBox('Your contact details have been updated.', type: AlertType.success),
        if (_editing) ...[
          EditContactForm(
            student: s,
            onCancel: () => setState(() => _editing = false),
            onSaved: (updated) => setState(() {
              _student = updated;
              _editing = false;
              _saved = true;
            }),
          ),
          const SizedBox(height: 16),
        ],
        // 2. Four information cards
        ResponsiveGrid(
          minItemWidth: 380,
          spacing: 16,
          children: [
            Panel(
              child: Column(
                children: [
                  const PanelTitle('General Information', icon: Icons.person),
                  InfoRow('Full Legal Name', '${s['fullName']}'),
                  InfoRow('Date of Birth', _dob),
                  InfoRow('Gender', _shown(s['gender'])),
                  InfoRow('Civil Status', _shown(s['civilStatus'])),
                  InfoRow('Nationality', _shown(s['nationality']), last: true),
                ],
              ),
            ),
            Panel(
              child: Column(
                children: [
                  const PanelTitle('Contact Information', icon: Icons.email),
                  InfoRow('Institutional Email', '${s['email']}'),
                  InfoRow('Personal Email', _shown(s['personalEmail'])),
                  InfoRow('Mobile Number', _shown(s['contactNumber'])),
                  InfoRow('Residential Address', _shown(s['address']), last: true),
                ],
              ),
            ),
            Panel(
              child: Column(
                children: [
                  const PanelTitle('Emergency Contact', icon: Icons.monitor_heart, iconColor: AppColors.danger),
                  InfoRow('Guardian / Contact Person', _shown(s['emergencyContact'])),
                  InfoRow('Relationship', _shown(s['guardianRelationship'])),
                  InfoRow('Emergency Hotline / Phone', _shown(s['emergencyContactNumber']), last: true),
                ],
              ),
            ),
            Panel(
              child: Column(
                children: [
                  const PanelTitle('Academic Information', icon: Icons.school, iconColor: AppColors.success),
                  InfoRow('College Department', departments[s['program']] ?? '—'),
                  InfoRow('Degree Program', programName(s['program'] as String?)),
                  InfoRow('Year & Section', '${s['yearLevel']} - ${s['section']}'),
                  InfoRow('Academic Status', '', last: true, valueWidget: Pill('${s['academicStatus']}', color: AppColors.primary)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'You can update your contact details above. To correct your name, student ID or academic information, open a ticket in Help and Support.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        ChangePasswordCard(key: _securityKey),
      ],
    );
  }
}

/// Contact fields a student may change (PUT /api/portal/profile).
class EditContactForm extends StatefulWidget {
  const EditContactForm({super.key, required this.student, required this.onSaved, required this.onCancel});
  final Map<String, dynamic> student;
  final ValueChanged<Map<String, dynamic>> onSaved;
  final VoidCallback onCancel;

  @override
  State<EditContactForm> createState() => _EditContactFormState();
}

const _contactFields = [
  (name: 'contactNumber', label: 'Mobile Number', max: 30, keyboard: TextInputType.phone),
  (name: 'personalEmail', label: 'Personal Email (optional)', max: 254, keyboard: TextInputType.emailAddress),
  (name: 'address', label: 'Residential Address', max: 300, keyboard: TextInputType.streetAddress),
  (name: 'emergencyContact', label: 'Emergency Contact Person', max: 100, keyboard: TextInputType.name),
  (name: 'guardianRelationship', label: 'Relationship (optional)', max: 60, keyboard: TextInputType.text),
  (name: 'emergencyContactNumber', label: 'Emergency Contact Number', max: 30, keyboard: TextInputType.phone),
];

/// Same rules as the API (portalProfileRules) and the web form (EditContactForm.jsx).
Map<String, String> validateContact(Map<String, String> form) => onlyErrors({
  'contactNumber': phone(form['contactNumber'], 'Mobile number'),
  'personalEmail': form['personalEmail']!.trim().isEmpty ? null : email(form['personalEmail'], label: 'Personal email'),
  'address': lengthBetween(form['address'], 'Address', 5, 300),
  'emergencyContact': personName(form['emergencyContact'], 'Emergency contact', max: 100),
  'guardianRelationship': optionalName(form['guardianRelationship'], 'Relationship'),
  'emergencyContactNumber': phone(form['emergencyContactNumber'], 'Emergency contact number'),
});

class _EditContactFormState extends State<EditContactForm> {
  late final Map<String, TextEditingController> _controllers = {
    for (final f in _contactFields) f.name: TextEditingController(text: _shown(widget.student[f.name]) == '—' ? '' : '${widget.student[f.name]}'),
  };
  // Fields left (blur) or submitted show their message; the API's messages too.
  final Set<String> _touched = {};
  Map<String, String> _serverErrors = const {};
  bool _saving = false;
  String _serverError = '';

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> get _form => _controllers.map((k, c) => MapEntry(k, c.text));

  Future<void> _submit() async {
    if (_saving) return; // no double submits
    setState(() => _touched.addAll(_contactFields.map((f) => f.name)));
    if (validateContact(_form).isNotEmpty) return;
    setState(() {
      _saving = true;
      _serverError = '';
    });
    try {
      final body = _form.map((k, v) => MapEntry(k, clean(v)));
      final data = await context.read<ApiClient>().put('/portal/profile', body);
      widget.onSaved(Map<String, dynamic>.from(data as Map));
    } catch (error) {
      if (mounted) {
        setState(() {
          _serverErrors = apiFieldErrors(error);
          _serverError = _serverErrors.isEmpty ? apiErrorMessage(error) : '';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final errors = {...validateContact(_form), ..._serverErrors};
    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Edit Contact Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('Name, student ID and academic information are managed by the Registrar.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 12),
          if (_serverError.isNotEmpty) AlertBox(_serverError),
          ResponsiveGrid(
            minItemWidth: 300,
            children: [
              for (final field in _contactFields)
                Focus(
                  onFocusChange: (focused) {
                    if (!focused) setState(() => _touched.add(field.name));
                  },
                  child: TextField(
                    key: Key('contact-${field.name}'),
                    controller: _controllers[field.name],
                    keyboardType: field.keyboard,
                    maxLength: field.max,
                    onChanged: (_) => setState(() => _serverErrors = {..._serverErrors}..remove(field.name)),
                    decoration: InputDecoration(
                      labelText: field.label,
                      hintText: field.keyboard == TextInputType.phone ? 'e.g. 0917 123 4567' : null,
                      errorText: _touched.contains(field.name) ? errors[field.name] : null,
                      errorMaxLines: 3,
                      counterText: '',
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(onPressed: _saving ? null : _submit, icon: const Icon(Icons.save, size: 16), label: Text(_saving ? 'Saving…' : 'Save Changes')),
              OutlinedButton(onPressed: _saving ? null : widget.onCancel, child: const Text('Cancel')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lets a signed-in user change their password (PUT /api/auth/password).
class ChangePasswordCard extends StatefulWidget {
  const ChangePasswordCard({super.key, this.dense = false});
  final bool dense;

  @override
  State<ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends State<ChangePasswordCard> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final Set<String> _touched = {};
  Map<String, String> _serverErrors = const {};
  bool _saving = false;
  (AlertType, String)? _status;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  // Same rules as register and reset (not as login).
  Map<String, String> get _errors => {
    ...onlyErrors({
      'currentPassword': _current.text.isEmpty ? 'Enter your current password.' : null,
      'password': strongPassword(_next.text),
      'confirmPassword': confirmPassword(_confirm.text, _next.text),
    }),
    ..._serverErrors,
  };

  String? _shown(String field) => _touched.contains(field) ? _errors[field] : null;

  Future<void> _submit() async {
    if (_saving) return; // no double submits
    setState(() {
      _touched.addAll(['currentPassword', 'password', 'confirmPassword']);
      _status = null;
    });
    if (_errors.isNotEmpty) return;
    setState(() => _saving = true);
    final api = context.read<ApiClient>();
    try {
      final data = await api.put('/auth/password', {'currentPassword': _current.text, 'password': _next.text, 'confirmPassword': _confirm.text});
      // The API signs out every other session and returns a new token for this one.
      if (data is Map && data['token'] is String) await api.tokens.replace(data['token'] as String);
      _current.clear();
      _next.clear();
      _confirm.clear();
      _touched.clear();
      _status = (AlertType.success, 'Your password has been updated.');
    } catch (error) {
      _serverErrors = apiFieldErrors(error);
      if (_serverErrors.isEmpty) _status = (AlertType.danger, apiErrorMessage(error));
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _field(String name, String label, TextEditingController controller, {Widget? below}) => Focus(
    onFocusChange: (focused) {
      if (!focused) setState(() => _touched.add(name));
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: Key({'currentPassword': 'password-current', 'password': 'password-new', 'confirmPassword': 'password-confirm'}[name]!),
          controller: controller,
          obscureText: true,
          maxLength: 128,
          onChanged: (_) => setState(() => _serverErrors = {..._serverErrors}..remove(name)),
          decoration: InputDecoration(labelText: label, errorText: _shown(name), errorMaxLines: 3, counterText: ''),
        ),
        ?below,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final fields = [
      _field('currentPassword', 'Current password', _current),
      _field('password', 'New password', _next, below: PasswordChecklist(password: _next.text)),
      _field('confirmPassword', 'Confirm new password', _confirm),
    ];
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.dense) const PanelTitle('Account Security', icon: Icons.key),
        if (_status != null) AlertBox(_status!.$2, type: _status!.$1),
        ResponsiveGrid(minItemWidth: widget.dense ? 600 : 240, children: fields),
        const SizedBox(height: 12),
        FilledButton(onPressed: _saving ? null : _submit, child: Text(_saving ? 'Saving…' : 'Update password')),
      ],
    );
    return widget.dense ? body : Panel(padding: const EdgeInsets.all(20), child: body);
  }
}
