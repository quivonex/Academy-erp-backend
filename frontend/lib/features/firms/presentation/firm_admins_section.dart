import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_pill.dart';
import '../data/firm_admin_model.dart';
import '../data/firm_admin_repository.dart';

/// Section for the Firm Detail screen: lists admins for the given firm
/// and exposes a "Add Firm Admin" action that POSTs to the backend.
class FirmAdminsSection extends ConsumerWidget {
  const FirmAdminsSection({super.key, required this.firmUuid});

  final String firmUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminsAsync = ref.watch(firmAdminsForFirmProvider(firmUuid));
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'FIRM ADMINS',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            TextButton.icon(
              onPressed: () => _showCreateDialog(context, ref),
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: const Text('Add Firm Admin'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        adminsAsync.when(
          data: (admins) {
            if (admins.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Text(
                  'No admins yet for this firm.',
                  style: TextStyle(color: colors.textMuted),
                ),
              );
            }
            return Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('NAME')),
                    DataColumn(label: Text('EMAIL')),
                    DataColumn(label: Text('PHONE')),
                    DataColumn(label: Text('JOINED')),
                    DataColumn(label: Text('STATUS')),
                  ],
                  rows: [
                    for (final admin in admins)
                      DataRow(cells: [
                        DataCell(Text(admin.fullName)),
                        DataCell(Text(admin.email)),
                        DataCell(Text(admin.phone ?? '—')),
                        DataCell(Text(formatDate(admin.dateJoined))),
                        DataCell(
                          StatusPill(
                            label: admin.isActive ? 'ACTIVE' : 'INACTIVE',
                            tone: admin.isActive
                                ? PillTone.success
                                : PillTone.neutral,
                            compact: true,
                          ),
                        ),
                      ]),
                  ],
                ),
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('Could not load admins: $e'),
          ),
        ),
      ],
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _CreateFirmAdminDialog(firmUuid: firmUuid),
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
    return AlertDialog(
      title: const Text('Add Firm Admin'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration:
                        const InputDecoration(labelText: 'First name'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        decoration:
                        const InputDecoration(labelText: 'Last name'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                  (v == null || v.length < 6) ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscure,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: context.colors.danger),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Create Admin'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await ref.read(firmAdminRepositoryProvider).create(
        widget.firmUuid,
        FirmAdminCreateRequest(
          email: _emailController.text.trim(),
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          password: _passwordController.text,
          confirmPassword: _confirmPasswordController.text,
        ),
      );

      ref.invalidate(firmAdminsForFirmProvider(widget.firmUuid));
      ref.invalidate(allFirmAdminsProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}