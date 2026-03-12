import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:correctv1/auth/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordPage({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await AuthService.sendPasswordResetEmail(_emailController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP sent to your email.')),
      );
      setState(() {
        _otpSent = true;
        _otpVerified = false;
      });
    } on AuthException catch (error) {
      _showSnackBar(error.message);
    } catch (_) {
      _showSnackBar('Unable to send reset email right now. Try again later.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Add at least 1 uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Add at least 1 lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) return 'Add at least 1 number';
    return null;
  }

  Future<void> _verifyOtpAndResetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_otpVerified) {
      _showSnackBar('Please verify OTP first.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      await AuthService.updatePassword(_newPasswordController.text);
      TextInput.finishAutofillContext(shouldSave: true);
      await AuthService.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successful.')),
      );
      Navigator.of(context).pop({
        'email': email,
        'password': _newPasswordController.text,
        'showPassword': true,
      });
    } on AuthException catch (error) {
      _showSnackBar(error.message);
    } catch (_) {
      _showSnackBar('Could not reset password. Please check OTP and try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnackBar('Please enter a valid email.');
      return;
    }
    if (otp.length < 6) {
      _showSnackBar('Please enter valid OTP.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthService.verifyRecoveryOtp(email: email, token: otp);
      if (!mounted) return;
      setState(() => _otpVerified = true);
      _showSnackBar('OTP verified.');
    } on AuthException catch (error) {
      setState(() => _otpVerified = false);
      _showSnackBar(error.message);
    } catch (_) {
      setState(() => _otpVerified = false);
      _showSnackBar('Could not verify OTP. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<String> get _failedPasswordRules {
    final password = _newPasswordController.text;
    final failed = <String>[];
    if (password.length < 8) failed.add('Minimum 8 characters');
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      failed.add('At least 1 uppercase letter');
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      failed.add('At least 1 lowercase letter');
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) failed.add('At least 1 number');
    return failed;
  }

  Widget _ruleItem(String text) {
    return Row(
      children: [
        const Icon(
          Icons.cancel_rounded,
          size: 16,
          color: Color(0xFFEF4444),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFFB91C1C),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE6F7F5), Color(0xFFF4FBFA)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x140F172A),
                                blurRadius: 20,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Icon(
                                Icons.mark_email_unread_outlined,
                                color: Color(0xFF2A9D8F),
                                size: 34,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Reset password',
                                textAlign: TextAlign.center,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _otpSent
                                    ? 'Enter OTP from email, then set your new password.'
                                    : 'Enter your email and we will send an OTP.',
                                textAlign: TextAlign.center,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [
                                  AutofillHints.username,
                                  AutofillHints.email,
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                validator: (value) {
                                  final email = value?.trim() ?? '';
                                  if (email.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!email.contains('@')) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              if (_otpSent) ...[
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _otpController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'OTP',
                                    prefixIcon: const Icon(Icons.pin_outlined),
                                    suffixIcon: TextButton(
                                      onPressed: _isLoading ? null : _verifyOtp,
                                      child: Text(
                                        _otpVerified ? 'Verified' : 'Verify',
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (!_otpSent) return null;
                                    final otp = value?.trim() ?? '';
                                    if (otp.isEmpty) return 'Please enter OTP';
                                    if (otp.length < 6) return 'Enter valid OTP';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _newPasswordController,
                                  obscureText: _obscurePassword,
                                  onChanged: (_) => setState(() {}),
                                  autofillHints: const [
                                    AutofillHints.newPassword,
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'New password',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                    ),
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) => _otpSent
                                      ? _validatePassword(value)
                                      : null,
                                ),
                                if (_newPasswordController.text.isNotEmpty &&
                                    _failedPasswordRules.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  ..._failedPasswordRules.map(
                                    (rule) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: _ruleItem(rule),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureConfirmPassword,
                                  autofillHints: const [
                                    AutofillHints.newPassword,
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Confirm new password',
                                    prefixIcon: const Icon(
                                      Icons.verified_user_outlined,
                                    ),
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _obscureConfirmPassword =
                                              !_obscureConfirmPassword;
                                        });
                                      },
                                      icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (!_otpSent) return null;
                                    if (value != _newPasswordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _isLoading
                                    ? null
                                    : (_otpSent
                                          ? _verifyOtpAndResetPassword
                                          : _sendResetLink),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(_otpSent ? 'Reset password' : 'Send OTP'),
                              ),
                              if (_otpSent) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _isLoading ? null : _sendResetLink,
                                  child: const Text('Resend OTP'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
