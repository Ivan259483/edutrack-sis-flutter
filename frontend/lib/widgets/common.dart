import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Loading / error / empty states for screens that load from the API
/// (frontend/src/components/PageState.jsx).
class Loading extends StatelessWidget {
  const Loading({super.key, this.label = 'Loading…'});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: AppColors.muted)),
      ],
    ),
  );
}

class LoadError extends StatelessWidget {
  const LoadError({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF8D7DA),
      border: Border.all(color: const Color(0xFFF1AEB5)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(message, style: const TextStyle(color: Color(0xFF58151C))),
        ),
        if (onRetry != null)
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            child: const Text('Try again'),
          ),
      ],
    ),
  );
}

class Empty extends StatelessWidget {
  const Empty(this.text, {super.key, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
    child: Column(
      children: [
        if (icon != null) Icon(icon, size: 28, color: AppColors.muted),
        if (icon != null) const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      ],
    ),
  );
}

/// Colored alert box (Bootstrap .alert).
class AlertBox extends StatelessWidget {
  const AlertBox(this.message, {super.key, this.type = AlertType.danger});
  final String message;
  final AlertType type;

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = switch (type) {
      AlertType.danger => (const Color(0xFFF8D7DA), const Color(0xFFF1AEB5), const Color(0xFF58151C)),
      AlertType.success => (const Color(0xFFD1E7DD), const Color(0xFFA3CFBB), const Color(0xFF0A3622)),
      AlertType.warning => (const Color(0xFFFFF3CD), const Color(0xFFFFE69C), const Color(0xFF664D03)),
      AlertType.secondary => (const Color(0xFFE2E3E5), const Color(0xFFC4C8CB), const Color(0xFF2B2F32)),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: TextStyle(color: fg, fontSize: 13)),
    );
  }
}

enum AlertType { danger, success, warning, secondary }

/// White rounded card with padding (Bootstrap "card border-0 shadow-sm rounded-4 p-4").
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Card(
    color: color,
    child: Padding(padding: padding, child: child),
  );
}

/// Card header with an icon and title, separated by a line.
class PanelTitle extends StatelessWidget {
  const PanelTitle(this.title, {super.key, this.icon, this.iconColor, this.subtitle, this.trailing});
  final String title;
  final IconData? icon;
  final Color? iconColor;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        if (icon != null) ...[Icon(icon, size: 18, color: iconColor ?? Theme.of(context).colorScheme.primary), const SizedBox(width: 8)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              if (subtitle != null) Text(subtitle!, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Label on the left, value on the right, with a hairline below.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.last = false, this.valueWidget});
  final String label;
  final String value;
  final bool last;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: last
        ? null
        : const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF1F3F5))),
          ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ),
        const SizedBox(width: 12),
        Flexible(
          flex: 2,
          child: Align(
            alignment: Alignment.centerRight,
            child:
                valueWidget ??
                Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
          ),
        ),
      ],
    ),
  );
}

/// Pill badge with a tinted background.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.color, this.solid = false, this.icon, this.fontSize = 11, this.dot = false});
  final String text;
  final Color color;
  final bool solid;
  final IconData? icon;
  final double fontSize;

  /// Leading status dot (drawn, so it renders the same with every font).
  final bool dot;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: solid ? color : color.withValues(alpha: 0.1),
      border: solid ? null : Border.all(color: color.withValues(alpha: 0.25)),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: fontSize, color: solid ? Colors.white : color), const SizedBox(width: 4)],
        if (dot) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: solid ? (_isLight(color) ? AppColors.dark : Colors.white) : color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
        ],
        Text(
          text,
          style: TextStyle(color: solid ? (_isLight(color) ? AppColors.dark : Colors.white) : color, fontSize: fontSize, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  static bool _isLight(Color c) => c.computeLuminance() > 0.6;
}

/// Monospace dark badge used for subject codes and ticket numbers.
class CodeBadge extends StatelessWidget {
  const CodeBadge(this.text, {super.key, this.color = AppColors.dark});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold),
    ),
  );
}

/// KPI tile: colored icon square, small label, big value.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    required this.label,
    required this.value,
    this.caption,
    this.dark = false,
  });
  final IconData icon;
  final Color color;
  final Color background;
  final String label;
  final Widget value;
  final String? caption;
  final bool dark;

  @override
  Widget build(BuildContext context) => Card(
    color: dark ? AppColors.slate800 : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: dark ? BorderSide(color: AppColors.slate600.withValues(alpha: 0.4)) : BorderSide.none,
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: dark ? AppColors.slate400 : AppColors.muted, fontSize: 12)),
                DefaultTextStyle.merge(
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: dark ? Colors.white : AppColors.dark),
                  child: value,
                ),
                if (caption != null) Text(caption!, style: TextStyle(color: dark ? AppColors.slate400 : AppColors.muted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Lays children out in [columns] equal columns on wide screens and one
/// column on phones (Bootstrap row/col).
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({super.key, required this.children, this.minItemWidth = 260, this.spacing = 12});
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = (constraints.maxWidth / minItemWidth).floor().clamp(1, children.length.clamp(1, 4));
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    },
  );
}

/// Shows a short message at the bottom of the screen (the web's toasts).
void showToast(BuildContext context, String message, {bool error = false, String? description}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(
    SnackBar(
      backgroundColor: error ? AppColors.danger : AppColors.slate800,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (description != null) Text(description, style: const TextStyle(fontSize: 12)),
        ],
      ),
    ),
  );
}

/// Yes/no confirmation dialog (window.confirm / AlertDialog).
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Full-screen-on-phone dialog with a title bar and close button.
Future<T?> showSheetDialog<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  List<Widget> Function(BuildContext)? actions,
  Widget? titleWidget,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) {
      final width = MediaQuery.sizeOf(context).width;
      return Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: width < 600 ? 12 : 40, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: titleWidget ?? Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), tooltip: 'Close'),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: builder(context)),
              ),
              if (actions != null) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: actions(context)),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// Rounded box with a thick colored left edge (the web's `border-left`
/// accent). Flutter can't round a border whose sides differ in color, so the
/// accent is drawn as a strip inside a clipped, uniformly bordered box.
class AccentBox extends StatelessWidget {
  const AccentBox({
    super.key,
    required this.accent,
    required this.child,
    this.accentWidth = 4,
    this.color = Colors.white,
    this.borderColor = AppColors.borderLight,
    this.radius = 10,
    this.padding = const EdgeInsets.all(12),
    this.margin,
    this.fillHeight = false,
  });
  final Color accent;
  final Widget child;
  final double accentWidth;
  final Color color;
  final Color borderColor;
  final double radius;
  final EdgeInsets padding;
  final EdgeInsets? margin;

  /// True when the box already has a fixed height (e.g. positioned in a grid).
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(width: accentWidth, color: accent),
        Expanded(
          child: Padding(padding: padding, child: child),
        ),
      ],
    );
    return Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: fillHeight ? row : IntrinsicHeight(child: row),
    );
  }
}
