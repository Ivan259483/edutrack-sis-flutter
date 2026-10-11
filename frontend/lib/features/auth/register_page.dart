import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import 'auth_card.dart';

// Same rules as the web form (frontend/src/pages/RegisterPage.jsx).
final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
bool validName(String v) => v.trim().length >= 2;
bool validEmail(String v) => _emailRegex.hasMatch(v.trim());
bool validPassword(String v) => v.length >= 8 && RegExp('[A-Za-z]').hasMatch(v) && RegExp(r'\d').hasMatch(v);

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
  int _cooldown = 0;
  Timer? _timer;

  bool get _firstValid => validName(_firstName.text);
  bool get _lastValid => validName(_lastName.text);
  bool get _emailValid => validEmail(_email.text);
  bool get _passwordValid => validPassword(_password.text);
  bool get _confirmValid => _confirm.text.isNotEmpty && _confirm.text == _password.text;
  bool get _formValid => _firstValid && _lastValid && _emailValid && _passwordValid && _confirmValid;

  ApiClient get _api => context.read<Session>().api;

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_firstName, _lastName, _email, _password, _confirm, _otp]) {
      c.dispose();
    }
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  Future<void> _sendOtp() async {
    setState(() => _serverError = '');
    if (!_formValid) {
      setState(() => _touched.addAll(['firstName', 'lastName', 'email', 'password', 'confirmPassword']));
      return;
    }
    setState(() => _loading = true);
    try {
      await _api.post('/auth/send-otp', {'email': _email.text.trim()});
      if (!mounted) return;
      setState(() {
        _loading = false;
        _step = 2;
      });
      _startCooldown();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _serverError = apiErrorMessage(error, 'Failed to send verification code. Please try again.');
      });
    }
  }

  Future<void> _resendOtp() async {
    if (_cooldown > 0 || _loading) return;
    setState(() {
      _serverError = '';
      _loading = true;
    });
    try {
      await _api.post('/auth/send-otp', {'email': _email.text.trim()});
      if (!mounted) return;
      setState(() => _loading = false);
      _startCooldown();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _serverError = apiErrorMessage(error, 'Failed to resend code. Please try again.');
      });
    }
  }

  Future<void> _verifyAndRegister() async {
    setState(() => _serverError = '');
    if (_otp.text.trim().length != 5) {
      setState(() => _serverError = 'Please enter the full 5-digit verification code.');
      return;
    }
    setState(() => _loading = true);
    try {
      await _api.post('/auth/verify-otp', {'email': _email.text.trim(), 'otp': _otp.text.trim()});
      await _api.post('/auth/register', {
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
        'program': _program,
        'yearLevel': _yearLevel,
      });
      if (!mounted) return;
      setState(() {
        _loading = false;
        _step = 3;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _serverError = apiErrorMessage(error, 'Verification or registration failed. Please try again.');
      });
    }
  }

  void _changed(String field) => setState(() {
        _touched.add(field);
        _serverError = '';
      });

  @override
  Widget build(BuildContext context) {
    return AuthCard(
      maxWidth: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Student Account Registration',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('EduTrack Student Information System',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.slate400, fontSize: 13)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final (index, color) in [(1, AppColors.blue600), (2, AppColors.blue600), (3, AppColors.green500)]) ...[
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _step >= index ? color : AppColors.slate600,
                    borderRadius: BorderRadius.circular(4),
                  ),
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
    required bool valid,
    required String validText,
    required String invalidText,
    String? hint,
    String? labelSuffix,
    bool obscure = false,
    TextInputType? keyboard,
  }) {
    final touched = _touched.contains(name);
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
            style: const TextStyle(color: Colors.white),
            decoration: darkInput(hint: hint, borderColor: color),
            onChanged: (_) => _changed(name),
          ),
        ),
        if (touched)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(valid ? validText : invalidText, style: TextStyle(fontSize: 11, color: color)),
          ),
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
            items: [for (final o in options) DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => onChanged(v!),
          ),
        ],
      );

  Widget _pair(Widget a, Widget b, {int flexA = 1, int flexB = 1}) => LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 380
            ? Column(children: [a, const SizedBox(height: 14), b])
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(flex: flexA, child: a), const SizedBox(width: 10), Expanded(flex: flexB, child: b)],
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
              valid: _firstValid,
              hint: 'e.g. Gabriel',
              validText: 'Valid first name',
              invalidText: 'Minimum 2 characters required',
            ),
            _field(
              name: 'lastName',
              label: 'Last Name',
              controller: _lastName,
              valid: _lastValid,
              hint: 'e.g. Adiaton',
              validText: 'Valid last name',
              invalidText: 'Minimum 2 characters required',
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
            valid: _emailValid,
            hint: 'e.g. student@gmail.com',
            keyboard: TextInputType.emailAddress,
            validText: 'Valid email format',
            invalidText: 'Please enter a valid email address',
          ),
          const SizedBox(height: 14),
          _pair(
            _field(
              name: 'password',
              label: 'Password',
              controller: _password,
              valid: _passwordValid,
              obscure: true,
              hint: 'Min 8 characters, letters & numbers',
              validText: 'Password meets requirements',
              invalidText: 'At least 8 characters with a letter and a number',
            ),
            _field(
              name: 'confirmPassword',
              label: 'Confirm Password',
              controller: _confirm,
              valid: _confirmValid,
              obscure: true,
              hint: 'Re-enter password',
              validText: 'Passwords match',
              invalidText: 'Passwords do not match',
            ),
          ),
          const SizedBox(height: 22),
          WideButton(
            key: const Key('register-send'),
            label: _loading ? 'Sending Verification Code...' : 'Send Verification Code to Email',
            color: _formValid ? AppColors.blue600 : AppColors.slate700,
            onPressed: _loading || !_formValid ? null : _sendOtp,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Already have an account? ', style: TextStyle(color: AppColors.slate400, fontSize: 13)),
              GestureDetector(
                onTap: () => context.go('/login'),
                child: const Text('Sign In', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
        ],
      );

  Widget _verify() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Check Your Email', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('A 5-digit verification code has been dispatched to:',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.slate400, fontSize: 13)),
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
          const Text('Please check your Gmail inbox or spam/junk folder. The code will expire in 5 minutes.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.slate400, fontSize: 12)),
          const SizedBox(height: 20),
          const Text('Enter 5-Digit Verification Code',
              textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFF8F9FA), fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            key: const Key('register-otp'),
            controller: _otp,
            autofocus: true,
            maxLength: 5,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 28, fontFamily: 'monospace', letterSpacing: 8),
            decoration: darkInput(hint: '00000').copyWith(counterText: ''),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _verifyAndRegister(),
          ),
          const SizedBox(height: 20),
          WideButton(
            key: const Key('register-verify'),
            label: _loading ? 'Verifying & Registering...' : 'Verify Code & Complete Registration',
            onPressed: _loading || _otp.text.length != 5 ? null : _verifyAndRegister,
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
                  _serverError = '';
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
          const Text('Account Registered Successfully',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(style: const TextStyle(color: AppColors.slate400, fontSize: 13), children: [
              const TextSpan(text: 'Your student account for '),
              TextSpan(text: _email.text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const TextSpan(
                  text: ' has been verified and registered. You may now sign in using your email address and password.'),
            ]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          WideButton(label: 'Proceed to Sign In', onPressed: () => context.go('/login')),
        ],
      );
}
