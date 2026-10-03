import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/status_pill.dart';
import '../data/firm_admin_model.dart';
import '../data/firm_admin_repository.dart';

/// Human label for a backend user type, e.g. FIRM_ADMIN -> "Firm admin".
String prettyUserType(String raw) {
  final value = raw.replaceAll('_', ' ').trim().toLowerCase();
  if (value.isEmpty) return 'Admin';
  return value[0].toUpperCase() + value.substring(1);
}

/// Section for the Firm Detail screen: lists admins for the given firm
/// and exposes a "Add Firm Admin" action that POSTs to the backend.
class FirmAdminsSection extends ConsumerWidget {
  const FirmAdminsSection({
    super.key,
    required this.firmUuid,
    this.firmName,
  });

  final String firmUuid;

  /// Only used for the section subtitle.
  final String? firmName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminsAsync = ref.watch(firmAdminsForFirmProvider(firmUuid));
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final heading = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Firm admins',
                  style: jakarta(
                    textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  firmName == null || firmName!.isEmpty
                      ? 'Authorized personnel managing this firm'
                      : 'Authorized personnel managing $firmName',
                  style: textTheme.bodySmall,
                ),
              ],
            );
            final addButton = GradientButton(
              label: 'Add firm admin',
              icon: Icons.person_add_alt_1_rounded,
              height: 40,
              onPressed: () => _showCreateDialog(context),
            );

            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading,
                  const SizedBox(height: 12),
                  addButton,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: heading),
                const SizedBox(width: 16),
                addButton,
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        adminsAsync.when(
          data: (admins) {
            if (admins.isEmpty) {
              return AdminStateMessage(
                icon: Icons.group_add_outlined,
                title: 'No admins yet',
                message: 'Add the first administrator for this firm.',
              );
            }
            return _AdminsTable(admins: admins);
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => AdminStateMessage(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load admins',
            message: '$e',
            actionLabel: 'Retry',
            onAction: () =>
                ref.invalidate(firmAdminsForFirmProvider(firmUuid)),
            isError: true,
          ),
        ),
      ],
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateFirmAdminDialog(firmUuid: firmUuid),
    );
  }
}

class _AdminsTable extends StatelessWidget {
  const _AdminsTable({required this.admins});

  final List<FirmAdmin> admins;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final headStyle = textTheme.labelMedium?.copyWith(
      color: const Color(0xFF475569),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    );
    const mono = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      color: Color(0xFF334155),
    );

    String nameOf(FirmAdmin a) =>
        a.fullName.trim().isEmpty ? a.email : a.fullName.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Narrow screens: stacked cards instead of a table.
            if (constraints.maxWidth < 1000) {
              return Column(
                children: [
                  for (var i = 0; i < admins.length; i++)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: i == 0
                            ? null
                            : const Border(
                          top: BorderSide(color: Color(0xFFEEF0F5)),
                        ),
                      ),
                      child: Row(
                        children: [
                          InitialsBadge(label: adminInitials(nameOf(admins[i]))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(nameOf(admins[i]),
                                    style: textTheme.titleSmall),
                                Text(admins[i].email,
                                    style: textTheme.bodySmall),
                                Text(
                                  '${admins[i].phone ?? '—'}  •  Joined '
                                      '${formatDate(admins[i].dateJoined)}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colors.textSubtle,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                StatusPill(
                                  label: admins[i].isActive
                                      ? 'ACTIVE'
                                      : 'INACTIVE',
                                  tone: admins[i].isActive
                                      ? PillTone.success
                                      : PillTone.neutral,
                                  compact: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            }

            Widget row(List<Widget> cells, {bool header = false, int i = 0}) {
              return Container(
                height: header ? 46 : 64,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: header ? const Color(0xFFF8FAFC) : Colors.white,
                  border: header
                      ? const Border(
                    bottom: BorderSide(color: Color(0xFFE2E8F0)),
                  )
                      : i == 0
                      ? null
                      : const Border(
                    top: BorderSide(color: Color(0xFFEEF0F5)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 4, child: cells[0]),
                    Expanded(flex: 4, child: cells[1]),
                    Expanded(flex: 2, child: cells[2]),
                    Expanded(flex: 2, child: cells[3]),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: cells[4],
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                row(
                  [
                    Text('NAME', style: headStyle),
                    Text('EMAIL', style: headStyle),
                    Text('PHONE', style: headStyle),
                    Text('JOINED', style: headStyle),
                    Text('STATUS', style: headStyle),
                  ],
                  header: true,
                ),
                for (var i = 0; i < admins.length; i++)
                  row(
                    [
                      Row(
                        children: [
                          InitialsBadge(
                            label: adminInitials(nameOf(admins[i])),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nameOf(admins[i]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.titleSmall?.copyWith(
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  prettyUserType(admins[i].userType),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colors.textSubtle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SelectableText(
                        admins[i].email,
                        maxLines: 1,
                        style: mono,
                      ),
                      Text(
                        admins[i].phone?.isNotEmpty == true
                            ? admins[i].phone!
                            : '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mono,
                      ),
                      Text(
                        formatDate(admins[i].dateJoined),
                        style: textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF334155),
                        ),
                      ),
                      StatusPill(
                        label: admins[i].isActive ? 'ACTIVE' : 'INACTIVE',
                        tone: admins[i].isActive
                            ? PillTone.success
                            : PillTone.neutral,
                        compact: true,
                      ),
                    ],
                    i: i,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CreateFirmAdminDialog extends ConsumerStatefulWidget {
  const _CreateFirmAdminDialog({required this.firmUuid});

  final String firmUuid;

  @override
  ConsumerState<_CreateFirmAdminDialog> createState() =>
      _CreateFirmAdminDialogState();
}

class _CreateFirmAdminDialogState
    extends ConsumerState<_CreateFirmAdminDialog> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscure = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: AdminFormDialog(
        icon: Icons.person_add_alt_1_rounded,
        title: 'Add firm admin',
        subtitle: 'Create an administrator account for this firm.',
        onClose: _isSubmitting ? null : () => Navigator.of(context).pop(),
        body: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FieldLabel(
                label: 'Email',
                required: true,
                child: TextFormField(
                  controller: _emailController,
                  enabled: !_isSubmitting,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: adminFieldDecoration(
                    context,
                    hint: 'admin@academy.edu',
                    icon: Icons.mail_outline_rounded,
                  ),
                  validator: (value) {
                    final email = (value ?? '').trim();

                    if (email.isEmpty) {
                      return 'Email is required';
                    }

                    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                        .hasMatch(email)) {
                      return 'Enter a valid email';
                    }

                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),
              FormRow(
                left: FieldLabel(
                  label: 'First name',
                  child: TextFormField(
                    controller: _firstNameController,
                    enabled: !_isSubmitting,
                    maxLength: 100,
                    textInputAction: TextInputAction.next,
                    decoration: adminFieldDecoration(
                      context,
                      hint: 'Optional',
                      icon: Icons.person_outline_rounded,
                    ),
                  ),
                ),
                right: FieldLabel(
                  label: 'Last name',
                  child: TextFormField(
                    controller: _lastNameController,
                    enabled: !_isSubmitting,
                    maxLength: 100,
                    textInputAction: TextInputAction.next,
                    decoration: adminFieldDecoration(
                      context,
                      hint: 'Optional',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FieldLabel(
                label: 'Phone',
                child: TextFormField(
                  controller: _phoneController,
                  enabled: !_isSubmitting,
                  maxLength: 20,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: adminFieldDecoration(
                    context,
                    hint: 'Optional',
                    icon: Icons.call_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FormRow(
                left: FieldLabel(
                  label: 'Password',
                  required: true,
                  child: TextFormField(
                    controller: _passwordController,
                    enabled: !_isSubmitting,
                    obscureText: _obscure,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    decoration: adminFieldDecoration(
                      context,
                      hint: 'At least 8 characters',
                      icon: Icons.lock_outline_rounded,
                      suffix: IconButton(
                        tooltip:
                        _obscure ? 'Show passwords' : 'Hide passwords',
                        onPressed: _isSubmitting
                            ? null
                            : () => setState(
                              () => _obscure = !_obscure,
                        ),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required';
                      }

                      if (value != value.trim()) {
                        return 'Avoid spaces at the start or end';
                      }

                      if (value.length < 8) {
                        return 'Enter at least 8 characters';
                      }

                      return null;
                    },
                  ),
                ),
                right: FieldLabel(
                  label: 'Confirm password',
                  required: true,
                  child: TextFormField(
                    controller: _confirmPasswordController,
                    enabled: !_isSubmitting,
                    obscureText: _obscure,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    decoration: adminFieldDecoration(
                      context,
                      hint: 'Repeat password',
                      icon: Icons.verified_user_outlined,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Confirm your password';
                      }

                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }

                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                AdminErrorBanner(message: _error!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting
                ? null
                : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF334155),
              minimumSize: const Size(0, 44),
            ),
            child: const Text('Cancel'),
          ),
          GradientButton(
            label: 'Create admin',
            icon: Icons.check_rounded,
            loading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();

    final request = FirmAdminCreateRequest(
      email: _emailController.text.trim().toLowerCase(),
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
    );

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await ref.read(firmAdminRepositoryProvider).create(
        widget.firmUuid,
        request,
      );

      if (!mounted) return;

      ref.invalidate(firmAdminsForFirmProvider(widget.firmUuid));
      ref.invalidate(allFirmAdminsProvider);

      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);

      // Allow the successful dialog to close.
      setState(() => _isSubmitting = false);
      navigator.pop();

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Firm admin created successfully.'),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
              () => _error =
          'Could not create admin. Please try again.',
        );
      }
    } finally {
      if (mounted && _isSubmitting) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
