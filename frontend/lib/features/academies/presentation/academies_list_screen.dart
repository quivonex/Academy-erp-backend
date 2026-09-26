import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/status_pill.dart';
import '../data/academy.dart';
import '../data/academy_repository.dart';

class AcademiesListScreen extends ConsumerWidget {
  const AcademiesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final academiesAsync = ref.watch(academiesListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Academy Management Directory', style: Theme.of(context).textTheme.displayMedium),
            ),
            ElevatedButton.icon(
              onPressed: () => _showRegisterDialog(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Register New Academy Branch'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: academiesAsync.when(
            data: (academies) => _AcademiesTable(academies: academies),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Could not load academies: $error')),
          ),
        ),
      ],
    );
  }

  void _showRegisterDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _RegisterAcademyDialog(),
    );
  }
}

class _AcademiesTable extends StatelessWidget {
  const _AcademiesTable({required this.academies});
  final List<Academy> academies;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (academies.isEmpty) {
      return Center(
        child: Text('No academies registered yet.', style: TextStyle(color: colors.textMuted)),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('ACADEMY')),
            DataColumn(label: Text('CODE')),
            DataColumn(label: Text('CITY')),
            DataColumn(label: Text('STATUS')),
          ],
          rows: [
            for (final academy in academies)
              DataRow(cells: [
                DataCell(Text(academy.name)),
                DataCell(Text(academy.code)),
                DataCell(Text(academy.city ?? '—')),
                DataCell(_statusPillFor(academy.status)),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _statusPillFor(String status) {
    final tone = switch (status) {
      'active' => PillTone.success,
      'onboarding' => PillTone.info,
      'suspended' => PillTone.danger,
      _ => PillTone.neutral,
    };
    return StatusPill(label: status.toUpperCase(), tone: tone, compact: true);
  }
}

class _RegisterAcademyDialog extends ConsumerStatefulWidget {
  const _RegisterAcademyDialog();

  @override
  ConsumerState<_RegisterAcademyDialog> createState() => _RegisterAcademyDialogState();
}

class _RegisterAcademyDialogState extends ConsumerState<_RegisterAcademyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _cityController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Register New Academy Branch'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Academy name'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Branch code (e.g. KOTA-02)'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'City'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: context.colors.danger)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
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
      await ref.read(academyRepositoryProvider).create(AcademyCreateRequest(
            name: _nameController.text.trim(),
            code: _codeController.text.trim(),
            city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
          ));
      ref.invalidate(academiesListProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
