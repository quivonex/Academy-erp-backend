import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/chapter.dart';
import '../data/chapter_repository.dart';

import '../data/lesson.dart';
import '../data/lesson_repository.dart';

class ChapterDetailScreen extends ConsumerStatefulWidget {
  const ChapterDetailScreen({
    super.key,
    required this.subjectUuid,
    required this.chapterUuid,
  });

  final String subjectUuid;
  final String chapterUuid;

  @override
  ConsumerState<ChapterDetailScreen> createState() =>
      _ChapterDetailScreenState();
}

class _ChapterDetailScreenState extends ConsumerState<ChapterDetailScreen> {
  late Future<Chapter> chapterFuture;
  late Future<LessonPage> lessonsFuture;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    chapterFuture = ref
        .read(chapterRepositoryProvider)
        .detail(widget.chapterUuid);

    lessonsFuture = ref
        .read(lessonRepositoryProvider)
        .list(
          chapterUuid: widget.chapterUuid,
        );
  }

  void refresh() {
    setState(reload);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Chapter>(
      future: chapterFuture,
      builder: (
        context,
        chapterSnapshot,
      ) {
        if (chapterSnapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (chapterSnapshot.hasError) {
          return Center(
            child: Text(
              'Could not load chapter:\n'
              '${chapterSnapshot.error}',
            ),
          );
        }

        final chapter = chapterSnapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(
                Icons.arrow_back,
              ),
              label: const Text('Subject'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  child: Text(
                    chapter.sequence.toString(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        chapter.subjectName,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    chapter.isActive ? 'Active' : 'Inactive',
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
                      label: 'Subject',
                      value: chapter.subjectName,
                    ),
                    _InfoRow(
                      label: 'Chapter Title',
                      value: chapter.title,
                    ),
                    _InfoRow(
                      label: 'Sequence',
                      value: chapter.sequence.toString(),
                    ),
                    _InfoRow(
                      label: 'Description',
                      value: chapter.description.isEmpty
                          ? '—'
                          : chapter.description,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Lessons',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    final created = await showDialog<bool>(
                      context: context,
                      builder: (_) => _LessonDialog(
                        chapterUuid: chapter.uuid,
                      ),
                    );

                    if (created == true && mounted) {
                      refresh();
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Add Lesson',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<LessonPage>(
                future: lessonsFuture,
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
                      child: Text(
                        'Could not load lessons:\n'
                        '${snapshot.error}',
                      ),
                    );
                  }

                  final data = snapshot.data!;

                  if (data.results.isEmpty) {
                    return const Center(
                      child: Text(
                        'No lessons added.',
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: data.results.length,
                    itemBuilder: (context, index) {
                      final lesson = data.results[index];

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              lesson.sequence.toString(),
                            ),
                          ),
                          title: Text(
                            lesson.title,
                          ),
                          subtitle: Text(
                            lesson.description.isEmpty
                                ? 'No description'
                                : lesson.description,
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                          ),
                          onTap: () async {
                            await context.push(
                              '/subjects/'
                              '${widget.subjectUuid}'
                              '/chapters/'
                              '${chapter.uuid}'
                              '/lessons/'
                              '${lesson.uuid}',
                            );

                            if (mounted) {
                              refresh();
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LessonDialog extends ConsumerStatefulWidget {
  const _LessonDialog({
    required this.chapterUuid,
  });

  final String chapterUuid;

  @override
  ConsumerState<_LessonDialog> createState() => _LessonDialogState();
}

class _LessonDialogState extends ConsumerState<_LessonDialog> {
  final title = TextEditingController();

  final description = TextEditingController();

  final sequence = TextEditingController(
    text: '1',
  );

  bool saving = false;
  String? error;

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

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await ref.read(lessonRepositoryProvider).create(
            chapterUuid: widget.chapterUuid,
            title: title.text,
            description: description.text,
            sequence: int.tryParse(
                  sequence.text,
                ) ??
                1,
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
      title: const Text('Add Lesson'),
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
            saving ? 'Saving...' : 'Save Lesson',
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
