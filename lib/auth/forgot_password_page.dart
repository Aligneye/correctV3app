import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:correctv1/auth/auth_service.dart';
import 'package:correctv1/theme/app_theme.dart';

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
  int _resendSecondsRemaining = 0;
  Timer? _resendTimer;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
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
      _startResendCountdown();
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
      final verified = await _verifyOtpInternal(showSuccessSnack: false);
      if (!verified) return;
    }
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      await AuthService.updatePassword(_newPasswordController.text);
      AuthService.setPendingLoginPrefill(
        email: email,
        password: _newPasswordController.text,
        showPassword: true,
      );
      final sessionCleared = await _clearRecoverySession();
      if (!sessionCleared) {
        _showSnackBar('Could not complete reset. Please try again.');
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successful.')),
      );
      Navigator.of(context).pop();
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

  Future<bool> _verifyOtpInternal({bool showSuccessSnack = true}) async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnackBar('Please enter a valid email.');
      return false;
    }
    if (otp.length < 6) {
      _showSnackBar('Please enter valid OTP.');
      return false;
    }
    setState(() => _isLoading = true);
    try {
      await AuthService.verifyRecoveryOtp(email: email, token: otp);
      if (!mounted) return false;
      setState(() => _otpVerified = true);
      if (showSuccessSnack) {
        _showSnackBar('OTP verified.');
      }
      return true;
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _otpVerified = false);
      }
      _showSnackBar(error.message);
      return false;
    } catch (_) {
      if (mounted) {
        setState(() => _otpVerified = false);
      }
      _showSnackBar('Could not verify OTP. Please try again.');
      return false;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    await _verifyOtpInternal(showSuccessSnack: true);
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsRemaining = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsRemaining <= 1) {
        timer.cancel();
        setState(() => _resendSecondsRemaining = 0);
        return;
      }
      setState(() => _resendSecondsRemaining -= 1);
    });
  }

  // mark OTP as unverified when source inputs change
  void _invalidateOtpVerification() {
    if (_otpVerified) {
      setState(() => _otpVerified = false);
    }
  }

  Future<void> _onResendOtpTap() async {
    if (_resendSecondsRemaining > 0 || _isLoading) return;
    await _sendResetLink();
  }

  Future<void> _handleBack() async {
    // If recovery flow started, clear temporary auth session before leaving.
    if (_otpSent || _otpVerified) {
      try {
        await AuthService.signOut(includeGoogle: false);
      } catch (_) {
        // No-op: we still allow navigation back.
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<bool> _clearRecoverySession() async {
    try {
      await AuthService.signOut(includeGoogle: false);
      // Wait briefly for auth state to settle before navigating.
      for (int i = 0; i < 10; i++) {
        if (Supabase.instance.client.auth.currentSession == null) {
          return true;
        }
        await Future.delayed(const Duration(milliseconds: 150));
      }
      return Supabase.instance.client.auth.currentSession == null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _onEmailChanged(String _) async {
    _invalidateOtpVerification();
  }

  Future<void> _onOtpChanged(String _) async {
    _invalidateOtpVerification();
  }

  Future<void> _onPasswordChanged(String _) async {
    _invalidateOtpVerification();
  }

  Future<void> _onConfirmPasswordChanged(String _) async {
    _invalidateOtpVerification();
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
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          Icons.cancel_rounded,
          size: 16,
          color: scheme.error,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: scheme.error,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.pageBackgroundGradientFor(context),
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
                  child: PopScope(
                    canPop: false,
                    onPopInvokedWithResult: (didPop, result) async {
                      if (didPop) return;
                      await _handleBack();
                    },
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: _handleBack,
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: scheme.surface,
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
                              Icon(
                                Icons.mark_email_unread_outlined,
                                color: scheme.primary,
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
                                  color: scheme.onSurface,
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
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                onChanged: _onEmailChanged,
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
                                  onChanged: _onOtpChanged,
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
                                  onChanged: (value) {
                                    setState(() {});
                                    _onPasswordChanged(value);
                                  },
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
                                  onChanged: _onConfirmPasswordChanged,
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
                                  onPressed: _isLoading ||
                                          _resendSecondsRemaining > 0
                                      ? null
                                      : _onResendOtpTap,
                                  child: Text(
                                    _resendSecondsRemaining > 0
                                        ? 'Resend OTP in ${_resendSecondsRemaining}s'
                                        : 'Resend OTP',
                                  ),
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
              ),
              );
            },
          ),
        ),
      ),
    );
  }
}
