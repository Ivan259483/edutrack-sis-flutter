import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/loader.dart';
import 'student_shell.dart';

const ticketCategories = ['Enrollment', 'Grades', 'Technical', 'General'];
const ticketStatusColors = {'Open': AppColors.danger, 'In Progress': AppColors.warning, 'Resolved': AppColors.success};

/// Same rules as the web form.
Map<String, String> validateTicket(String subject, String message) => {
      if (subject.trim().length < 5) 'subject': 'Subject must be at least 5 characters.',
      if (message.trim().length < 10) 'message': 'Please describe your concern (at least 10 characters).',
    };

/// Students open support tickets here; the registrar answers them in the
/// admin helpdesk (frontend/src/pages/StudentSupport.jsx).
class StudentSupportPage extends StatefulWidget {
  const StudentSupportPage({super.key});

  @override
  State<StudentSupportPage> createState() => _StudentSupportPageState();
}

class _StudentSupportPageState extends State<StudentSupportPage> with ApiLoader {
  List<Map<String, dynamic>> _tickets = [];
  String? _selectedId;
  bool _showForm = false;
  String _category = 'General';
  final _subject = TextEditingController();
  final _message = TextEditingController();
  final _reply = TextEditingController();
  bool _touched = false;
  bool _saving = false;
  String _error = '';

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    _reply.dispose();
    super.dispose();
  }

  @override
  Future<void> fetch() async => _tickets = asList(await api.get('/portal/tickets'));

  Map<String, dynamic>? get _selected => _tickets.where((t) => t['id'] == _selectedId).firstOrNull;

  void _replaceTicket(Map<String, dynamic> ticket) =>
      _tickets = [ticket, ..._tickets.where((t) => t['id'] != ticket['id'])];

  Future<void> _create() async {
    setState(() => _touched = true);
    if (validateTicket(_subject.text, _message.text).isNotEmpty) return;
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      final data = asMap(await api.post('/portal/tickets', {
        'category': _category,
        'subject': _subject.text.trim(),
        'message': _message.text.trim(),
      }))!;
      _replaceTicket(data);
      _selectedId = data['id'] as String;
      _subject.clear();
      _message.clear();
      _category = 'General';
      _touched = false;
      _showForm = false;
    } catch (error) {
      _error = apiErrorMessage(error);
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _sendReply() async {
    if (_reply.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      final data = asMap(await api.post('/portal/tickets/${Uri.encodeComponent(_selectedId!)}/replies', {'message': _reply.text.trim()}))!;
      _replaceTicket(data);
      _reply.clear();
    } catch (error) {
      _error = apiErrorMessage(error);
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final errors = _touched ? validateTicket(_subject.text, _message.text) : const <String, String>{};
    final list = _ticketList();
    final conversation = _conversation();
    return StudentPage(
      onRefresh: reload,
      children: [
        Panel(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: AppColors.blue50, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.headset_mic, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Flexible(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Help and Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    Text('Send a concern to the Registrar and follow the replies here.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  ]),
                ),
              ]),
              FilledButton.icon(
                onPressed: () => setState(() => _showForm = !_showForm),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Ticket'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_error.isNotEmpty) AlertBox(_error),
        if (_showForm) ...[
          Panel(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Open a support ticket', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('ticket-category'),
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [for (final c in ticketCategories) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('ticket-subject'),
                controller: _subject,
                maxLength: 200,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: 'Subject', errorText: errors['subject'], counterText: ''),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('ticket-message'),
                controller: _message,
                minLines: 4,
                maxLines: 8,
                maxLength: 5000,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: 'Message', errorText: errors['message'], counterText: '', alignLabelWithHint: true),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                FilledButton(onPressed: _saving ? null : _create, child: Text(_saving ? 'Sending…' : 'Submit Ticket')),
                OutlinedButton(onPressed: () => setState(() => _showForm = false), child: const Text('Cancel')),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
        ],
        if (loading)
          const Loading()
        else if (loadError != null)
          LoadError(message: loadError!, onRetry: () => reload(showSpinner: true))
        else if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 5, child: list),
            const SizedBox(width: 16),
            Expanded(flex: 7, child: conversation),
          ])
        else ...[
          list,
          const SizedBox(height: 16),
          conversation,
        ],
      ],
    );
  }

  Widget _ticketList() => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text('My Tickets (${_tickets.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const Divider(height: 1),
          if (_tickets.isEmpty) const Empty('You have not opened any tickets yet.'),
          for (final t in _tickets)
            Material(
              color: t['id'] == _selectedId ? AppColors.primary : Colors.white,
              child: InkWell(
                onTap: () => setState(() => _selectedId = t['id'] as String),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderLight))),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: t['id'] == _selectedId ? Colors.white : AppColors.dark),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('${t['ticketNumber']}', style: const TextStyle(fontFamily: 'monospace', fontSize: 13))),
                        Pill('${t['status']}', color: ticketStatusColors[t['status']] ?? AppColors.muted, solid: true),
                      ]),
                      const SizedBox(height: 4),
                      Text('${t['subject']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Opacity(
                        opacity: 0.75,
                        child: Text('${t['category']} • Updated ${formatDate(t['dateUpdated'] as String?)}', style: const TextStyle(fontSize: 12)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      );

  Widget _conversation() {
    final t = _selected;
    if (t == null) {
      return const Panel(child: Empty('Select a ticket to view the conversation.', icon: Icons.confirmation_number));
    }
    final replies = asList(t['replies']);
    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CodeBadge('${t['ticketNumber']}'),
              const SizedBox(height: 4),
              Text('${t['subject']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('${t['category']} • Opened ${formatDate(t['dateCreated'] as String?)}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ]),
          ),
          Pill('${t['status']}', color: ticketStatusColors[t['status']] ?? AppColors.muted, solid: true),
        ]),
        const SizedBox(height: 12),
        _bubble('You', null, '${t['message']}', isAdmin: false),
        for (final r in replies)
          _bubble(r['isAdmin'] == true ? '${r['author']} (Registrar)' : 'You', formatDate(r['timestamp'] as String?), '${r['message']}',
              isAdmin: r['isAdmin'] == true),
        const SizedBox(height: 8),
        if (t['status'] == 'Resolved')
          const Text('This ticket is resolved. Open a new ticket if you need more help.', style: TextStyle(color: AppColors.muted, fontSize: 13))
        else
          Row(children: [
            Expanded(
              child: TextField(
                key: const Key('ticket-reply'),
                controller: _reply,
                maxLength: 5000,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _sendReply(),
                decoration: const InputDecoration(hintText: 'Write a reply…', counterText: ''),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _saving || _reply.text.trim().isEmpty ? null : _sendReply,
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Send'),
            ),
          ]),
      ]),
    );
  }

  Widget _bubble(String author, String? date, String message, {required bool isAdmin}) => Container(
        margin: EdgeInsets.only(bottom: 8, left: isAdmin ? 24 : 0, right: isAdmin ? 0 : 24),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAdmin ? AppColors.primary.withValues(alpha: 0.1) : AppColors.light,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text.rich(TextSpan(style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), children: [
            TextSpan(text: author),
            if (date != null) TextSpan(text: '  • $date', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.normal)),
          ])),
          const SizedBox(height: 4),
          Text(message, style: const TextStyle(fontSize: 13)),
        ]),
      );
}
