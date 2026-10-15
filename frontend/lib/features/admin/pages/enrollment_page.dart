import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../core/pdf_docs.dart';
import '../../../core/theme.dart';
import '../../../widgets/common.dart';
import '../admin_widgets.dart';
import '../data/admin_rules.dart';
import '../data/admin_store.dart';

/// Review enrollment requests and print Certificates of Registration
/// (admin/src/pages/EnrollmentPage.tsx).
class AdminEnrollmentPage extends StatefulWidget {
  const AdminEnrollmentPage({super.key, this.recordId});

  /// Opens this enrollment's details (`?record=`, from notifications).
  final String? recordId;

  @override
  State<AdminEnrollmentPage> createState() => _AdminEnrollmentPageState();
}

class _AdminEnrollmentPageState extends State<AdminEnrollmentPage> {
  String _tab = 'all';
  String _search = '';
  String _program = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.recordId == null) return;
      if (context.read<AdminStore>().find(AdminCollection.enrollments, widget.recordId) != null) _openDetails(widget.recordId!);
    });
  }

  void _openDetails(String id) {
    showSheetDialog<void>(
      context,
      title: 'Enrollment Details',
      builder: (_) => _EnrollmentDetails(id: id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final settings = store.settings;
    final all = store.enrollments;
    int count(String status) => all.where((e) => e['status'] == status).length;
    final query = _search.toLowerCase();
    final filtered = all.where((e) {
      final matchTab = _tab == 'all' || e['status'] == _tab;
      final matchSearch = '${e['studentName']}'.toLowerCase().contains(query) || '${e['studentNumber']}'.contains(_search);
      return matchTab && matchSearch && (_program == 'all' || e['program'] == _program);
    }).toList();

    return AdminPage(
      onRefresh: store.refresh,
      children: [
        AdminPageHeader(
          title: 'Enrollment & COR',
          description:
              '${periodLabel(settings)} · Enrollment ${settings['enrollmentOpen'] == true ? 'open' : 'closed'}. Review existing requests and Certificates of Registration.',
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'all', label: Text('All (${all.length})')),
              ButtonSegment(value: 'Pending', label: Text('Pending (${count('Pending')})')),
              ButtonSegment(value: 'Approved', label: Text('Approved (${count('Approved')})')),
              ButtonSegment(value: 'Rejected', label: Text('Rejected (${count('Rejected')})')),
            ],
            selected: {_tab},
            onSelectionChanged: (v) => setState(() => _tab = v.first),
          ),
        ),
        const SizedBox(height: 12),
        FilterGrid(
          children: [
            SearchBox(hint: 'Search by student name or ID...', value: _search, onChanged: (v) => setState(() => _search = v)),
            FilterSelect(label: 'Program', allLabel: 'All Programs', value: _program, options: programOptions, onChanged: (v) => setState(() => _program = v)),
          ],
        ),
        const SizedBox(height: 12),
        AdminCard(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (filtered.isEmpty)
                const Empty('No enrollments found\nNo enrollment requests match your current filters.', icon: Icons.assignment_turned_in_outlined),
              for (final e in filtered)
                InkWell(
                  onTap: () => _openDetails('${e['id']}'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.adminBorder)),
                    ),
                    child: Row(
                      children: [
                        InitialsAvatar('${e['studentName']}'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${e['studentName']}', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                              Text(
                                '${e['studentNumber']} · ${e['program']} · ${e['yearLevel']} · ${e['section']}',
                                style: const TextStyle(fontSize: 12, color: AppColors.adminMutedFg),
                              ),
                              Text('${num0(e['totalUnits'] as num? ?? 0)} units', style: const TextStyle(fontSize: 12, color: AppColors.adminMutedFg)),
                            ],
                          ),
                        ),
                        StatusBadge('${e['status']}', dot: true),
                        const Icon(Icons.chevron_right, color: AppColors.adminMutedFg),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Details, approve/reject and COR for one enrollment.
class _EnrollmentDetails extends StatelessWidget {
  const _EnrollmentDetails({required this.id});
  final String id;

  Future<void> _approve(BuildContext context, Map<String, dynamic> e) async {
    var override = false;
    if (hasPrerequisiteConcerns(e)) {
      override = await confirmDialog(
        context,
        title: 'Override unmet prerequisites?',
        message:
            '${e['studentName']} has unresolved prerequisites. Confirm that you authorize this exception. This approval will be recorded in the activity log.',
        confirmLabel: 'Confirm override and approve',
      );
      if (!override || !context.mounted) return;
    }
    await runChange(
      context,
      () => context.read<AdminStore>().save(
        AdminCollection.enrollments,
        transitionEnrollment(e, 'Approved', override: override),
        action: 'Approved enrollment for ${e['studentName']}${override ? ' with confirmed prerequisite override' : ''}',
      ),
      success: 'Enrollment approved',
      description: "${e['studentName']}'s enrollment has been approved.",
    );
  }

  Future<void> _reject(BuildContext context, Map<String, dynamic> e) async {
    final remarks = await showDialog<String>(
      context: context,
      builder: (_) => _RejectDialog(name: '${e['studentName']}'),
    );
    if (remarks == null || !context.mounted) return;
    await runChange(
      context,
      () => context.read<AdminStore>().save(
        AdminCollection.enrollments,
        transitionEnrollment(e, 'Rejected', remarks: remarks),
        action: 'Rejected enrollment for ${e['studentName']}',
      ),
      success: 'Enrollment rejected',
      description: "${e['studentName']}'s enrollment has been rejected.",
    );
  }

  void _printCor(Map<String, dynamic> e, Map<String, dynamic> settings) {
    final subjects = enrollmentSubjects(e);
    PrintableDoc(
      title: 'Certificate of Registration - ${e['studentNumber']}',
      subtitle: 'Office of the Registrar',
      badge: 'Certificate of Registration',
      info: [
        ('Student Name', '${e['studentName']}'),
        ('Student Number', '${e['studentNumber']}'),
        ('Program', '${e['program']}'),
        ('Year Level & Section', '${e['yearLevel']} · ${e['section']}'),
        ('Academic Term', periodLabel(settings)),
      ],
      sections: [
        DocSection(
          headers: const ['Code', 'Subject', 'Units'],
          rows: [
            for (final s in subjects) ['${s['code']}', '${s['title']}', num0(s['units'] as num)],
          ],
          footer: ['', 'Total Units', num0(e['totalUnits'] as num? ?? 0)],
        ),
      ],
      signatures: [('', 'Student Signature'), ('', 'Registrar Signature')],
    ).print();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final e = store.find(AdminCollection.enrollments, id);
    if (e == null) return const Empty('This enrollment no longer exists.');
    final subjects = enrollmentSubjects(e);
    final pending = e['status'] == 'Pending';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${e['studentName']} · ${e['studentNumber']}', style: const TextStyle(color: AppColors.adminMutedFg, fontSize: 13)),
        const SizedBox(height: 12),
        Row(
          children: [
            InitialsAvatar('${e['studentName']}', radius: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${e['studentName']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(
                    '${e['studentNumber']}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: AppColors.adminMutedFg),
                  ),
                ],
              ),
            ),
            StatusBadge('${e['status']}', dot: true),
          ],
        ),
        const SizedBox(height: 12),
        InfoGrid([
          ('Program', '${e['program']}'),
          ('Year Level', '${e['yearLevel']}'),
          ('Section', '${e['section']}'),
          ('Total Units', num0(e['totalUnits'] as num? ?? 0)),
        ], minItemWidth: 120),
        if (e['hasPrerequisiteConcerns'] == true) ...[
          const SizedBox(height: 12),
          const AlertBox('Prerequisite Concern\nSome subjects have unmet prerequisites. Please review before approving.', type: AlertType.warning),
        ],
        const SectionLabel('Selected Subjects'),
        for (final s in subjects)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.adminBorder)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    '${s['code']}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${s['title']}', style: const TextStyle(fontSize: 13)),
                      Text(
                        'Prerequisite: ${(s['prerequisite'] as String?)?.isNotEmpty == true ? s['prerequisite'] : 'None'}',
                        style: const TextStyle(fontSize: 11, color: AppColors.adminMutedFg),
                      ),
                      if (s['hasPrerequisiteMet'] != true && (s['prerequisite'] as String?)?.isNotEmpty == true)
                        Row(
                          children: [
                            const Icon(Icons.warning_amber, size: 13, color: AppColors.amber600),
                            const SizedBox(width: 4),
                            Text('Needs ${s['prerequisite']}', style: const TextStyle(fontSize: 11, color: AppColors.amber600)),
                          ],
                        ),
                    ],
                  ),
                ),
                Text('${num0(s['units'] as num)} u', style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        if (e['status'] == 'Rejected' && '${e['remarks'] ?? ''}'.isNotEmpty) ...[const SizedBox(height: 12), AlertBox('Rejection Remarks\n${e['remarks']}')],
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 12),
        if (pending)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('enrollment-approve'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.green600),
                onPressed: () => _approve(context, e),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Approve Enrollment'),
              ),
              FilledButton.icon(
                key: const Key('enrollment-reject'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.adminDestructive),
                onPressed: () => _reject(context, e),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Reject Enrollment'),
              ),
            ],
          ),
        if (e['prerequisiteOverride'] == true)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Prerequisite override confirmed by Admin.', style: TextStyle(fontSize: 12, color: AppColors.amber600)),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: canIssueCor(e) ? () => _printCor(e, store.settings) : null,
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('View COR'),
          ),
        ),
        if (!canIssueCor(e))
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('A Certificate of Registration is available only after approval.', style: TextStyle(fontSize: 12, color: AppColors.adminMutedFg)),
          ),
      ],
    );
  }
}

/// Asks for the (required) rejection remarks; returns them, or null if cancelled.
class _RejectDialog extends StatefulWidget {
  const _RejectDialog({required this.name});
  final String name;

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _remarks = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reject Enrollment'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("Provide a reason for rejecting ${widget.name}'s enrollment."),
        const SizedBox(height: 12),
        TextField(
          key: const Key('reject-remarks'),
          controller: _remarks,
          minLines: 4,
          maxLines: 6,
          maxLength: 1000,
          decoration: InputDecoration(hintText: 'Enter rejection remarks...', errorText: _error),
        ),
      ],
    ),
    actions: [
      OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.adminDestructive),
        onPressed: () {
          if (_remarks.text.trim().isEmpty) {
            setState(() => _error = 'Please provide a reason for rejection.');
            return;
          }
          Navigator.pop(context, _remarks.text.trim());
        },
        child: const Text('Confirm Rejection'),
      ),
    ],
  );
}
