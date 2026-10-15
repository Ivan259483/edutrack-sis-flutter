import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'data/admin_rules.dart';

/// Phones show one column; the admin sidebar stays open from this width up
/// (Tailwind `lg`).
const adminWideBreakpoint = 1024.0;

/// Colors of admin/src/components/shared/StatusBadge.tsx (Tailwind 100/800 + 500 dot).
(Color bg, Color fg, Color dot) statusColors(String status) => switch (status) {
  'Pending' || 'In Progress' || 'Incomplete' => (const Color(0xFFFEF3C7), const Color(0xFF92400E), AppColors.amber500),
  'Approved' || 'Resolved' || 'Published' || 'Passed' || 'Active' => (const Color(0xFFDCFCE7), const Color(0xFF166534), AppColors.green500),
  'Rejected' || 'Failed' || 'Suspended' => (const Color(0xFFFEE2E2), const Color(0xFF991B1B), AppColors.red500),
  'Open' || 'On Leave' => (const Color(0xFFDBEAFE), const Color(0xFF1E40AF), AppColors.blue500),
  'Graduated' => (const Color(0xFFF3E8FF), const Color(0xFF6B21A8), const Color(0xFFA855F7)),
  _ => (const Color(0xFFF3F4F6), const Color(0xFF4B5563), const Color(0xFF9CA3AF)),
};

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key, this.dot = false});
  final String status;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, dotColor) = statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Color.alphaBlend(fg.withValues(alpha: 0.12), bg)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            status,
            style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Small rounded tag with its own colors (announcement and ticket categories).
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, required this.bg, required this.fg});
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(
      text,
      style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}

/// Tailwind 100/800 pairs used for categories.
(Color, Color) categoryColors(String category) => switch (category) {
  'Academic' || 'Enrollment' => (const Color(0xFFDBEAFE), const Color(0xFF1E40AF)),
  'Grades' => (const Color(0xFFDCFCE7), const Color(0xFF166534)),
  'Event' || 'Technical' => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
  'Urgent' => (const Color(0xFFFEE2E2), const Color(0xFF991B1B)),
  _ => (const Color(0xFFF3F4F6), const Color(0xFF374151)),
};

/// Announcement categories differ from ticket categories for "Enrollment" (green).
(Color, Color) announcementCategoryColors(String category) =>
    category == 'Enrollment' ? (const Color(0xFFDCFCE7), const Color(0xFF166534)) : categoryColors(category);

/// Round avatar with initials.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.name, {super.key, this.radius = 18, this.text});
  final String name;
  final double radius;
  final String? text;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: AppColors.adminPrimary.withValues(alpha: 0.1),
    child: Text(
      text ?? initials(name),
      style: TextStyle(color: AppColors.adminPrimary, fontWeight: FontWeight.w600, fontSize: radius * 0.7),
    ),
  );
}

/// Page title + description + actions (admin PageHeader).
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({super.key, required this.title, required this.description, this.actions = const []});
  final String title;
  final String description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Admin  ›  $title', style: const TextStyle(color: AppColors.adminMutedFg, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.adminFg),
        ),
        const SizedBox(height: 2),
        Text(description, style: const TextStyle(color: AppColors.adminMutedFg, fontSize: 13)),
        if (actions.isNotEmpty) ...[const SizedBox(height: 12), Wrap(spacing: 8, runSpacing: 8, children: actions)],
      ],
    ),
  );
}

/// Scrollable admin page body with pull-to-refresh.
class AdminPage extends StatelessWidget {
  const AdminPage({super.key, required this.children, required this.onRefresh});
  final List<Widget> children;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.sizeOf(context).width >= 768 ? 24.0 : 12.0;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(padding, padding, padding, padding + MediaQuery.paddingOf(context).bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }
}

/// Bordered white card (shadcn Card).
class AdminCard extends StatelessWidget {
  const AdminCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.borderColor, this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: color ?? Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: borderColor ?? AppColors.adminBorder, width: borderColor == null ? 1 : 2),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// Card title + description.
class CardHeading extends StatelessWidget {
  const CardHeading(this.title, {super.key, this.description, this.trailing});
  final String title;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              if (description != null) Text(description!, style: const TextStyle(color: AppColors.adminMutedFg, fontSize: 12)),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Search box for list filters.
class SearchBox extends StatelessWidget {
  const SearchBox({super.key, required this.hint, required this.value, required this.onChanged});
  final String hint;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: value,
    onChanged: onChanged,
    decoration: InputDecoration(hintText: hint, prefixIcon: const Icon(Icons.search, size: 18)),
  );
}

/// Dropdown filter whose first entry is "All …" (value 'all').
class FilterSelect extends StatelessWidget {
  const FilterSelect({super.key, required this.label, required this.allLabel, required this.value, required this.options, required this.onChanged});
  final String label;
  final String allLabel;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: options.contains(value) ? value : 'all',
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      DropdownMenuItem(value: 'all', child: Text(allLabel)),
      for (final option in options)
        DropdownMenuItem(
          value: option,
          child: Text(option, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (v) => onChanged(v ?? 'all'),
  );
}

/// Required dropdown in a form ("Select …" until chosen).
class SelectField extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.errorText,
    this.labels,
    this.fieldKey,
  });
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final String? errorText;

  /// Display text per option, when it differs from the value.
  final Map<String, String>? labels;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    key: fieldKey,
    initialValue: options.contains(value) ? value : null,
    isExpanded: true,
    hint: Text('Select ${label.toLowerCase()}'),
    decoration: InputDecoration(labelText: label, errorText: errorText),
    items: [
      for (final option in options)
        DropdownMenuItem(
          value: option,
          child: Text(labels?[option] ?? option, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: onChanged,
  );
}

/// Grid of filter fields: one per row on phones, side by side when wide.
class FilterGrid extends StatelessWidget {
  const FilterGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AdminCard(child: ResponsiveGrid(minItemWidth: 200, children: children));
}

/// Runs an admin change; on failure shows the web's "Changes were not saved"
/// toast with the reason, or passes the reason to [onError] (forms show it
/// inline, since a dialog covers the toast). Returns true on success.
Future<bool> runChange(
  BuildContext context,
  Future<void> Function() change, {
  String? success,
  String? description,
  void Function(String message)? onError,
}) async {
  try {
    await change();
    if (success != null && context.mounted) showToast(context, success, description: description);
    return true;
  } catch (error) {
    final message = error is FormatException ? ruleMessage(error) : apiErrorMessage(error);
    if (onError != null) {
      onError(message);
    } else if (context.mounted) {
      await showProblem(context, 'Changes were not saved', message);
    }
    return false;
  }
}

/// Error toast, or an alert when a dialog is open (it would hide the toast).
Future<void> showProblem(BuildContext context, String title, String message) async {
  if (ModalRoute.of(context) is! PopupRoute) return showToast(context, title, error: true, description: message);
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
    ),
  );
}

/// Two-line label/value block used in detail dialogs.
class LabeledValue extends StatelessWidget {
  const LabeledValue(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppColors.adminMutedFg, fontSize: 12)),
      const SizedBox(height: 2),
      Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
    ],
  );
}

/// Grey info box with a grid of label/value pairs.
class InfoGrid extends StatelessWidget {
  const InfoGrid(this.items, {super.key, this.minItemWidth = 150});
  final List<(String, String)> items;
  final double minItemWidth;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.adminMuted.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(8)),
    child: ResponsiveGrid(minItemWidth: minItemWidth, spacing: 10, children: [for (final (label, value) in items) LabeledValue(label, value)]),
  );
}

/// Section heading inside dialogs ("Contact Information").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.adminMutedFg, letterSpacing: 0.6),
    ),
  );
}
