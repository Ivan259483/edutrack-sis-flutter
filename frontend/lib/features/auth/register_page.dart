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

// Fields of step 1; API errors for them send the student back there.
const _detailFields = ['firstName', 'lastName', 'email', 'password', 'confirmPassword', 'program', 'yearLevel'];

const _programs = ['BS Information Technology', 'BS Business Administration', 'Bachelor of Secondary Education'];
const _years = ['1st Year', '2nd Year', '3rd Year', '4th Year'];

/// Student registration: 1 = details, 2 = email verification code, 3 = success.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  int _step = 1;
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _otp = TextEditingController();
  String _program = _programs.first;
  String _yearLevel = _years.first;
  final Set<String> _touched = {};
  bool _loading = false;
  String _serverError = '';
  // Field messages returned by the API (e.g. "Email is already registered.").
  Map<String, String> _serverErrors = const {};
  bool _otpTouched = false;
  int _cooldown = 0;
  Timer? _timer;

  // Same rules as the website and the API.
  Map<String, String> get _errors => {
    ...onlyErrors({
      'firstName': personName(_firstName.text, 'First name'),
      'lastName': personName(_lastName.text, 'Last name'),
      'email': email(_email.text),
      'password': strongPassword(_password.text),
      'confirmPassword': confirmPassword(_confirm.text, _password.text),
    }),
    ..._serverErrors,
  };
  bool get _formValid => _detailFields.every((f) => !_errors.containsKey(f));
  String? get _otpError => _serverErrors['otp'] ?? digitsCode(_otp.text, registrationCodeLength);
  String get _emailValue => _email.text.trim().toLowerCase();

  ApiClient get _api => context.read<Session>().api;

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_firstName, _lastName, _email, _password, _confirm, _otp]) {
      c.dispose();
    }
    super.dispose();
  }

  void _startCooldown([int seconds = resendSeconds]) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  /// Shows an API error under its field (back on step 1 if it belongs there),
  /// and counts the resend button down when the API asks to wait.
  void _showApiError(Object error, String fallback) {
    final retryAfter = apiRetryAfter(error);
    if (retryAfter != null) _startCooldown(retryAfter);
    final fields = apiFieldErrors(error);
    setState(() {
      _loading = false;
      if (fields.isEmpty) {
        _serverError = apiErrorMessage(error, fallback);
        return;
      }
      _serverErrors = fields;
      if (_detailFields.any(fields.containsKey)) {
        _touched.addAll(_detailFields);
        _step = 1;
      } else {
        _otpTouched = true;
      }
    });
  }

  Future<void> _sendOtp() async {
    if (_loading) return; // no double submits
    setState(() => _serverError = '');
    if (!_formValid) {
      setState(() => _touched.addAll(_detailFields));
      return;
    }
    setState(() => _loading = true);
    try {
      await _api.post('/auth/send-otp', {'email': _emailValue});
      if (!mounted) return;
      setState(() {
        _loading = false;
        _step = 2;
      });
      _startCooldown();
    } catch (error) {
      if (mounted) _showApiError(error, 'Failed to send verification code. Please try again.');
    }
  }

  Future<void> _resendOtp() async {
    if (_cooldown > 0 || _loading) return;
    setState(() {
      _serverError = '';
      _loading = true;
    });
    try {
      await _api.post('/auth/send-otp', {'email': _emailValue});
      if (!mounted) return;
      setState(() {
        _loading = false;
        _serverErrors = const {};
      });
      _startCooldown();
    } catch (error) {
      if (mounted) _showApiError(error, 'Failed to resend code. Please try again.');
    }
  }

  Future<void> _verifyAndRegister() async {
    if (_loading) return;
    setState(() {
      _serverError = '';
      _otpTouched = true;
    });
    if (_otpError != null) return;
    setState(() => _loading = true);
    try {
      await _api.post('/auth/verify-otp', {'email': _emailValue, 'otp': _otp.text.trim()});
      await _api.post('/auth/register', {
        'firstName': clean(_firstName.text),
        'lastName': clean(_lastName.text),
        'email': _emailValue,
        'password': _password.text,
        'confirmPassword': _confirm.text,
        'program': _program,
        'yearLevel': _yearLevel,
      });
      if (!mounted) return;
      setState(() {
        _loading = false;
        _step = 3;
      });
    } catch (error) {
      if (mounted) _showApiError(error, 'Verification or registration failed. Please try again.');
    }
  }

  void _changed(String field) => setState(() {
    _serverErrors = {..._serverErrors}..remove(field);
    _serverError = '';
  });

  @override
  Widget build(BuildContext context) {
    return AuthCard(
      maxWidth: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Student Account Registration',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'EduTrack Student Information System',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.slate400, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final (index, color) in [(1, AppColors.blue600), (2, AppColors.blue600), (3, AppColors.green500)]) ...[
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(color: _step >= index ? color : AppColors.slate600, borderRadius: BorderRadius.circular(4)),
                ),
                if (index < 3) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 20),
          if (_serverError.isNotEmpty) DarkError(_serverError),
          if (_step == 1) _details(),
          if (_step == 2) _verify(),
          if (_step == 3) _success(),
        ],
      ),
    );
  }

  Widget _field({
    required String name,
    required String label,
    required TextEditingController controller,
    required String validText,
    String? hint,
    String? labelSuffix,
    bool obscure = false,
    TextInputType? keyboard,
    int maxLength = 50,
    Widget? below,
  }) {
    final touched = _touched.contains(name);
    final error = _errors[name];
    final valid = error == null;
    final color = !touched ? null : (valid ? AppColors.green500 : AppColors.red500);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DarkLabel(label, suffix: labelSuffix),
        Focus(
          onFocusChange: (focused) {
            if (!focused) setState(() => _touched.add(name));
          },
          child: TextField(
            key: Key('register-$name'),
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboard,
            maxLength: maxLength,
            style: const TextStyle(color: Colors.white),
            decoration: darkInput(hint: hint, borderColor: color).copyWith(counterText: ''),
            onChanged: (_) => _changed(name),
          ),
        ),
        if (touched)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(valid ? validText : error, style: TextStyle(fontSize: 11, color: color)),
          ),
        ?below,
      ],
    );
  }

  Widget _select(String label, String value, List<String> options, ValueChanged<String> onChanged) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DarkLabel(label),
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        dropdownColor: AppColors.slate800,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: darkInput(),
        items: [
          for (final o in options)
            DropdownMenuItem(
              value: o,
              child: Text(o, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) => onChanged(v!),
      ),
    ],
  );

  Widget _pair(Widget a, Widget b, {int flexA = 1, int flexB = 1}) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth < 380
        ? Column(children: [a, const SizedBox(height: 14), b])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: flexA, child: a),
              const SizedBox(width: 10),
              Expanded(flex: flexB, child: b),
            ],
          ),
  );

  Widget _details() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _pair(
        _field(
          name: 'firstName',
          label: 'First Name',
          controller: _firstName,
          hint: 'e.g. Gabriel',
          validText: 'Valid first name',
        ),
        _field(
          name: 'lastName',
          label: 'Last Name',
          controller: _lastName,
          hint: 'e.g. Adiaton',
          validText: 'Valid last name',
        ),
      ),
      const SizedBox(height: 14),
      _pair(
        _select('Degree Program', _program, _programs, (v) => setState(() => _program = v)),
        _select('Year Level', _yearLevel, _years, (v) => setState(() => _yearLevel = v)),
        flexA: 7,
        flexB: 5,
      ),
      const SizedBox(height: 14),
      _field(
        name: 'email',
        label: 'Email Address',
        labelSuffix: '(Gmail or institutional)',
        controller: _email,
        hint: 'e.g. student@gmail.com',
        keyboard: TextInputType.emailAddress,
        maxLength: 254,
        validText: 'Valid email format',
      ),
      const SizedBox(height: 14),
      _pair(
        _field(
          name: 'password',
          label: 'Password',
          controller: _password,
          obscure: true,
          hint: 'Create a strong password',
          maxLength: 128,
          validText: 'Password meets requirements',
          below: PasswordChecklist(password: _password.text, dark: true),
        ),
        _field(
          name: 'confirmPassword',
          label: 'Confirm Password',
          controller: _confirm,
          obscure: true,
          hint: 'Re-enter password',
          maxLength: 128,
          validText: 'Passwords match',
        ),
      ),
      const SizedBox(height: 22),
      WideButton(
        key: const Key('register-send'),
        label: _loading ? 'Sending Verification Code...' : 'Send Verification Code to Email',
        color: AppColors.blue600,
        // Enabled even when invalid, so tapping it shows every field's message.
        onPressed: _loading ? null : _sendOtp,
      ),
      const SizedBox(height: 14),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Already have an account? ', style: TextStyle(color: AppColors.slate400, fontSize: 13)),
          GestureDetector(
            onTap: () => context.go('/login'),
            child: const Text(
              'Sign In',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _verify() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Check Your Email',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text(
        'A $registrationCodeLength-digit verification code has been dispatched to:',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.slate400, fontSize: 13),
      ),
      const SizedBox(height: 8),
      Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.slate900,
            border: Border.all(color: AppColors.slate700),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_email.text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Please check your Gmail inbox or spam/junk folder. The code will expire in 5 minutes.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.slate400, fontSize: 12),
      ),
      const SizedBox(height: 20),
      const Text(
        'Enter $registrationCodeLength-Digit Verification Code',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFFF8F9FA), fontSize: 13, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 8),
      TextField(
        key: const Key('register-otp'),
        controller: _otp,
        autofocus: true,
        maxLength: registrationCodeLength,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 28, fontFamily: 'monospace', letterSpacing: 8),
        decoration: darkInput(hint: '0' * registrationCodeLength, errorText: _otpTouched ? _otpError : null).copyWith(counterText: ''),
        onChanged: (_) => setState(() => _serverErrors = {..._serverErrors}..remove('otp')),
        onSubmitted: (_) => _verifyAndRegister(),
      ),
      const SizedBox(height: 20),
      WideButton(
        key: const Key('register-verify'),
        label: _loading ? 'Verifying & Registering...' : 'Verify Code & Complete Registration',
        onPressed: _loading ? null : _verifyAndRegister,
      ),
      const SizedBox(height: 12),
      const Divider(color: Color(0x406C757D)),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => setState(() {
              _step = 1;
              _otp.clear();
              _otpTouched = false;
              _serverError = '';
              _serverErrors = const {};
            }),
            child: const Text('Change Email', style: TextStyle(color: AppColors.slate400, fontSize: 13)),
          ),
          TextButton(
            onPressed: _cooldown > 0 || _loading ? null : _resendOtp,
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
    ],
  );

  Widget _success() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(color: Color(0x2622C55E), shape: BoxShape.circle),
          child: const Icon(Icons.check, color: AppColors.green500, size: 34),
        ),
      ),
      const SizedBox(height: 14),
      const Text(
        'Account Registered Successfully',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Text.rich(
        TextSpan(
          style: const TextStyle(color: AppColors.slate400, fontSize: 13),
          children: [
            const TextSpan(text: 'Your student account for '),
            TextSpan(
              text: _email.text,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const TextSpan(text: ' has been verified and registered. You may now sign in using your email address and password.'),
          ],
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 22),
      WideButton(label: 'Proceed to Sign In', onPressed: () => context.go('/login')),
    ],
  );
}
