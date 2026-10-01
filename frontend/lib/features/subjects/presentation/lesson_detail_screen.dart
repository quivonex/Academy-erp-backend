import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/lesson.dart';
import '../data/lesson_repository.dart';

class LessonDetailScreen extends ConsumerStatefulWidget {
  const LessonDetailScreen({
    super.key,
    required this.lessonUuid,
  });

  final String lessonUuid;

  @override
  ConsumerState<LessonDetailScreen> createState() =>
      _LessonDetailScreenState();
}

class _LessonDetailScreenState extends ConsumerState<LessonDetailScreen> {
  late Future<Lesson> lessonFuture;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    lessonFuture = ref
        .read(lessonRepositoryProvider)
        .detail(widget.lessonUuid);
  }

  void refresh() {
    setState(reload);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Lesson>(
      future: lessonFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load lesson:\n'
              '${snapshot.error}',
            ),
          );
        }

        final lesson = snapshot.data!;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(
                  Icons.arrow_back,
                ),
                label: const Text(
                  'Chapter',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    child: Text(
                      lesson.sequence.toString(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lesson.chapterTitle,
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(
                      lesson.isActive ? 'Active' : 'Inactive',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(
                        label: 'Chapter',
                        value: lesson.chapterTitle,
                      ),
                      _InfoRow(
                        label: 'Lesson Title',
                        value: lesson.title,
                      ),
                      _InfoRow(
                        label: 'Sequence',
                        value: lesson.sequence.toString(),
                      ),
                      _InfoRow(
                        label: 'Description',
                        value: lesson.description.isEmpty
                            ? '—'
                            : lesson.description,
                      ),
                      _InfoRow(
                        label: 'Status',
                        value: lesson.isActive ? 'Active' : 'Inactive',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  final updated = await showDialog<bool>(
                    context: context,
                    builder: (_) => _EditLessonDialog(
                      lesson: lesson,
                    ),
                  );

                  if (updated == true && mounted) {
                    refresh();
                  }
                },
                icon: const Icon(
                  Icons.edit_outlined,
                ),
                label: const Text(
                  'Edit Lesson',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EditLessonDialog extends ConsumerStatefulWidget {
  const _EditLessonDialog({
    required this.lesson,
  });

  final Lesson lesson;

  @override
  ConsumerState<_EditLessonDialog> createState() => _EditLessonDialogState();
}

class _EditLessonDialogState extends ConsumerState<_EditLessonDialog> {
  late final TextEditingController title;

  late final TextEditingController description;

  late final TextEditingController sequence;

  bool saving = false;

  String? error;

  @override
  void initState() {
    super.initState();

    title = TextEditingController(
      text: widget.lesson.title,
    );

    description = TextEditingController(
      text: widget.lesson.description,
    );

    sequence = TextEditingController(
      text: widget.lesson.sequence.toString(),
    );
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    sequence.dispose();

    super.dispose();
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty) {
      setState(() {
        error = 'Lesson title is required.';
      });

      return;
    }

    final sequenceValue = int.tryParse(
      sequence.text.trim(),
    );

    if (sequenceValue == null || sequenceValue <= 0) {
      setState(() {
        error = 'Please enter a valid sequence.';
      });

      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await ref.read(lessonRepositoryProvider).update(
            uuid: widget.lesson.uuid,
            title: title.text,
            description: description.text,
            sequence: sequenceValue,
          );

      if (mounted) {
        Navigator.pop(
          context,
          true,
        );
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
      title: const Text('Edit Lesson'),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(
                labelText: 'Lesson Title',
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
            const SizedBox(height: 12),
            TextField(
              controller: sequence,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Sequence',
              ),
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
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(
            saving ? 'Saving...' : 'Update Lesson',
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
        vertical: 6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
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
