import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';
import '../data/student.dart';
import '../data/student_repository.dart';

/// Open with showDialog<Student>; returns the updated student after saving[cite: 26].
class StudentEditScreen extends ConsumerStatefulWidget {
  const StudentEditScreen({
    super.key,
    required this.student,
  });

  final Student student;

  @override
  ConsumerState<StudentEditScreen> createState() =>
      _StudentEditScreenState();
}

class _StudentEditScreenState extends ConsumerState<StudentEditScreen> {
  final form = GlobalKey<FormState>();

  late final fields = <String, TextEditingController>{
    'admission': TextEditingController(
      text: widget.student.admissionNumber,
    ),
    'first': TextEditingController(text: widget.student.firstName),
    'last': TextEditingController(text: widget.student.lastName),
    'email': TextEditingController(text: widget.student.email),
    'phone': TextEditingController(text: widget.student.phone),
    'address': TextEditingController(text: widget.student.address),
    'dob': TextEditingController(
      text: widget.student.dateOfBirth ?? '',
    ),
    'joined': TextEditingController(
      text: widget.student.joinedDate ?? '',
    ),
  };

  late String gender = widget.student.gender;
  bool saving = false;
  String? error;

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String value(String key) => fields[key]!.text.trim();

  String? dateError(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return null;

    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      return 'Use YYYY-MM-DD';
    }

    final parsed = DateTime.tryParse(text);
    if (parsed == null ||
        parsed.year < 1 ||
        parsed.toIso8601String().substring(0, 10) != text) {
      return 'Enter a valid calendar date';
    }

    return null;
  }

  String? emailValidator(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return null;
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)
        ? null
        : 'Enter a valid email';
  }

  Widget _field(
      String key,
      String label, {
        bool required = false,
        int? maxLength,
        int lines = 1,
        TextInputType? keyboard,
        String? hint,
        String? Function(String?)? validator,
      }) =>
      TextFormField(
        controller: fields[key],
        enabled: !saving,
        maxLength: maxLength,
        maxLines: lines,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          border: const OutlineInputBorder(),
          counterText: '',
        ),
        validator: (raw) {
          final text = (raw ?? '').trim();

          if (required && text.isEmpty) {
            return '$label is required';
          }

          if (maxLength != null && text.runes.length > maxLength) {
            return 'Use at most $maxLength characters';
          }

          return validator?.call(raw);
        },
      );

  Widget _genderDropdown() => DropdownButtonFormField<String>(
    value: gender,
    decoration: const InputDecoration(
      labelText: 'Gender',
      border: OutlineInputBorder(),
    ),
    items: const [
      DropdownMenuItem(value: '', child: Text('Not specified')),
      DropdownMenuItem(value: 'MALE', child: Text('Male')),
      DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
      DropdownMenuItem(value: 'OTHER', child: Text('Other')),
    ],
    onChanged: saving ? null : (next) => setState(() => gender = next ?? ''),
  );

  // Two side-by-side widgets on wide containers; stacked on narrow mobile viewports.
  Widget _pairRow(
      BuildContext context, {
        required Widget left,
        required Widget right,
      }) {
    final wide = MediaQuery.sizeOf(context).width >= 520;
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          left,
          const SizedBox(height: 14),
          right,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 14),
        Expanded(child: right),
      ],
    );
  }

  Future<void> save() async {
    if (saving || !(form.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      saving = true;
      error = null;
    });

    try {
      final updated = await ref.read(studentRepositoryProvider).update(
        uuid: widget.student.uuid,
        admissionNumber: value('admission'),
        firstName: value('first'),
        lastName: value('last'),
        email: value('email'),
        phone: value('phone'),
        gender: gender,
        address: value('address'),
        dateOfBirth: value('dob').isEmpty ? null : value('dob'),
        joinedDate: value('joined').isEmpty ? null : value('joined'),
      );

      if (!mounted) return;
      setState(() => saving = false);
      Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          error =
          'Could not confirm the update. Refresh the profile before retrying.';
        });
      }
    } finally {
      if (mounted && saving) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: const Text('Edit student'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Admission number (left) | Email (right)
                _pairRow(
                  context,
                  left: _field(
                    'admission',
                    'Admission number',
                    required: true,
                    maxLength: 50,
                  ),
                  right: _field(
                    'email',
                    'Email',
                    maxLength: 254,
                    keyboard: TextInputType.emailAddress,
                    validator: emailValidator,
                  ),
                ),
                const SizedBox(height: 14),

                // 2. First name (left) | Last name (right)
                _pairRow(
                  context,
                  left: _field(
                    'first',
                    'First name',
                    required: true,
                    maxLength: 100,
                  ),
                  right: _field(
                    'last',
                    'Last name',
                    maxLength: 100,
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Phone (left) | Gender (right)
                _pairRow(
                  context,
                  left: _field(
                    'phone',
                    'Phone',
                    maxLength: 20,
                    keyboard: TextInputType.phone,
                  ),
                  right: _genderDropdown(),
                ),
                const SizedBox(height: 14),

                // 4. Date of birth (left) | Joined date (right)
                _pairRow(
                  context,
                  left: _field(
                    'dob',
                    'Date of birth',
                    hint: 'YYYY-MM-DD',
                    validator: dateError,
                  ),
                  right: _field(
                    'joined',
                    'Joined date',
                    hint: 'YYYY-MM-DD',
                    validator: dateError,
                  ),
                ),
                const SizedBox(height: 14),

                // 5. Full-width Address
                _field('address', 'Address', lines: 3),

                if (error != null) ...[
                  const SizedBox(height: 12),
                  AdminErrorBanner(message: error!),
                ],
                if (saving) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(saving ? 'Saving...' : 'Save changes'),
        ),
      ],
    ),
  );
}