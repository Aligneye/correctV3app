import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:correctv1/auth/auth_service.dart';
import 'package:correctv1/auth/forgot_password_page.dart';
import 'package:correctv1/auth/signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _postRecoveryCooldown = false;
  bool _ignoreNextGoogleTapAfterPrefill = false;
  Timer? _postRecoveryTimer;

  @override
  void initState() {
    super.initState();
    _applyPendingPrefill();
  }

  @override
  void dispose() {
    _postRecoveryTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _applyPendingPrefill() {
    final result = AuthService.consumePendingLoginPrefill();
    if (result == null) return;
    final email = result['email'] as String?;
    final password = result['password'] as String?;
    final showPassword = result['showPassword'] as bool? ?? false;
    setState(() {
      if (email != null && email.isNotEmpty) {
        _emailController.text = email;
      }
      if (password != null && password.isNotEmpty) {
        _passwordController.text = password;
        _obscurePassword = !showPassword;
        _ignoreNextGoogleTapAfterPrefill = true;
      }
    });
    _startPostRecoveryCooldown();
  }

  void _startPostRecoveryCooldown() {
    _postRecoveryTimer?.cancel();
    setState(() => _postRecoveryCooldown = true);
    _postRecoveryTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _postRecoveryCooldown = false);
    });
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await AuthService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      TextInput.finishAutofillContext(shouldSave: true);
    } on AuthException catch (error) {
      _showSnackBar(error.message);
    } catch (_) {
      _showSnackBar('Unable to sign in right now. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_ignoreNextGoogleTapAfterPrefill) {
      setState(() => _ignoreNextGoogleTapAfterPrefill = false);
      _showSnackBar(
        'Tap Continue with Google again if you want Google sign-in.',
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthService.signInWithGoogle();
    } on AuthException catch (error) {
      _showSnackBar(error.message);
    } on PlatformException catch (error) {
      final details = '${error.code}: ${error.message ?? 'Unknown error'}';
      _showSnackBar('Google sign-in failed ($details)');
    } catch (error) {
      _showSnackBar('Google sign-in failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [scheme.primaryContainer, Theme.of(context).scaffoldBackgroundColor],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    Center(
                      child: Image.asset(
                        'assets/logo HQ.png',
                        height: 92,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Log in to track and improve your posture.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
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
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.email,
                              AutofillHints.username,
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
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                              labelText: 'Password',
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
                            validator: (value) {
                              if ((value ?? '').isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isLoading || _postRecoveryCooldown
                                  ? null
                                  : () {
                                      Navigator.of(context)
                                          .push<Map<String, dynamic>>(
                                            MaterialPageRoute<
                                              Map<String, dynamic>
                                            >(
                                              builder: (_) =>
                                                  ForgotPasswordPage(
                                                    initialEmail:
                                                        _emailController.text
                                                            .trim(),
                                                  ),
                                            ),
                                          )
                                          .then((result) {
                                            if (!mounted) return;
                                            _applyPendingPrefill();
                                          });
                                    },
                              child: const Text('Forgot password?'),
                            ),
                          ),
                          FilledButton(
                            onPressed: _isLoading || _postRecoveryCooldown
                                ? null
                                : _signInWithEmail,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Login'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _isLoading || _postRecoveryCooldown
                                ? null
                                : _signInWithGoogle,
                            icon: const Icon(
                              Icons.g_mobiledata_rounded,
                              size: 28,
                            ),
                            label: const Text('Continue with Google'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account?"),
                        TextButton(
                          onPressed: _isLoading || _postRecoveryCooldown
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => SignupPage(
                                        initialEmail: _emailController.text
                                            .trim(),
                                        initialPassword:
                                            _passwordController.text,
                                      ),
                                    ),
                                  );
                                },
                          child: const Text('Sign up'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
