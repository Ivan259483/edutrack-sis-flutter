import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Dark slate page with a centered card, shared by the sign-in screens.
class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child, this.maxWidth = 460});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.slate900,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.slate800,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, 8))],
              ),
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: Colors.white),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Round tinted icon above the card title.
class AuthIcon extends StatelessWidget {
  const AuthIcon(this.icon, {super.key, this.color = AppColors.primary, this.size = 56});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color.withValues(alpha: 0.25), shape: BoxShape.circle),
    child: Icon(icon, color: color, size: size * 0.45),
  );
}

/// Dark input style used on the sign-in screens (bg-dark border-secondary text-white).
/// [errorText] shows the red message under the field and a red border.
InputDecoration darkInput({String? hint, Widget? suffix, Color? borderColor, String? errorText}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: borderColor ?? AppColors.slate600),
  );
  final errorBorder = border.copyWith(borderSide: const BorderSide(color: AppColors.red500));
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.slate500),
    errorText: errorText,
    errorMaxLines: 3,
    errorStyle: const TextStyle(color: AppColors.red400, fontSize: 12),
    errorBorder: errorBorder,
    focusedErrorBorder: errorBorder.copyWith(borderSide: const BorderSide(color: AppColors.red500, width: 1.5)),
    filled: true,
    fillColor: AppColors.dark,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    suffixIcon: suffix,
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(borderSide: BorderSide(color: borderColor ?? AppColors.primary, width: 1.5)),
  );
}

/// Small field label above dark inputs.
class DarkLabel extends StatelessWidget {
  const DarkLabel(this.text, {super.key, this.suffix});
  final String text;
  final String? suffix;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: text,
            style: const TextStyle(color: Color(0xFFF8F9FA), fontSize: 13, fontWeight: FontWeight.w500),
          ),
          if (suffix != null)
            TextSpan(
              text: ' $suffix',
              style: const TextStyle(color: AppColors.slate400, fontSize: 13),
            ),
        ],
      ),
    ),
  );
}

/// Red error box on the dark sign-in card.
class DarkError extends StatelessWidget {
  const DarkError(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(color: const Color(0x26EF4444), borderRadius: BorderRadius.circular(10)),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.red400, fontSize: 13),
    ),
  );
}

/// Green (success) or blue (info) box on the dark sign-in card.
class DarkNotice extends StatelessWidget {
  const DarkNotice(this.message, {super.key, this.info = false});
  final String message;
  final bool info;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(color: info ? const Color(0x262563EB) : const Color(0x2622C55E), borderRadius: BorderRadius.circular(10)),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(color: info ? const Color(0xFF93C5FD) : const Color(0xFF4ADE80), fontSize: 13),
    ),
  );
}

/// Full-width primary button with a busy label.
class WideButton extends StatelessWidget {
  const WideButton({super.key, required this.label, required this.onPressed, this.color});
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color ?? AppColors.primary,
        disabledBackgroundColor: (color ?? AppColors.primary).withValues(alpha: 0.55),
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      child: Text(label),
    ),
  );
}
