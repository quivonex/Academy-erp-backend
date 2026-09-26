import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_pill.dart';
import '../data/firm_model.dart';
import '../data/firm_repository.dart';

class FirmsListScreen extends ConsumerWidget {
  const FirmsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firmsAsync = ref.watch(firmsListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Firm Management Directory',
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => ref.invalidate(firmsListProvider),
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _showRegisterDialog(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Register New Firm'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: firmsAsync.when(
            data: (firms) => _FirmsTable(firms: firms),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Could not load firms: $error')),
          ),
        ),
      ],
    );
  }

  void _showRegisterDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _RegisterFirmDialog(),
    );
  }
}

class _FirmsTable extends StatelessWidget {
  const _FirmsTable({required this.firms});
  final List<Firm> firms;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (firms.isEmpty) {
      return Center(
        child: Text(
          'No firms registered yet.',
          style: TextStyle(color: colors.textMuted),
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('FIRM')),
            DataColumn(label: Text('CODE')),
            DataColumn(label: Text('EMAIL')),
            DataColumn(label: Text('PHONE')),
            DataColumn(label: Text('CREATED')),
            DataColumn(label: Text('STATUS')),
          ],
          rows: [
            for (final firm in firms)
              DataRow(
                onSelectChanged: (_) => context.go('/firms/${firm.uuid}'),
                cells: [
                  DataCell(Text(firm.name)),
                  DataCell(Text(firm.code)),
                  DataCell(Text(firm.email ?? '—')),
                  DataCell(Text(firm.phone ?? '—')),
                  DataCell(Text(formatDate(firm.createdAt))),
                  DataCell(_statusPillFor(firm.status)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusPillFor(String status) {
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

/// ---------------------------------------------
/// Register New Firm Dialog  →  POST /firms/
/// ---------------------------------------------
class _RegisterFirmDialog extends ConsumerStatefulWidget {
  const _RegisterFirmDialog();

  @override
  ConsumerState<_RegisterFirmDialog> createState() =>
      _RegisterFirmDialogState();
}

class _RegisterFirmDialogState extends ConsumerState<_RegisterFirmDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  String _status = 'ACTIVE';
  bool _isActive = true;
  bool _isSubmitting = false;
  String? _error;

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
      title: const Text('Register New Firm'),
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
                  decoration: const InputDecoration(
                    labelText: 'Firm code (e.g. ABC002)',
                  ),
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
          _isSubmitting ? null : () => Navigator.of(context).pop(),
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
              : const Text('Register'),
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
      await ref.read(firmRepositoryProvider).create(
        FirmCreateRequest(
          name: _nameController.text.trim(),
          code: _codeController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          address: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          status: _status,
          isActive: _isActive,
        ),
      );

      ref.invalidate(firmsListProvider);
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