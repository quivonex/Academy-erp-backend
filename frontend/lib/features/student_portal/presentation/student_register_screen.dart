import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/back_button.dart';
import '../data/student_portal_repository.dart';
import 'widgets/student_ui.dart';

class StudentRegisterScreen extends ConsumerStatefulWidget {
  const StudentRegisterScreen({
    super.key,
    this.returnTo,
  });

  final String? returnTo;

  @override
  ConsumerState<StudentRegisterScreen> createState() =>
      _StudentRegisterScreenState();
}

class _StudentRegisterScreenState
    extends ConsumerState<StudentRegisterScreen> {
  final formKey = GlobalKey<FormState>();

  final first = TextEditingController();
  final last = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();

  bool busy = false;
  String? error;

  bool _hidePassword = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    for (final controller in [
      first,
      last,
      email,
      phone,
      password,
      confirm,
    ]) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      busy = true;
      error = null;
    });

    try {
      await ref.read(studentPortalRepositoryProvider).register(
        firstName: first.text.trim(),
        lastName: last.text.trim(),
        email: email.text.trim(),
        phone: phone.text.trim(),
        password: password.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created. Please sign in.'),
          ),
        );

        final returnTo = widget.returnTo;

        context.go(
          returnTo == null
              ? '/login'
              : Uri(
                  path: '/login',
                  queryParameters: {'returnTo': returnTo},
                ).toString(),
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _goToLogin() {
    final returnTo = widget.returnTo;

    context.go(
      returnTo == null
          ? '/login'
          : Uri(
              path: '/login',
              queryParameters: {'returnTo': returnTo},
            ).toString(),
    );
  }

  /// 0–4 visual strength score (UI hint only; validation is unchanged).
  int _strength(String value) {
    if (value.isEmpty) return 0;
    var score = 0;
    if (value.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[a-z]').hasMatch(value)) {
      score++;
    }
    if (RegExp(r'\d').hasMatch(value)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    return score;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    final strength = _strength(password.text);
    final strengthLabel = const ['', 'Weak', 'Fair', 'Good', 'Strong'][strength];
    final strengthColor = strength <= 1
        ? colors.danger
        : strength == 2
            ? colors.warning
            : const Color(0xFF10B981);

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        centerTitle: true,
        leading: AppBackButton(
          fallbackRoute: '/login',
          color: Colors.black87,
        ),
        title: const Text('Create account'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BrandBadge()),
                  const SizedBox(height: 20),
                  Text(
                    'Join Academy Learning',
                    textAlign: TextAlign.center,
                    style: textTheme.displayMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Start your student journey and unlock your courses.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: first,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.givenName],
                          decoration: premiumFieldDecoration(
                            context,
                            hint: 'First name',
                            icon: Icons.person_outline_rounded,
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Required'
                                  : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: last,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.familyName],
                          decoration: premiumFieldDecoration(
                            context,
                            hint: 'Last name',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: premiumFieldDecoration(
                      context,
                      hint: 'Email address',
                      icon: Icons.mail_outline_rounded,
                    ),
                    validator: (value) =>
                        value == null || !value.contains('@')
                            ? 'Enter a valid email'
                            : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: premiumFieldDecoration(
                      context,
                      hint: 'Mobile phone (optional)',
                      icon: Icons.smartphone_rounded,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: password,
                    obscureText: _hidePassword,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    onChanged: (_) => setState(() {}),
                    decoration: premiumFieldDecoration(
                      context,
                      hint: 'Create password',
                      icon: Icons.lock_outline_rounded,
                      suffix: IconButton(
                        tooltip:
                            _hidePassword ? 'Show password' : 'Hide password',
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _hidePassword = !_hidePassword),
                      ),
                    ),
                    validator: (value) => value == null || value.length < 8
                        ? 'At least 8 characters'
                        : null,
                  ),
                  if (password.text.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (var i = 0; i < 4; i++) ...[
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 6,
                              decoration: BoxDecoration(
                                color: i < strength
                                    ? strengthColor
                                    : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                          if (i < 3) const SizedBox(width: 4),
                        ],
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 48,
                          child: Text(
                            strengthLabel,
                            textAlign: TextAlign.right,
                            style: textTheme.labelMedium?.copyWith(
                              color: strengthColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: confirm,
                    obscureText: _hideConfirm,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!busy) submit();
                    },
                    decoration: premiumFieldDecoration(
                      context,
                      hint: 'Confirm password',
                      icon: Icons.verified_user_outlined,
                      suffix: IconButton(
                        tooltip:
                            _hideConfirm ? 'Show password' : 'Hide password',
                        icon: Icon(
                          _hideConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _hideConfirm = !_hideConfirm),
                      ),
                    ),
                    validator: (value) => value != password.text
                        ? 'Passwords do not match'
                        : null,
                  ),
                  if (error != null) ...[
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
                              error!,
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        shape: const StadiumBorder(),
                        textStyle: textTheme.titleMedium,
                      ),
                      onPressed: busy ? null : submit,
                      child: busy
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Creating...'),
                              ],
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Create account'),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                      TextButton(
                        onPressed: _goToLogin,
                        child: const Text('Log in'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
