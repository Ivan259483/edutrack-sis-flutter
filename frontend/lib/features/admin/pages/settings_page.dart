import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme.dart';
import '../../../widgets/common.dart';
import '../admin_widgets.dart';
import '../data/admin_rules.dart';
import '../data/admin_store.dart';

/// Academic period, enrollment/grade switches and notification preferences
/// (admin/src/pages/SettingsPage.tsx). Saved together with PUT /settings.
class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  late Map<String, dynamic> _settings = {...context.read<AdminStore>().settings};
  late final _year = TextEditingController(text: '${_settings['academicYear'] ?? ''}');
  bool _saved = false;
  bool _saving = false;
  String? _yearError;

  @override
  void dispose() {
    _year.dispose();
    super.dispose();
  }

  void _update(String key, Object value) => setState(() {
    _saved = false;
    _settings = {..._settings, key: value};
  });

  /// settingsSchema in admin/src/data/schema.ts.
  String? _validateYear(String value) {
    if (!RegExp(r'^\d{4}-\d{4}$').hasMatch(value)) return 'Use YYYY-YYYY for the academic year.';
    if (int.parse(value.substring(5)) != int.parse(value.substring(0, 4)) + 1) return 'Academic year must span consecutive years.';
    return null;
  }

  Future<void> _save() async {
    final year = _year.text.trim();
    setState(() => _yearError = _validateYear(year));
    if (_yearError != null) {
      showToast(context, 'Changes were not saved', error: true, description: _yearError);
      return;
    }
    setState(() => _saving = true);
    final ok = await runChange(
      context,
      () => context.read<AdminStore>().saveSettings({..._settings, 'academicYear': year}, action: 'Updated academic period and system settings'),
      success: 'Settings saved',
      description: 'System settings have been updated successfully.',
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = ok;
    });
    if (ok) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saved = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final saveButton = FilledButton.icon(
      onPressed: _saved || _saving ? null : _save,
      icon: Icon(_saved ? Icons.check : Icons.save_outlined, size: 18),
      label: Text(_saved ? 'Saved' : (_saving ? 'Saving…' : 'Save Settings')),
    );
    Widget toggle(String key, String title, String subtitle) => SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.adminMutedFg)),
      value: _settings[key] == true,
      onChanged: (v) => _update(key, v),
    );
    Widget section(IconData icon, String title, String description, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AdminCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.adminPrimary),
                const SizedBox(width: 10),
                Expanded(child: CardHeading(title, description: description)),
              ],
            ),
            ...children,
          ],
        ),
      ),
    );

    return AdminPage(
      onRefresh: store.refresh,
      children: [
        AdminPageHeader(
          title: 'Settings',
          description: 'Configure school controls and preferences. Save to apply changes across the Admin Portal.',
          actions: [saveButton],
        ),
        section(Icons.calendar_month_outlined, 'Academic Settings', 'Current academic year and semester', [
          ResponsiveGrid(
            minItemWidth: 240,
            children: [
              TextField(
                key: const Key('settings-year'),
                controller: _year,
                decoration: InputDecoration(labelText: 'Academic Year', hintText: 'e.g. 2024-2025', errorText: _yearError),
                onChanged: (_) => setState(() {
                  _saved = false;
                  _yearError = null;
                }),
              ),
              SelectField(label: 'Semester', value: '${_settings['semester']}', options: semesterOptions, onChanged: (v) => _update('semester', v!)),
            ],
          ),
        ]),
        section(Icons.assignment_turned_in_outlined, 'Enrollment Controls', 'Manage enrollment availability', [
          toggle('enrollmentOpen', 'Enrollment Open', 'Allow students to submit enrollment requests'),
        ]),
        section(Icons.school_outlined, 'Grade Controls', 'Manage grade encoding availability', [
          toggle('gradeEncodingOpen', 'Grade Encoding Open', 'Allow instructors and admins to encode grades'),
        ]),
        section(Icons.notifications_none, 'Notification Preferences', 'Choose which alerts you want to receive', [
          toggle('notifyNewEnrollments', 'New Enrollment Notifications', 'Get notified when a student submits an enrollment request'),
          toggle('notifyNewTickets', 'New Ticket Notifications', 'Get notified when a student opens a support ticket'),
          toggle('notifySystemActivity', 'System Activity Notifications', 'Get notified about general system actions and changes'),
        ]),
        Align(alignment: Alignment.centerRight, child: saveButton),
      ],
    );
  }
}
