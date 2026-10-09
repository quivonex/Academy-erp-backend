import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../student_portal/presentation/widgets/student_ui.dart';
import 'login_model.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.returnTo,
  });

  final String? returnTo;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(sessionControllerProvider.notifier).login(
        LoginRequest(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ),
      );
      // Router redirect will navigate to /dashboard automatically.
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _goToRegister() {
    final returnTo = widget.returnTo;

    if (returnTo == null) {
      context.go('/register');
      return;
    }

    context.go(
      Uri(
        path: '/register',
        queryParameters: {'returnTo': returnTo},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEEF0FF), Color(0xFFF8F7FF)],
            stops: [0, 0.45],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: BrandBadge()),
                      const SizedBox(height: 22),
                      Text(
                        'Welcome back',
                        textAlign: TextAlign.center,
                        style: textTheme.displayMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sign in to your account.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: colors.borderSubtle),
                          boxShadow: colors.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Email
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              decoration: premiumFieldDecoration(
                                context,
                                hint: 'Email address',
                                icon: Icons.mail_outline_rounded,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                if (!value.contains('@')) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Password
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) => _submit(),
                              decoration: premiumFieldDecoration(
                                context,
                                hint: 'Password',
                                icon: Icons.lock_outline_rounded,
                                suffix: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Password is required';
                                }
                                return null;
                              },
                            ),

                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => context.go('/forgot-password'),
                                child: const Text('Forgot password?'),
                              ),
                            ),

                            // Error banner
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colors.dangerBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline_rounded,
                                        size: 18, color: colors.danger),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colors.danger,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),

                            // Submit
                            SizedBox(
                              height: 56,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: colors.primary,
                                  shape: const StadiumBorder(),
                                  elevation: 0,
                                  textStyle: textTheme.titleMedium,
                                ),
                                onPressed: _isSubmitting ? null : _submit,
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('Sign in'),
                                          SizedBox(width: 8),
                                          Icon(Icons.arrow_forward_rounded,
                                              size: 20),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'New here?',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                          TextButton(
                            onPressed: _goToRegister,
                            child: const Text('Create student account'),
                          ),
                        ],
                      ),
                      Center(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            shape: const StadiumBorder(),
                            minimumSize: const Size(0, 44),
                          ),
                          onPressed: () => context.go('/explore'),
                          icon: Icon(Icons.explore_outlined,
                              color: colors.primary),
                          label: const Text('Explore courses'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
