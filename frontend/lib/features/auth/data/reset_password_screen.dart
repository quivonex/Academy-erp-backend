import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../student_portal/presentation/widgets/student_ui.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.email,
  });

  final String email;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState
    extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final authService = AuthService(ref.read(dioProvider));

      await authService.confirmPasswordReset(
        email: widget.email,
        otp: _otpController.text.trim(),
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_outline_rounded,
            color: Color(0xFF047857),
            size: 38,
          ),
          title: const Text('Password reset successful'),
          content: const Text(
            'Your password has been updated. Please sign in using your new password.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Sign in'),
            ),
          ],
        ),
      );

      if (mounted) {
        context.go('/login');
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
              () => _errorMessage =
          'Could not reset the password. Check the OTP and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.go('/forgot-password'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
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
          top: false,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: BrandBadge()),
                      const SizedBox(height: 24),
                      Text(
                        'Set new password',
                        textAlign: TextAlign.center,
                        style: textTheme.displayMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter the six-digit OTP sent to ${widget.email}.',
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
                            TextFormField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              maxLength: 6,
                              decoration: premiumFieldDecoration(
                                context,
                                hint: 'Six-digit OTP',
                                icon: Icons.password_rounded,
                              ).copyWith(counterText: ''),
                              validator: (value) {
                                if ((value?.trim().length ?? 0) != 6) {
                                  return 'Enter the six-digit OTP';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: _obscureNewPassword,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [
                                AutofillHints.newPassword,
                              ],
                              decoration: premiumFieldDecoration(
                                context,
                                hint: 'New password',
                                icon: Icons.lock_outline_rounded,
                                suffix: IconButton(
                                  onPressed: () => setState(
                                        () => _obscureNewPassword =
                                    !_obscureNewPassword,
                                  ),
                                  icon: Icon(
                                    _obscureNewPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if ((value?.length ?? 0) < 8) {
                                  return 'Password must be at least 8 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              autofillHints: const [
                                AutofillHints.newPassword,
                              ],
                              decoration: premiumFieldDecoration(
                                context,
                                hint: 'Confirm new password',
                                icon: Icons.lock_reset_rounded,
                                suffix: IconButton(
                                  onPressed: () => setState(
                                        () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                                  ),
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value != _newPasswordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colors.dangerBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colors.danger,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 56,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: colors.primary,
                                  shape: const StadiumBorder(),
                                  elevation: 0,
                                ),
                                onPressed: _isSubmitting ? null : _submit,
                                child: _isSubmitting
                                    ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                                    : const Text('Reset password'),
                              ),
                            ),
                          ],
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