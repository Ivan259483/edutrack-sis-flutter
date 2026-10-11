import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import 'auth_card.dart';

/// The only sign-in screen, for students and administrators
/// (frontend/src/pages/LoginPage.jsx).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.initialRole = 'student'});
  final String initialRole;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  late String _role = widget.initialRole == 'admin' ? 'admin' : 'student';
  bool _showPassword = false;
  bool _rememberMe = false;
  bool _loading = false;
  String _error = '';

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _error = '';
      _loading = true;
    });
    final error = await context
        .read<Session>()
        .login(_identifier.text.trim(), _password.text, _role, remember: _rememberMe);
    // On success the router opens the dashboard for the account's role.
    if (!mounted || error == null) return;
    setState(() {
      _loading = false;
      _error = error;
    });
  }

  void _selectRole(String role) => setState(() {
        _role = role;
        _error = '';
      });

  void _fillDemo(String role) {
    final account = demoAccounts![role]!;
    setState(() {
      _role = role;
      _identifier.text = account.identifier;
      _password.text = account.password;
      _error = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final student = _role == 'student';
    return AuthCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: AuthIcon(Icons.school)),
            const SizedBox(height: 14),
            const Text('EduTrack SIS', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Student Information & Management Portal',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.slate400, fontSize: 13)),
            const SizedBox(height: 22),
            // Role switcher tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AppColors.slate900, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                _RoleTab(label: 'Student', icon: Icons.school, selected: student, onTap: () => _selectRole('student')),
                _RoleTab(label: 'Administrator', icon: Icons.shield, selected: !student, onTap: () => _selectRole('admin')),
              ]),
            ),
            const SizedBox(height: 22),
            if (_error.isNotEmpty) DarkError(_error),
            DarkLabel(student ? 'Student Email or Student ID' : 'Administrator Email'),
            TextFormField(
              key: const Key('login-identifier'),
              controller: _identifier,
              keyboardType: student ? TextInputType.text : TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: Colors.white),
              decoration: darkInput(hint: student ? 'e.g. juan.delacruz@edutrack.edu' : 'e.g. admin@edutrack.edu'),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return 'Please fill out this field.';
                if (!student && !RegExp(r'^[^\s@]+@[^\s@]+$').hasMatch(text)) return 'Please enter an email address.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            const DarkLabel('Password'),
            TextFormField(
              key: const Key('login-password'),
              controller: _password,
              obscureText: !_showPassword,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              style: const TextStyle(color: Colors.white),
              decoration: darkInput(
                hint: 'Enter password',
                suffix: IconButton(
                  tooltip: _showPassword ? 'Hide password' : 'Show password',
                  icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, size: 18, color: AppColors.slate300),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
              validator: (value) => (value ?? '').isEmpty ? 'Please fill out this field.' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _rememberMe,
                    side: const BorderSide(color: AppColors.slate500),
                    onChanged: (v) => setState(() => _rememberMe = v ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                  child: const Text('Remember Me', style: TextStyle(color: AppColors.slate400, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            WideButton(
              label: _loading ? 'Authenticating...' : 'Sign In',
              onPressed: _loading ? null : _submit,
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0x406C757D)),
            const SizedBox(height: 8),
            if (student)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('New student? ', style: TextStyle(color: AppColors.slate400, fontSize: 13)),
                  GestureDetector(
                    onTap: () => context.push('/register'),
                    child: const Text('Create an Account',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ],
              )
            else
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 11, color: AppColors.slate400),
                  SizedBox(width: 4),
                  Text('Authorized Registrar Personnel Only', style: TextStyle(color: AppColors.slate400, fontSize: 11)),
                ],
              ),
            // Quick Demo Fill (debug builds only)
            if (demoAccounts != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.slate900,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x406C757D)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.bolt, size: 16, color: AppColors.warning),
                      SizedBox(width: 4),
                      Text('Quick Demo Fill', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 13)),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _DemoButton(label: 'Demo Student', icon: Icons.school, onTap: () => _fillDemo('student'))),
                      const SizedBox(width: 8),
                      Expanded(child: _DemoButton(label: 'Demo Admin', icon: Icons.shield, onTap: () => _fillDemo('admin'))),
                    ]),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoleTab extends StatelessWidget {
  const _RoleTab({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: Material(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 16, color: selected ? Colors.white : AppColors.slate400),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? Colors.white : AppColors.slate400,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          )),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _DemoButton extends StatelessWidget {
  const _DemoButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFF8F9FA),
          side: const BorderSide(color: Color(0xFFF8F9FA)),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      );
}
