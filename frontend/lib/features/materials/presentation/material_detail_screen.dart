import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';
import '../data/material.dart';
import '../data/material_repository.dart';

class MaterialDetailScreen extends ConsumerStatefulWidget {
  const MaterialDetailScreen({super.key, required this.materialUuid});
  final String materialUuid;

  @override
  ConsumerState<MaterialDetailScreen> createState() =>
      _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends ConsumerState<MaterialDetailScreen> {
  late Future<LearningMaterial> result;
  bool busy = false;
  int revision = 0;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(covariant MaterialDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.materialUuid != widget.materialUuid) {
      revision++;
      busy = false;
      reload();
    }
  }

  void reload() {
    result = ref.read(materialRepositoryProvider).detail(widget.materialUuid);
  }

  void back() {
    if (busy) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/materials');
    }
  }

  void notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> edit(LearningMaterial material) async {
    if (busy) return;
    final ticket = revision;
    setState(() => busy = true);
    try {
      final updated = await showDialog<LearningMaterial>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _EditMaterialDialog(material: material),
      );
      if (!mounted || ticket != revision) return;
      if (updated != null) {
        setState(() => result = Future.value(updated));
        notify('Material updated successfully.');
      }
    } finally {
      if (mounted && ticket == revision) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> delete(LearningMaterial material) async {
    if (busy) return;
    final ticket = revision;
    setState(() => busy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete material?'),
          content: Text(
            'Permanently delete "${material.title}" and its uploaded file? '
                'This cannot be undone. Materials with student progress '
                'records cannot be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (!mounted || ticket != revision || confirmed != true) return;
      await ref.read(materialRepositoryProvider).delete(material.uuid);
      if (!mounted || ticket != revision) return;
      setState(() => busy = false);
      notify('Material deleted successfully.');
      back();
    } on ApiException catch (e) {
      if (mounted && ticket == revision) notify(e.message);
    } catch (_) {
      if (mounted && ticket == revision) {
        notify('Could not delete material. Please try again.');
      }
    } finally {
      if (mounted && ticket == revision) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !busy,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: busy ? null : back,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Materials'),
            ),
            const SizedBox(height: 12),
            FutureBuilder<LearningMaterial>(
              future: result,
              builder: (context, snapshot) {
                final state = adminFutureState(
                  snapshot,
                  noun: 'material',
                  onRetry: () {
                    if (!busy) setState(reload);
                  },
                );
                if (state != null) return state;
                final material = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdminPageHeader(
                      title: material.title,
                      subtitle: material.courseName,
                      titleTrailing: [
                        SoftBadge(label: material.materialType),
                        ActiveBadge(active: material.isActive),
                      ],
                      actions: [
                        GradientButton(
                          label: 'Edit Material',
                          icon: Icons.edit_outlined,
                          onPressed: busy ? null : () => edit(material),
                        ),
                        AdminOutlineButton(
                          label: 'Delete Material',
                          icon: Icons.delete_outline,
                          danger: true,
                          onPressed: busy ? null : () => delete(material),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    AdminCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Material information',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          _InfoRow(
                            label: 'Course',
                            value: material.courseName,
                          ),
                          _InfoRow(
                            label: 'Subject',
                            value: material.subjectName,
                          ),
                          _InfoRow(
                            label: 'Chapter',
                            value: material.chapterTitle,
                          ),
                          _InfoRow(
                            label: 'Lesson',
                            value: material.lessonTitle,
                          ),
                          _InfoRow(
                            label: 'Type',
                            value: material.materialType,
                          ),
                          _InfoRow(
                            label: 'Source',
                            value: material.source,
                          ),
                          _InfoRow(
                            label: 'File key',
                            value: material.fileKey,
                          ),
                          _InfoRow(
                            label: 'External URL',
                            value: material.externalUrl,
                          ),
                          _InfoRow(
                            label: 'Duration',
                            value: material.durationSeconds == null
                                ? null
                                : '${material.durationSeconds} seconds',
                          ),
                          _InfoRow(
                            label: 'Sequence',
                            value: '${material.sequence}',
                          ),
                          _InfoRow(
                            label: 'Available from',
                            value: _formatDate(material.availableFrom),
                          ),
                          _InfoRow(
                            label: 'Available until',
                            value: _formatDate(material.availableUntil),
                          ),
                          _InfoRow(
                            label: 'Required',
                            value: material.isRequired ? 'Yes' : 'No',
                          ),
                          _InfoRow(
                            label: 'Counts toward progress',
                            value: material.countsTowardProgress ? 'Yes' : 'No',
                          ),
                          _InfoRow(
                            label: 'Description',
                            value: material.description,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, this.value});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: FormRow(
      left: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      right: SelectableText(
        value?.trim().isNotEmpty == true ? value! : '—',
      ),
    ),
  );
}

class _EditMaterialDialog extends ConsumerStatefulWidget {
  const _EditMaterialDialog({required this.material});
  final LearningMaterial material;

  @override
  ConsumerState<_EditMaterialDialog> createState() =>
      _EditMaterialDialogState();
}

class _EditMaterialDialogState
    extends ConsumerState<_EditMaterialDialog> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title;
  late final TextEditingController description;
  late final TextEditingController externalUrl;
  late final TextEditingController duration;
  late final TextEditingController sequence;
  DateTime? availableFrom;
  DateTime? availableUntil;
  late bool isRequired;
  late bool countsTowardProgress;
  bool saving = false;
  bool picking = false;
  String? error;
  bool get locked => saving || picking;

  @override
  void initState() {
    super.initState();
    final m = widget.material;
    title = TextEditingController(text: m.title);
    description = TextEditingController(text: m.description);
    externalUrl = TextEditingController(text: m.externalUrl);
    duration = TextEditingController(
      text: m.durationSeconds?.toString() ?? '',
    );
    sequence = TextEditingController(text: '${m.sequence}');
    availableFrom = m.availableFrom?.toLocal();
    availableUntil = m.availableUntil?.toLocal();
    isRequired = m.isRequired;
    countsTowardProgress = m.countsTowardProgress;
  }

  @override
  void dispose() {
    for (final controller in [
      title,
      description,
      externalUrl,
      duration,
      sequence,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? integerError(String? value, {bool optional = false}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return optional ? null : 'Sequence is required.';
    }
    final number = int.tryParse(text);
    if (!RegExp(r'^\d+$').hasMatch(text) ||
        number == null ||
        number < 0 ||
        number > 2147483647) {
      return 'Enter a whole number from 0 to 2147483647.';
    }
    return null;
  }

  Future<void> pick(bool from) async {
    if (locked) return;
    setState(() => picking = true);
    try {
      final initial =
          (from ? availableFrom : availableUntil) ?? DateTime.now();
      final day = DateTime(initial.year, initial.month, initial.day);
      final date = await showDatePicker(
        context: context,
        initialDate: day,
        firstDate: day.isBefore(DateTime(2000))
            ? day
            : DateTime(2000),
        lastDate: day.isAfter(DateTime(2100, 12, 31))
            ? day
            : DateTime(2100, 12, 31),
      );
      if (!mounted || date == null) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );
      if (!mounted || time == null) return;
      final selected = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      setState(() {
        if (from) {
          availableFrom = selected;
        } else {
          availableUntil = selected;
        }
        error = null;
      });
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> save() async {
    if (locked || !form.currentState!.validate()) return;
    if (availableFrom != null &&
        availableUntil != null &&
        !availableUntil!.isAfter(availableFrom!)) {
      setState(() {
        error = 'Available until must be after available from.';
      });
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final updated = await ref.read(materialRepositoryProvider).update(
        uuid: widget.material.uuid,
        title: title.text.trim(),
        description: description.text.trim(),
        externalUrl: externalUrl.text.trim(),
        durationSeconds: duration.text.trim().isEmpty
            ? null
            : int.parse(duration.text.trim()),
        sequence: int.parse(sequence.text.trim()),
        availableFrom: availableFrom,
        availableUntil: availableUntil,
        isRequired: isRequired,
        countsTowardProgress: countsTowardProgress,
      );
      if (mounted) Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Could not save material. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget dateField(String label, DateTime? value, bool from) =>
      FieldLabel(
        label: label,
        child: InputDecorator(
          decoration: adminFieldDecoration(context),
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(_formatDate(value)),
              IconButton(
                tooltip: 'Choose $label',
                onPressed: locked ? null : () => pick(from),
                icon: const Icon(Icons.calendar_month_outlined),
              ),
              if (value != null)
                IconButton(
                  tooltip: 'Clear $label',
                  onPressed: locked
                      ? null
                      : () => setState(() {
                    if (from) {
                      availableFrom = null;
                    } else {
                      availableUntil = null;
                    }
                    error = null;
                  }),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !locked,
    child: AdminFormDialog(
      icon: Icons.edit_outlined,
      title: 'Edit material',
      subtitle: widget.material.courseName,
      onClose: locked
          ? null
          : () => Navigator.of(context).pop(),
      body: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldLabel(
              label: 'Title',
              required: true,
              child: TextFormField(
                controller: title,
                enabled: !locked,
                maxLength: 255,
                decoration: adminFieldDecoration(
                  context,
                  hint: 'Material title',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Title is required.';
                  }
                  if (v.trim().length > 255) {
                    return 'Use at most 255 characters.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            FieldLabel(
              label: 'Description',
              child: TextFormField(
                controller: description,
                enabled: !locked,
                minLines: 3,
                maxLines: 5,
                decoration: adminFieldDecoration(
                  context,
                  hint: 'Optional description',
                ),
              ),
            ),
            if (widget.material.materialType == 'LINK') ...[
              const SizedBox(height: 16),
              FieldLabel(
                label: 'External URL',
                required: true,
                child: TextFormField(
                  controller: externalUrl,
                  enabled: !locked,
                  maxLength: 1000,
                  keyboardType: TextInputType.url,
                  decoration: adminFieldDecoration(
                    context,
                    hint: 'https://...',
                  ),
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    final uri = Uri.tryParse(text);
                    if (text.isEmpty) {
                      return 'External URL is required.';
                    }
                    if (text.length > 1000) {
                      return 'Use at most 1000 characters.';
                    }
                    if (uri == null ||
                        !uri.hasAuthority ||
                        uri.host.isEmpty ||
                        !['http', 'https'].contains(
                          uri.scheme.toLowerCase(),
                        )) {
                      return 'Enter a valid HTTP or HTTPS URL.';
                    }
                    return null;
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            FormRow(
              left: FieldLabel(
                label: 'Duration (seconds)',
                child: TextFormField(
                  controller: duration,
                  enabled: !locked,
                  keyboardType: TextInputType.number,
                  decoration: adminFieldDecoration(
                    context,
                    hint: 'Optional',
                  ),
                  validator: (v) => integerError(v, optional: true),
                ),
              ),
              right: FieldLabel(
                label: 'Sequence',
                required: true,
                child: TextFormField(
                  controller: sequence,
                  enabled: !locked,
                  keyboardType: TextInputType.number,
                  decoration: adminFieldDecoration(
                    context,
                    hint: '1',
                  ),
                  validator: (v) => integerError(v),
                ),
              ),
            ),
            const SizedBox(height: 16),
            dateField('Available from', availableFrom, true),
            const SizedBox(height: 16),
            dateField('Available until', availableUntil, false),
            const SizedBox(height: 8),
            const Text(
              'Dates use your local time. Clear a date to remove '
                  'that availability limit.',
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Required'),
              value: isRequired,
              onChanged: locked
                  ? null
                  : (v) => setState(() => isRequired = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Counts toward progress'),
              value: countsTowardProgress,
              onChanged: locked
                  ? null
                  : (v) => setState(() => countsTowardProgress = v),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              AdminErrorBanner(message: error!),
            ],
          ],
        ),
      ),
      actions: [
        AdminOutlineButton(
          label: 'Cancel',
          onPressed: locked
              ? null
              : () => Navigator.of(context).pop(),
        ),
        GradientButton(
          label: 'Save Changes',
          icon: Icons.check,
          loading: saving,
          onPressed: locked ? null : save,
        ),
      ],
    ),
  );
}

String _formatDate(DateTime? value) {
  if (value == null) return '—';
  final d = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} '
      '${two(d.hour)}:${two(d.minute)}';
}