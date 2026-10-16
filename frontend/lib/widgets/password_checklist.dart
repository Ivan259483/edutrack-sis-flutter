import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/validation.dart';

/// Live list of the password rules under a "new password" field.
/// [dark] matches the sign-in cards; otherwise it suits white cards.
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({super.key, required this.password, this.dark = false});
  final String password;
  final bool dark;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Password requirements',
    child: Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, test) in passwordChecks)
            Builder(
              builder: (context) {
                final met = test(password);
                final color = met ? (dark ? AppColors.green500 : const Color(0xFF15803D)) : (dark ? AppColors.slate400 : AppColors.slate500);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      Icon(met ? Icons.check_circle : Icons.radio_button_unchecked, size: 14, color: color),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          semanticsLabel: '$label ${met ? '(done)' : '(missing)'}',
                          style: TextStyle(color: color, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    ),
  );
}
