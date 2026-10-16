import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/validation.dart';
import '../../widgets/password_checklist.dart';
import 'auth_card.dart';
import 'login_page.dart' show RoleTab;

const _sentMessage = 'If an account matches, we sent a code to its email.';

/// Forgot password for both tabs of the login screen
/// (frontend/src/pages/ForgotPasswordPage.jsx): step 1 asks for the email or
/// Student ID, step 2 for the emailed 6-digit code and the new password.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.initialRole = 'student'});
  final String initialRole;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late String _role = widget.initialRole == 'admin' ? 'admin' : 'student';
  int _step = 1;
  final _identifier = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPassword = false;
  bool _loading = false;
  String _error = '';
  String _info = '';
  // Fields the user has left (blur) or tried to submit, and messages from the API.
  final Set<String> _touched = {};
  Map<String, String> _serverErrors = const {};
  int _cooldown = 0;
  Timer? _timer;

  ApiClient get _api => context.read<Session>().api;
  bool get _student => _role == 'student';

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_identifier, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _identifierError() =>
      _student ? (_identifier.text.trim().isEmpty ? 'Enter your email or Student ID.' : null) : email(_identifier.text, label: 'Administrator email');

  Map<String, String> get _resetErrors => onlyErrors({
    'code': digitsCode(_code.text, resetCodeLength),
    'password': strongPassword(_password.text),
    'confirmPassword': confirmPassword(_confirm.text, _password.text),
  });

  String? _shown(String field) {
    if (_serverErrors[field] != null) return _serverErrors[field];
    if (!_touched.contains(field)) return null;
    return field == 'identifier' ? _identifierError() : _resetErrors[field];
  }

  void _edited(String field) => setState(() {
    _serverErrors = {..._serverErrors}..remove(field);
    _error = '';
  });

  /// Counts the resend button down (60 s, or what the API asks for).
  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  /// Runs one request at a time (no double submits).
  Future<void> _once(Future<void> Function() work) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await work();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestCode() => _once(() async {
    try {
      final data = await _api.post('/auth/forgot-password', {'identifier': _identifier.text.trim(), 'role': _role});
      if (!mounted) return;
      setState(() {
        _info = (data is Map && data['message'] is String) ? data['message'] as String : _sentMessage;
        _step = 2;
      });
      _startCooldown(data is Map && data['retryAfter'] is num ? (data['retryAfter'] as num).ceil() : resendSeconds);
    } catch (error) {
      if (!mounted) return;
      // "Please wait 42 seconds before requesting another code."
      final retryAfter = apiRetryAfter(error);
      if (retryAfter != null) _startCooldown(retryAfter);
      final fields = apiFieldErrors(error);
      setState(() {
        _serverErrors = fields;
        _error = fields.isEmpty ? apiErrorMessage(error) : '';
      });
    }
  });

  void _submitRequest() {
    setState(() => _touched.add('identifier'));
    if (_identifierError() == null) _requestCode();
  }

  void _submitReset() {
    setState(() => _touched.addAll(['code', 'password', 'confirmPassword']));
    if (_resetErrors.isNotEmpty) return;
    final session = context.read<Session>();
    final router = GoRouter.of(context);
    _once(() async {
      try {
        await _api.post('/auth/reset-password', {
          'identifier': _identifier.text.trim(),
          'role': _role,
          'code': _code.text.trim(),
          'password': _password.text,
          'confirmPassword': _confirm.text,
        });
        session.setNotice('Your password has been reset. Sign in with your new password.');
        router.go('/login?role=$_role');
      } catch (error) {
        if (!mounted) return;
        final fields = apiFieldErrors(error);
        setState(() {
          _serverErrors = fields;
          _error = fields.isEmpty ? apiErrorMessage(error) : '';
        });
      }
    });
  }

  void _backToStep1() => setState(() {
    _step = 1;
    for (final c in [_code, _password, _confirm]) {
      c.clear();
    }
    _touched.clear();
    _serverErrors = const {};
    _error = '';
  });

  /// A field that marks itself touched when it loses focus.
  Widget _blurring(String field, Widget child) => Focus(
    onFocusChange: (focused) {
      if (!focused) setState(() => _touched.add(field));
    },
    child: child,
  );

  @override
  Widget build(BuildContext context) => AuthCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: AuthIcon(Icons.key)),
        const SizedBox(height: 14),
        const Text(
          'Reset Your Password',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          _step == 1 ? 'Enter your account and we will email you a 6-digit code.' : 'Enter the code from your email and choose a new password.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.slate400, fontSize: 13),
        ),
        const SizedBox(height: 22),
        if (_step == 1) ...[
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.slate900, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                RoleTab(label: 'Student', icon: Icons.school, selected: _student, onTap: () => _switchRole('student')),
                RoleTab(label: 'Administrator', icon: Icons.shield, selected: !_student, onTap: () => _switchRole('admin')),
              ],
            ),
          ),
          const SizedBox(height: 22),
        ],
        if (_error.isNotEmpty) DarkError(_error),
        if (_step == 1) ..._requestStep() else ..._resetStep(),
        const SizedBox(height: 16),
        const Divider(color: Color(0x406C757D)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Remembered it? ', style: TextStyle(color: AppColors.slate400, fontSize: 13)),
            GestureDetector(
              onTap: () => context.go('/login?role=$_role'),
              child: const Text(
                'Back to Sign In',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  void _switchRole(String role) => setState(() {
    _role = role;
    _touched.clear();
    _serverErrors = const {};
    _error = '';
  });

  List<Widget> _requestStep() => [
    DarkLabel(_student ? 'Student Email or Student ID' : 'Administrator Email'),
    _blurring(
      'identifier',
      TextField(
        key: const Key('forgot-identifier'),
        controller: _identifier,
        autofocus: true,
        maxLength: 254,
        keyboardType: _student ? TextInputType.text : TextInputType.emailAddress,
        autofillHints: const [AutofillHints.username],
        style: const TextStyle(color: Colors.white),
        decoration: darkInput(
          hint: _student ? 'e.g. juan.delacruz@edutrack.edu' : 'e.g. admin@edutrack.edu',
          errorText: _shown('identifier'),
        ).copyWith(counterText: ''),
        onChanged: (_) => _edited('identifier'),
        onSubmitted: (_) => _submitRequest(),
      ),
    ),
    const SizedBox(height: 22),
    WideButton(
      key: const Key('forgot-send'),
      label: _loading ? 'Sending Code...' : 'Send Reset Code',
      onPressed: _loading ? null : _submitRequest,
    ),
  ];

  List<Widget> _resetStep() => [
    if (_info.isNotEmpty) DarkNotice('$_info It is valid for 15 minutes.', info: true),
    const DarkLabel('6-Digit Reset Code'),
    _blurring(
      'code',
      TextField(
        key: const Key('forgot-code'),
        controller: _code,
        autofocus: true,
        maxLength: resetCodeLength,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 24, fontFamily: 'monospace', letterSpacing: 8),
        decoration: darkInput(hint: '000000', errorText: _shown('code')).copyWith(counterText: ''),
        onChanged: (_) => _edited('code'),
      ),
    ),
    const SizedBox(height: 16),
    const DarkLabel('New Password'),
    _blurring(
      'password',
      TextField(
        key: const Key('forgot-password'),
        controller: _password,
        obscureText: !_showPassword,
        maxLength: 128,
        autofillHints: const [AutofillHints.newPassword],
        style: const TextStyle(color: Colors.white),
        decoration: darkInput(
          hint: 'Create a strong password',
          errorText: _shown('password'),
          suffix: IconButton(
            tooltip: _showPassword ? 'Hide password' : 'Show password',
            icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, size: 18, color: AppColors.slate300),
            onPressed: () => setState(() => _showPassword = !_showPassword),
          ),
        ).copyWith(counterText: ''),
        onChanged: (_) => _edited('password'),
      ),
    ),
    PasswordChecklist(password: _password.text, dark: true),
    const SizedBox(height: 16),
    const DarkLabel('Confirm New Password'),
    _blurring(
      'confirmPassword',
      TextField(
        key: const Key('forgot-confirm'),
        controller: _confirm,
        obscureText: !_showPassword,
        maxLength: 128,
        style: const TextStyle(color: Colors.white),
        decoration: darkInput(hint: 'Re-enter the new password', errorText: _shown('confirmPassword')).copyWith(counterText: ''),
        onChanged: (_) => _edited('confirmPassword'),
        onSubmitted: (_) => _submitReset(),
      ),
    ),
    const SizedBox(height: 22),
    WideButton(
      key: const Key('forgot-reset'),
      label: _loading ? 'Resetting Password...' : 'Reset Password',
      onPressed: _loading ? null : _submitReset,
    ),
    const SizedBox(height: 8),
    Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton(
          onPressed: _loading ? null : _backToStep1,
          child: Text(
            _student ? 'Use a different email or ID' : 'Use a different email',
            style: const TextStyle(color: AppColors.slate400, fontSize: 13),
          ),
        ),
        TextButton(
          key: const Key('forgot-resend'),
          onPressed: _cooldown > 0 || _loading ? null : _requestCode,
          child: Text(
            _cooldown > 0 ? 'Resend Code in ${_cooldown}s' : 'Resend Code',
            style: TextStyle(
              color: AppColors.primary.withValues(alpha: _cooldown > 0 ? 0.6 : 1),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  ];
}
