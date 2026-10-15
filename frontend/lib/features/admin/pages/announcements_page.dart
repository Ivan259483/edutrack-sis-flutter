import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../widgets/common.dart';
import '../admin_widgets.dart';
import '../data/admin_rules.dart';
import '../data/admin_store.dart';

/// Create, edit, publish/unpublish and delete announcements
/// (admin/src/pages/AnnouncementsPage.tsx).
class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key, this.recordId, this.action});

  /// Opens this announcement in the editor (`?record=`, from global search).
  final String? recordId;

  /// `create` opens a new announcement (dashboard quick action).
  final String? action;

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  String _search = '';
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final requested = context.read<AdminStore>().find(AdminCollection.announcements, widget.recordId);
      if (widget.action == 'create') {
        _openForm(null);
      } else if (requested != null) {
        _openForm(requested);
      }
    });
  }

  void _openForm(Map<String, dynamic>? editing) {
    showSheetDialog<void>(
      context,
      title: editing == null ? 'Create Announcement' : 'Edit Announcement',
      builder: (_) => _AnnouncementForm(editing: editing),
    );
  }

  Future<void> _togglePublish(Map<String, dynamic> a) async {
    final next = a['status'] == 'Published' ? 'Draft' : 'Published';
    await runChange(
      context,
      () => context.read<AdminStore>().save(AdminCollection.announcements, {
        ...a,
        'status': next,
        'datePublished': next == 'Published' ? todayIso() : null,
      }, action: '$next announcement: ${a['title']}'),
      success: next == 'Published' ? 'Announcement published' : 'Announcement unpublished',
      description: '"${a['title']}" is now ${next.toLowerCase()}.',
    );
  }

  Future<void> _delete(Map<String, dynamic> a) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete Announcement',
      message: 'Are you sure you want to delete "${a['title']}"? This action cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await runChange(
      context,
      () => context.read<AdminStore>().remove(AdminCollection.announcements, a, action: 'Deleted announcement: ${a['title']}'),
      success: 'Announcement deleted',
      description: '"${a['title']}" has been removed.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final query = _search.toLowerCase();
    final filtered = store.announcements
        .where(
          (a) =>
              ('${a['title']}'.toLowerCase().contains(query) || '${a['message']}'.toLowerCase().contains(query)) &&
              (_status == 'all' || a['status'] == _status),
        )
        .toList();
    final createButton = FilledButton.icon(onPressed: () => _openForm(null), icon: const Icon(Icons.add, size: 18), label: const Text('Create Announcement'));

    return AdminPage(
      onRefresh: store.refresh,
      children: [
        AdminPageHeader(title: 'Announcements', description: 'Create and manage university announcements', actions: [createButton]),
        FilterGrid(
          children: [
            SearchBox(hint: 'Search announcements...', value: _search, onChanged: (v) => setState(() => _search = v)),
            FilterSelect(
              label: 'Status',
              allLabel: 'All Statuses',
              value: _status,
              options: const ['Published', 'Draft'],
              onChanged: (v) => setState(() => _status = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          AdminCard(
            child: Column(
              children: [
                const Empty('No announcements found\nCreate your first announcement to get started.', icon: Icons.campaign_outlined),
                createButton,
                const SizedBox(height: 12),
              ],
            ),
          ),
        for (final a in filtered)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text('${a['title']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge('${a['status']}', dot: true),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Builder(
                        builder: (_) {
                          final (bg, fg) = announcementCategoryColors('${a['category']}');
                          return Tag('${a['category']}', bg: bg, fg: fg);
                        },
                      ),
                      const Text('·', style: TextStyle(color: AppColors.adminMutedFg)),
                      Text('${a['targetValue']}', style: const TextStyle(fontSize: 12, color: AppColors.adminMutedFg)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${a['message']}', style: const TextStyle(fontSize: 13, color: AppColors.adminMutedFg)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          a['datePublished'] != null
                              ? 'Published ${formatDate(a['datePublished'] as String?)}'
                              : 'Created ${formatDate(a['dateCreated'] as String?)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.adminMutedFg),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _togglePublish(a),
                        icon: Icon(a['status'] == 'Published' ? Icons.edit_note : Icons.send_outlined, size: 18),
                        label: Text(a['status'] == 'Published' ? 'Unpublish' : 'Publish'),
                      ),
                      IconButton(tooltip: 'Edit', onPressed: () => _openForm(a), icon: const Icon(Icons.edit_outlined, size: 20)),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: () => _delete(a),
                        icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.adminDestructive),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AnnouncementForm extends StatefulWidget {
  const _AnnouncementForm({this.editing});
  final Map<String, dynamic>? editing;

  @override
  State<_AnnouncementForm> createState() => _AnnouncementFormState();
}

class _AnnouncementFormState extends State<_AnnouncementForm> {
  late final _title = TextEditingController(text: '${widget.editing?['title'] ?? ''}');
  late final _message = TextEditingController(text: '${widget.editing?['message'] ?? ''}');
  late String? _category = widget.editing?['category'] as String?;
  late String _audience = '${widget.editing?['targetAudience'] ?? 'All Students'}';
  late String _target = '${widget.editing?['targetValue'] ?? 'All Students'}';
  String _error = '';
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = context.read<AdminStore>();
    try {
      validateTarget(_audience, _target, store.sections);
    } on FormatException catch (e) {
      setState(() => _error = 'Choose a target audience: ${e.message}');
      return;
    }
    if (_title.text.trim().isEmpty || _category == null || _message.text.trim().isEmpty) {
      setState(() => _error = 'Missing fields: Please fill in title, category, and message.');
      return;
    }
    setState(() {
      _error = '';
      _saving = true;
    });
    final editing = widget.editing;
    final title = _title.text;
    final fields = {'title': title, 'category': _category, 'message': _message.text, 'targetAudience': _audience, 'targetValue': _target};
    // The full record: an edit keeps every other field; a new one starts as a draft.
    final record = editing != null
        ? {...editing, ...fields}
        : {...fields, 'status': 'Draft', 'author': 'Admin', 'dateCreated': todayIso(), 'datePublished': null};
    final navigator = Navigator.of(context);
    final ok = await runChange(
      context,
      () => store.save(AdminCollection.announcements, record, action: '${editing != null ? 'Updated' : 'Created'} announcement: $title'),
      success: editing != null ? 'Announcement updated' : 'Announcement created',
      description: editing != null ? '"$title" has been updated.' : '"$title" has been saved as a draft.',
      onError: (message) => _error = message,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final sections = context.watch<AdminStore>().sections;
    final (targetLabel, targetOptions) = switch (_audience) {
      'Specific Program' => ('Program', programOptions),
      'Specific Year Level' => ('Year Level', yearLevelOptions),
      'Specific Section' => ('Section', sections),
      _ => ('', const <String>[]),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.editing != null ? 'Update the announcement details.' : 'Fill in the details below to create a new announcement.',
          style: const TextStyle(color: AppColors.adminMutedFg, fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (_error.isNotEmpty) AlertBox(_error),
        TextField(
          key: const Key('announcement-title'),
          controller: _title,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Title', hintText: 'Enter announcement title...'),
        ),
        const SizedBox(height: 8),
        SelectField(label: 'Category', value: _category, options: announcementCategoryOptions, onChanged: (v) => setState(() => _category = v)),
        const SizedBox(height: 12),
        TextField(
          key: const Key('announcement-message'),
          controller: _message,
          minLines: 4,
          maxLines: 8,
          maxLength: 5000,
          decoration: const InputDecoration(labelText: 'Message', hintText: 'Enter announcement message...', alignLabelWithHint: true),
        ),
        const SizedBox(height: 8),
        SelectField(
          label: 'Target Audience',
          value: _audience,
          options: targetAudienceOptions,
          onChanged: (v) => setState(() {
            _audience = v!;
            _target = v == 'All Students' ? v : '';
          }),
        ),
        if (targetOptions.isNotEmpty) ...[
          const SizedBox(height: 12),
          SelectField(
            fieldKey: ValueKey('target-$_audience'),
            label: targetLabel,
            value: _target,
            options: targetOptions,
            onChanged: (v) => setState(() => _target = v!),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          children: [
            OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              key: const Key('announcement-save'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : (widget.editing != null ? 'Update' : 'Save as Draft')),
            ),
          ],
        ),
      ],
    );
  }
}
