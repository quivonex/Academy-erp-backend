import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../data/material.dart';
import '../data/material_repository.dart';

class MaterialDetailScreen extends ConsumerStatefulWidget {
  const MaterialDetailScreen({
    super.key,
    required this.materialUuid,
  });

  final String materialUuid;

  @override
  ConsumerState<MaterialDetailScreen> createState() =>
      _MaterialDetailScreenState();
}

class _MaterialDetailScreenState
    extends ConsumerState<MaterialDetailScreen> {
  late Future<LearningMaterial> result;

  bool deleting = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    result = ref
        .read(materialRepositoryProvider)
        .detail(widget.materialUuid);
  }

  Future<void> deleteMaterial(
    LearningMaterial material,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text(
              'Delete Material',
            ),
            content: Text(
              'Are you sure you want to delete "${material.title}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(
                  context,
                  false,
                ),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  true,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    setState(() {
      deleting = true;
    });

    try {
      await ref
          .read(materialRepositoryProvider)
          .delete(material.uuid);

      if (mounted) {
        context.pop();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          deleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LearningMaterial>(
      future: result,
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Could not load material:\n${snapshot.error}',
                ),
                TextButton(
                  onPressed: () {
                    setState(reload);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final material = snapshot.data!;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(
                  Icons.arrow_back,
                ),
                label: const Text('Materials'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    child: Icon(
                      _iconForType(
                        material.materialType,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          material.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          material.courseName,
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(
                      material.materialType,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Material Information',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 18),
                      _InfoRow(
                        label: 'Title',
                        value: material.title,
                      ),
                      _InfoRow(
                        label: 'Course',
                        value: material.courseName,
                      ),
                      _InfoRow(
                        label: 'Subject',
                        value: material.subjectName?.isNotEmpty == true
                            ? material.subjectName!
                            : '—',
                      ),
                      _InfoRow(
                        label: 'Chapter',
                        value: material.chapterTitle?.isNotEmpty == true
                            ? material.chapterTitle!
                            : '—',
                      ),
                      _InfoRow(
                        label: 'Lesson',
                        value: material.lessonTitle?.isNotEmpty == true
                            ? material.lessonTitle!
                            : '—',
                      ),
                      _InfoRow(
                        label: 'Material Type',
                        value: material.materialType,
                      ),
                      _InfoRow(
                        label: 'Source',
                        value: material.source,
                      ),
                      _InfoRow(
                        label: 'File Key',
                        value: material.fileKey.isEmpty
                            ? '—'
                            : material.fileKey,
                      ),
                      _InfoRow(
                        label: 'External URL',
                        value: material.externalUrl.isEmpty
                            ? '—'
                            : material.externalUrl,
                      ),
                      _InfoRow(
                        label: 'Duration',
                        value: material.durationSeconds == null
                            ? '—'
                            : '${material.durationSeconds} sec',
                      ),
                      _InfoRow(
                        label: 'Sequence',
                        value: material.sequence.toString(),
                      ),
                      _InfoRow(
                        label: 'Available From',
                        value: _formatDateTime(
                          material.availableFrom,
                        ),
                      ),
                      _InfoRow(
                        label: 'Available Until',
                        value: _formatDateTime(
                          material.availableUntil,
                        ),
                      ),
                      _InfoRow(
                        label: 'Required',
                        value: material.isRequired ? 'Yes' : 'No',
                      ),
                      _InfoRow(
                        label: 'Counts Toward Progress',
                        value: material.countsTowardProgress ? 'Yes' : 'No',
                      ),
                      _InfoRow(
                        label: 'Status',
                        value: material.isActive ? 'Active' : 'Inactive',
                      ),
                      _InfoRow(
                        label: 'Description',
                        value: material.description.isEmpty
                            ? '—'
                            : material.description,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      final updated = await showDialog<bool>(
                        context: context,
                        builder: (_) => _EditMaterialDialog(
                          material: material,
                        ),
                      );

                      if (updated == true && mounted) {
                        setState(reload);
                      }
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text(
                      'Edit Material',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: deleting
                        ? null
                        : () => deleteMaterial(
                              material,
                            ),
                    icon: const Icon(
                      Icons.delete_outline,
                    ),
                    label: Text(
                      deleting ? 'Deleting...' : 'Delete Material',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EditMaterialDialog extends ConsumerStatefulWidget {
  const _EditMaterialDialog({
    required this.material,
  });

  final LearningMaterial material;

  @override
  ConsumerState<_EditMaterialDialog> createState() =>
      _EditMaterialDialogState();
}

class _EditMaterialDialogState extends ConsumerState<_EditMaterialDialog> {
  late final TextEditingController title;

  late final TextEditingController description;

  late final TextEditingController externalUrl;

  late final TextEditingController duration;

  late final TextEditingController sequence;

  DateTime? availableFrom;
  DateTime? availableUntil;

  bool isRequired = true;

  bool countsTowardProgress = true;

  bool saving = false;

  String? error;

  @override
  void initState() {
    super.initState();

    title = TextEditingController(
      text: widget.material.title,
    );

    description = TextEditingController(
      text: widget.material.description,
    );

    externalUrl = TextEditingController(
      text: widget.material.externalUrl,
    );

    duration = TextEditingController(
      text: widget.material.durationSeconds?.toString() ?? '',
    );

    sequence = TextEditingController(
      text: widget.material.sequence.toString(),
    );

    availableFrom = widget.material.availableFrom;

    availableUntil = widget.material.availableUntil;

    isRequired = widget.material.isRequired;

    countsTowardProgress = widget.material.countsTowardProgress;
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    externalUrl.dispose();
    duration.dispose();
    sequence.dispose();

    super.dispose();
  }

  Future<DateTime?> pickDateTime(
    DateTime? current,
  ) async {
    final initial = current ?? DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (date == null || !mounted) {
      return null;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        initial,
      ),
    );

    if (time == null) {
      return null;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty) {
      setState(() {
        error = 'Title is required.';
      });

      return;
    }

    if (availableFrom != null &&
        availableUntil != null &&
        !availableUntil!.isAfter(availableFrom!)) {
      setState(() {
        error = 'Available until must be after available from.';
      });

      return;
    }

    if (widget.material.materialType == 'LINK' &&
        externalUrl.text.trim().isEmpty) {
      setState(() {
        error = 'External URL is required for link material.';
      });

      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await ref.read(materialRepositoryProvider).update(
            uuid: widget.material.uuid,
            title: title.text,
            description: description.text,
            externalUrl: externalUrl.text,
            durationSeconds: int.tryParse(
              duration.text,
            ),
            sequence: int.tryParse(
                  sequence.text,
                ) ??
                1,
            availableFrom: availableFrom,
            availableUntil: availableUntil,
            isRequired: isRequired,
            countsTowardProgress: countsTowardProgress,
          );

      if (mounted) {
        Navigator.pop(
          context,
          true,
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Material'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                ),
              ),
              if (widget.material.materialType == 'LINK') ...[
                const SizedBox(
                  height: 12,
                ),
                TextField(
                  controller: externalUrl,
                  decoration: const InputDecoration(
                    labelText: 'External URL',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: duration,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration Seconds',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sequence,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Sequence',
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Available From',
                ),
                subtitle: Text(
                  _formatDateTime(
                    availableFrom,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (availableFrom != null)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            availableFrom = null;
                          });
                        },
                        icon: const Icon(
                          Icons.close,
                        ),
                      ),
                    const Icon(
                      Icons.calendar_month,
                    ),
                  ],
                ),
                onTap: () async {
                  final value = await pickDateTime(
                    availableFrom,
                  );

                  if (value != null && mounted) {
                    setState(() {
                      availableFrom = value;
                    });
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Available Until',
                ),
                subtitle: Text(
                  _formatDateTime(
                    availableUntil,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (availableUntil != null)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            availableUntil = null;
                          });
                        },
                        icon: const Icon(
                          Icons.close,
                        ),
                      ),
                    const Icon(
                      Icons.calendar_month,
                    ),
                  ],
                ),
                onTap: () async {
                  final value = await pickDateTime(
                    availableUntil,
                  );

                  if (value != null && mounted) {
                    setState(() {
                      availableUntil = value;
                    });
                  }
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Required'),
                value: isRequired,
                onChanged: (value) {
                  setState(() {
                    isRequired = value;
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Counts Toward Progress',
                ),
                value: countsTowardProgress,
                onChanged: (value) {
                  setState(() {
                    countsTowardProgress = value;
                  });
                },
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(
                    top: 12,
                  ),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(
            saving ? 'Saving...' : 'Save Changes',
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }
}

IconData _iconForType(
  String type,
) {
  switch (type) {
    case 'VIDEO':
      return Icons.videocam_outlined;

    case 'PDF':
      return Icons.picture_as_pdf_outlined;

    case 'DOCUMENT':
      return Icons.description_outlined;

    case 'LINK':
      return Icons.link;

    default:
      return Icons.insert_drive_file_outlined;
  }
}

String _formatDateTime(
  DateTime? value,
) {
  if (value == null) {
    return '—';
  }

  final local = value.toLocal();

  String twoDigits(int value) => value.toString().padLeft(2, '0');

  return '${twoDigits(local.day)}/'
      '${twoDigits(local.month)}/'
      '${local.year} '
      '${twoDigits(local.hour)}:'
      '${twoDigits(local.minute)}';
}
