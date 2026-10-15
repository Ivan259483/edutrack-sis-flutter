import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../widgets/common.dart';
import '../admin_widgets.dart';
import '../data/admin_rules.dart';
import '../data/admin_store.dart';

/// Random id for a new reply (the web uses crypto.randomUUID()).
String _replyId() {
  final random = Random.secure();
  final hex = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// The full ticket after an admin reply (admin `replyToTicket`).
Map<String, dynamic> replyToTicket(Map<String, dynamic> ticket, String message, {required bool resolve}) {
  if (ticket['status'] == 'Resolved') throw const FormatException('This ticket is already resolved.');
  if (message.trim().isEmpty) throw const FormatException('Enter a reply before sending.');
  return {
    ...ticket,
    'status': resolve ? 'Resolved' : 'In Progress',
    'dateUpdated': todayIso(),
    'replies': [
      ...(ticket['replies'] as List? ?? const []),
      {'id': _replyId(), 'author': 'Admin', 'message': message.trim(), 'timestamp': nowIso(), 'isAdmin': true},
    ],
  };
}

/// Student tickets: filter, read, reply and resolve
/// (admin/src/pages/SupportHelpdeskPage.tsx).
class SupportHelpdeskPage extends StatefulWidget {
  const SupportHelpdeskPage({super.key, this.recordId});

  /// Opens this ticket (`?record=`, from notifications and global search).
  final String? recordId;

  @override
  State<SupportHelpdeskPage> createState() => _SupportHelpdeskPageState();
}

class _SupportHelpdeskPageState extends State<SupportHelpdeskPage> {
  String _tab = 'all';
  String _search = '';
  String _category = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AdminStore>().find(AdminCollection.tickets, widget.recordId) != null) _open(widget.recordId!);
    });
  }

  void _open(String id) {
    showSheetDialog<void>(
      context,
      title: 'Support Ticket',
      builder: (_) => _TicketDetails(id: id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final tickets = store.tickets;
    int count(String status) => tickets.where((t) => t['status'] == status).length;
    final query = _search.toLowerCase();
    final filtered = tickets.where((t) {
      final matchSearch = ['studentName', 'subject', 'ticketNumber'].any((f) => '${t[f]}'.toLowerCase().contains(query));
      return (_tab == 'all' || t['status'] == _tab) && matchSearch && (_category == 'all' || t['category'] == _category);
    }).toList();

    return AdminPage(
      onRefresh: store.refresh,
      children: [
        const AdminPageHeader(title: 'Support Helpdesk', description: 'Manage student support tickets and concerns'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'all', label: Text('All (${tickets.length})')),
              ButtonSegment(value: 'Open', label: Text('Open (${count('Open')})')),
              ButtonSegment(value: 'In Progress', label: Text('In Progress (${count('In Progress')})')),
              ButtonSegment(value: 'Resolved', label: Text('Resolved (${count('Resolved')})')),
            ],
            selected: {_tab},
            onSelectionChanged: (v) => setState(() => _tab = v.first),
          ),
        ),
        const SizedBox(height: 12),
        FilterGrid(
          children: [
            SearchBox(hint: 'Search by student, subject, or ticket number...', value: _search, onChanged: (v) => setState(() => _search = v)),
            FilterSelect(
              label: 'Category',
              allLabel: 'All Categories',
              value: _category,
              options: ticketCategoryOptions,
              onChanged: (v) => setState(() => _category = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty) const AdminCard(child: Empty('No tickets found\nNo support tickets match your filters.', icon: Icons.support_outlined)),
        for (final t in filtered)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AdminCard(
              onTap: () => _open('${t['id']}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InitialsAvatar('${t['studentName']}', radius: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${t['subject']}', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                            Text('${t['studentName']} · ${t['ticketNumber']}', style: const TextStyle(fontSize: 12, color: AppColors.adminMutedFg)),
                          ],
                        ),
                      ),
                      StatusBadge('${t['status']}', dot: true),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Builder(
                        builder: (_) {
                          final (bg, fg) = categoryColors('${t['category']}');
                          return Tag('${t['category']}', bg: bg, fg: fg);
                        },
                      ),
                      const Spacer(),
                      Text(formatDate(t['dateCreated'] as String?), style: const TextStyle(fontSize: 12, color: AppColors.adminMutedFg)),
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

class _TicketDetails extends StatefulWidget {
  const _TicketDetails({required this.id});
  final String id;

  @override
  State<_TicketDetails> createState() => _TicketDetailsState();
}

class _TicketDetailsState extends State<_TicketDetails> {
  final _reply = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() change, String success, String description) async {
    setState(() => _saving = true);
    final ok = await runChange(context, change, success: success, description: description);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) _reply.clear();
  }

  Future<void> _markInProgress(Map<String, dynamic> t) => _run(
    () => context.read<AdminStore>().save(AdminCollection.tickets, {
      ...t,
      'status': 'In Progress',
      'dateUpdated': todayIso(),
    }, action: 'Updated ticket status to In Progress'),
    'Ticket updated',
    '${t['ticketNumber']} marked as In Progress.',
  );

  Future<void> _send(Map<String, dynamic> t, {required bool resolve}) async {
    if (_reply.text.trim().isEmpty) {
      await showProblem(context, 'Reply is empty', resolve ? 'Please enter a reply before resolving.' : 'Please enter a reply before sending.');
      return;
    }
    await _run(
      () => context.read<AdminStore>().save(
        AdminCollection.tickets,
        replyToTicket(t, _reply.text, resolve: resolve),
        action: resolve ? 'Replied and resolved ticket' : 'Replied to ticket',
      ),
      resolve ? 'Ticket resolved' : 'Reply saved',
      resolve ? 'Reply saved and ${t['ticketNumber']} marked as Resolved.' : 'Reply saved to ${t['ticketNumber']}. Ticket marked as In Progress.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AdminStore>().find(AdminCollection.tickets, widget.id);
    if (t == null) return const Empty('This ticket no longer exists.');
    final replies = [for (final r in (t['replies'] as List? ?? const [])) Map<String, dynamic>.from(r as Map)];
    final (catBg, catFg) = categoryColors('${t['category']}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${t['subject']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(
                    '${t['ticketNumber']}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.adminMutedFg),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge('${t['status']}', dot: true),
                const SizedBox(height: 4),
                Tag('${t['category']}', bg: catBg, fg: catFg),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.adminMuted, borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              InitialsAvatar('${t['studentName']}', radius: 16),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${t['studentName']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text('${t['studentNumber']}', style: const TextStyle(fontSize: 12, color: AppColors.adminMutedFg)),
                ],
              ),
            ],
          ),
        ),
        const SectionLabel('Concern'),
        Text('${t['message']}', style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.access_time, size: 12, color: AppColors.adminMutedFg),
            const SizedBox(width: 4),
            Text(formatDate(t['dateCreated'] as String?), style: const TextStyle(fontSize: 12, color: AppColors.adminMutedFg)),
          ],
        ),
        if (replies.isNotEmpty) ...[
          const SectionLabel('Conversation'),
          for (final r in replies)
            Align(
              alignment: r['isAdmin'] == true ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                margin: EdgeInsets.only(bottom: 8, left: r['isAdmin'] == true ? 40 : 0, right: r['isAdmin'] == true ? 0 : 40),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: r['isAdmin'] == true ? AppColors.adminPrimary : AppColors.adminMuted, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r['author']}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: r['isAdmin'] == true ? Colors.white : AppColors.adminFg),
                    ),
                    const SizedBox(height: 2),
                    Text('${r['message']}', style: TextStyle(fontSize: 14, color: r['isAdmin'] == true ? Colors.white : AppColors.adminFg)),
                    const SizedBox(height: 4),
                    Text(
                      formatDate(r['timestamp'] as String?),
                      style: TextStyle(fontSize: 11, color: r['isAdmin'] == true ? Colors.white70 : AppColors.adminMutedFg),
                    ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 12),
        if (t['status'] != 'Resolved') ...[
          TextField(
            key: const Key('ticket-reply'),
            controller: _reply,
            minLines: 3,
            maxLines: 6,
            maxLength: 5000,
            decoration: const InputDecoration(hintText: 'Type your reply...'),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (t['status'] == 'Open')
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _markInProgress(t),
                  icon: const Icon(Icons.access_time, size: 18),
                  label: const Text('Mark In Progress'),
                ),
              FilledButton.icon(
                key: const Key('ticket-send'),
                onPressed: _saving ? null : () => _send(t, resolve: false),
                icon: const Icon(Icons.send, size: 18),
                label: const Text('Reply'),
              ),
              FilledButton.icon(
                key: const Key('ticket-resolve'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.green600),
                onPressed: _saving ? null : () => _send(t, resolve: true),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Reply & Resolve'),
              ),
            ],
          ),
        ] else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: AppColors.green600, size: 18),
                SizedBox(width: 8),
                Text('This ticket has been resolved.', style: TextStyle(color: Color(0xFF166534))),
              ],
            ),
          ),
      ],
    );
  }
}
