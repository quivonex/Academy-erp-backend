import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/assignment.dart';
import '../data/assignment_repository.dart';

class AssignmentEditScreen extends ConsumerStatefulWidget {
  const AssignmentEditScreen({
    super.key,
    required this.assignment,
  });

  final Assignment assignment;

  @override
  ConsumerState<AssignmentEditScreen> createState() =>
      _AssignmentEditScreenState();
}

class _AssignmentEditScreenState
    extends ConsumerState<AssignmentEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _instructions;

  DateTime? _dueAt;
  late bool _allowLateSubmission;

  bool _saving = false;
  bool _choosingDue = false;
  String? _error;

  bool get _busy => _saving || _choosingDue;

  @override
  void initState() {
    super.initState();

    final assignment = widget.assignment;

    _title = TextEditingController(
      text: assignment.title,
    );
    _description = TextEditingController(
      text: assignment.description,
    );
    _instructions = TextEditingController(
      text: assignment.instructions,
    );

    _dueAt = assignment.dueAt?.toLocal();
    _allowLateSubmission = assignment.allowLateSubmission;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _instructions.dispose();
    super.dispose();
  }

  String _dueLabel() {
    final date = _dueAt;

    if (date == null) return 'No deadline';

    String two(int value) =>
        value.toString().padLeft(2, '0');

    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  Future<void> _chooseDue() async {
    if (_busy) return;

    setState(() => _choosingDue = true);

    try {
      final initial = _dueAt ?? DateTime.now();

      final date = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1),
        lastDate: DateTime(9999, 12, 31),
      );

      if (!mounted || date == null) return;

      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );

      if (!mounted || time == null) return;

      setState(() {
        _dueAt = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        _error = null;
      });
    } finally {
      if (mounted) {
        setState(() => _choosingDue = false);
      }
    }
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) {
      return;
    }

    final title = _title.text.trim();
    final description = _description.text.trim();
    final instructions = _instructions.text.trim();
    final dueAt = _dueAt;
    final allowLateSubmission = _allowLateSubmission;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await ref
          .read(assignmentRepositoryProvider)
          .update(
            uuid: widget.assignment.uuid,
            title: title,
            description: description,
            instructions: instructions,
            dueAt: dueAt,
            allowLateSubmission: allowLateSubmission,
          );

      if (!mounted) return;

      Navigator.of(context).pop(updated);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Could not save the assignment. Please retry.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final assignment = widget.assignment;

    return PopScope(
      canPop: !_busy,
      child: Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 640,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        color: colors.primary,
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Edit assignment',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: _busy
                            ? null
                            : () {
                                Navigator.of(context).pop();
                              },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    assignment.courseName,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Assignments with student submissions '
                      'cannot be edited.',
                      style: TextStyle(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _title,
                    enabled: !_busy,
                    maxLength: 255,
                    textCapitalization:
                        TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Title *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final title = value?.trim() ?? '';

                      if (title.isEmpty) {
                        return 'Enter an assignment title.';
                      }

                      if (title.length > 255) {
                        return 'Use 255 characters or fewer.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _description,
                    enabled: !_busy,
                    minLines: 3,
                    maxLines: 6,
                    textCapitalization:
                        TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _instructions,
                    enabled: !_busy,
                    minLines: 3,
                    maxLines: 8,
                    textCapitalization:
                        TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Instructions',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Submission deadline',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _dueLabel(),
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Displayed in your device’s local time.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            _busy ? null : _chooseDue,
                        icon: const Icon(
                          Icons.calendar_month_outlined,
                        ),
                        label: Text(
                          _dueAt == null
                              ? 'Set deadline'
                              : 'Change deadline',
                        ),
                      ),
                      if (_dueAt != null)
                        TextButton.icon(
                          onPressed: _busy
                              ? null
                              : () {
                                  setState(() {
                                    _dueAt = null;
                                    _error = null;
                                  });
                                },
                          icon: const Icon(
                            Icons.clear_rounded,
                          ),
                          label: const Text(
                            'Remove deadline',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Allow late submissions',
                    ),
                    subtitle: const Text(
                      'Students can submit after '
                      'the deadline when enabled.',
                    ),
                    value: _allowLateSubmission,
                    onChanged: _busy
                        ? null
                        : (value) {
                            setState(() {
                              _allowLateSubmission = value;
                            });
                          },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: colors.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () {
                                Navigator.of(context).pop();
                              },
                        child: const Text('Cancel'),
                      ),
                      FilledButton.icon(
                        onPressed: _busy ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.check_rounded,
                              ),
                        label: Text(
                          _saving
                              ? 'Saving...'
                              : 'Save changes',
                        ),
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
