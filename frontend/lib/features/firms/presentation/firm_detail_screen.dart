import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_pill.dart';
import '../data/firm_model.dart';
import '../data/firm_repository.dart';
import 'firm_admins_section.dart';

class FirmDetailScreen extends ConsumerWidget {
  const FirmDetailScreen({super.key, required this.firmUuid});

  final String firmUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firmAsync = ref.watch(firmDetailProvider(firmUuid));
    final colors = context.colors;

    return firmAsync.when(
      data: (firm) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              firm: firm,
              onEdit: () => _showEditDialog(context, ref, firm),
              onToggleActive: () => _toggleActive(context, ref, firm),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _InfoCard(label: 'Code', value: firm.code),
                _InfoCard(label: 'Email', value: firm.email ?? '—'),
                _InfoCard(label: 'Phone', value: firm.phone ?? '—'),
                _InfoCard(label: 'Status', value: firm.status),
                _InfoCard(
                  label: 'Is Active',
                  value: firm.isActive ? 'Yes' : 'No',
                ),
                _InfoCard(label: 'UUID', value: firm.uuid),
                _InfoCard(
                  label: 'Created',
                  value: formatDate(firm.createdAt),
                ),
                _InfoCard(
                  label: 'Updated',
                  value: firm.updatedAt != null
                      ? formatDate(firm.updatedAt!)
                      : '—',
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (firm.address != null && firm.address!.isNotEmpty) ...[
              Text(
                'ADDRESS',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Text(
                  firm.address!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ─── Firm admins section (GET/POST /firms/{uuid}/admins/) ───
            FirmAdminsSection(firmUuid: firm.uuid),
            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: colors.textMuted, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Users, students, batches and billing panels plug into '
                            'this firm the same way — each via its own '
                            'scoped endpoint.',
                        style: TextStyle(color: colors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Could not load firm: $error')),
    );
  }

  Future<void> _showEditDialog(
      BuildContext context,
      WidgetRef ref,
      Firm firm,
      ) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => _EditFirmDialog(firm: firm),
    );
    if (updated == true) {
      ref.invalidate(firmDetailProvider(firmUuid));
      ref.invalidate(firmsListProvider);
    }
  }

  Future<void> _toggleActive(
      BuildContext context,
      WidgetRef ref,
      Firm firm,
      ) async {
    final repo = ref.read(firmRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final FirmStatusResponse result;
      if (firm.isActive) {
        result = await repo.deactivate(firm.uuid);
      } else {
        result = await repo.activate(firm.uuid);
      }

      messenger.showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      ref.invalidate(firmDetailProvider(firmUuid));
      ref.invalidate(firmsListProvider);
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: context.colors.danger,
        ),
      );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.firm,
    required this.onEdit,
    required this.onToggleActive,
  });

  final Firm firm;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: colors.primary.withOpacity(0.1),
          child: Text(
            firm.name.isNotEmpty ? firm.name[0].toUpperCase() : '?',
            style: TextStyle(color: colors.primary, fontSize: 20),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                firm.name,
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    firm.code,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(width: 12),
                  _StatusPill(status: firm.status),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit'),
        ),
        const SizedBox(width: 8),
        firm.isActive
            ? OutlinedButton.icon(
          onPressed: onToggleActive,
          icon: const Icon(Icons.block, size: 18),
          label: const Text('Deactivate'),
        )
            : FilledButton.icon(
          onPressed: onToggleActive,
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Activate'),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status.toUpperCase()) {
      'ACTIVE' => PillTone.success,
      'INACTIVE' => PillTone.neutral,
      'SUSPENDED' => PillTone.danger,
      _ => PillTone.neutral,
    };
    return StatusPill(
      label: status.toUpperCase(),
      tone: tone,
      compact: true,
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyLarge,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------
/// Edit Firm Dialog  →  PATCH /firms/{uuid}/
/// ---------------------------------------------
class _EditFirmDialog extends ConsumerStatefulWidget {
  const _EditFirmDialog({required this.firm});
  final Firm firm;

  @override
  ConsumerState<_EditFirmDialog> createState() => _EditFirmDialogState();
}

class _EditFirmDialogState extends ConsumerState<_EditFirmDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

  late String _status;
  late bool _isActive;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final f = widget.firm;
    _nameController = TextEditingController(text: f.name);
    _codeController = TextEditingController(text: f.code);
    _emailController = TextEditingController(text: f.email ?? '');
    _phoneController = TextEditingController(text: f.phone ?? '');
    _addressController = TextEditingController(text: f.address ?? '');
    _status = f.status;
    _isActive = f.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Firm'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Firm name'),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(labelText: 'Firm code'),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'ACTIVE', child: Text('ACTIVE')),
                    DropdownMenuItem(
                        value: 'INACTIVE', child: Text('INACTIVE')),
                    DropdownMenuItem(
                        value: 'SUSPENDED', child: Text('SUSPENDED')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'ACTIVE'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Is Active'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
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
          onPressed:
          _isSubmitting ? null : () => Navigator.of(context).pop(false),
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
              : const Text('Save Changes'),
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
      await ref.read(firmRepositoryProvider).update(
        widget.firm.uuid,
        FirmUpdateRequest(
          name: _nameController.text.trim(),
          code: _codeController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          status: _status,
          isActive: _isActive,
        ),
      );

      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}