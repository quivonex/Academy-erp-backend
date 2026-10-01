import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/subject.dart';
import '../data/subject_repository.dart';

import '../data/chapter.dart';
import '../data/chapter_repository.dart';

class SubjectDetailScreen extends ConsumerStatefulWidget {
  const SubjectDetailScreen({
    super.key,
    required this.subjectUuid,
  });

  final String subjectUuid;

  @override
  ConsumerState<SubjectDetailScreen> createState() =>
      _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends ConsumerState<SubjectDetailScreen> {
  late Future<Subject> subjectFuture;

  late Future<ChapterPage> chaptersFuture;

  @override
  void initState() {
    super.initState();

    reload();
  }

  void reload() {
    subjectFuture = ref
        .read(subjectRepositoryProvider)
        .detail(widget.subjectUuid);

    chaptersFuture = ref
        .read(chapterRepositoryProvider)
        .list(
          subjectUuid: widget.subjectUuid,
        );
  }

  void refresh() {
    setState(reload);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Subject>(
      future: subjectFuture,
      builder: (
        context,
        subjectSnapshot,
      ) {
        if (subjectSnapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (subjectSnapshot.hasError) {
          return Center(
            child: Text(
              'Could not load subject:\n'
              '${subjectSnapshot.error}',
            ),
          );
        }

        final subject = subjectSnapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(
                Icons.arrow_back,
              ),
              label: const Text('Subjects'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  child: Icon(
                    Icons.menu_book_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        subject.courseName,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    subject.isActive ? 'Active' : 'Inactive',
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
                      label: 'Course',
                      value: subject.courseName,
                    ),
                    _InfoRow(
                      label: 'Subject Name',
                      value: subject.name,
                    ),
                    _InfoRow(
                      label: 'Subject Code',
                      value: subject.code.isEmpty ? '—' : subject.code,
                    ),
                    _InfoRow(
                      label: 'Teacher',
                      value: subject.teacherName?.isNotEmpty == true
                          ? subject.teacherName!
                          : 'Not assigned',
                    ),
                    _InfoRow(
                      label: 'Description',
                      value: subject.description.isEmpty
                          ? '—'
                          : subject.description,
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
                    'Chapters',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    final created = await showDialog<bool>(
                      context: context,
                      builder: (_) => _ChapterDialog(
                        subjectUuid: subject.uuid,
                      ),
                    );

                    if (created == true && mounted) {
                      refresh();
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Add Chapter',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<ChapterPage>(
                future: chaptersFuture,
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
                        'Could not load chapters:\n'
                        '${snapshot.error}',
                      ),
                    );
                  }

                  final data = snapshot.data!;

                  if (data.results.isEmpty) {
                    return const Center(
                      child: Text(
                        'No chapters added.',
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: data.results.length,
                    itemBuilder: (context, index) {
                      final chapter = data.results[index];

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              chapter.sequence.toString(),
                            ),
                          ),
                          title: Text(
                            chapter.title,
                          ),
                          subtitle: Text(
                            chapter.description.isEmpty
                                ? 'No description'
                                : chapter.description,
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                          ),
                          onTap: () async {
                            await context.push(
                              '/subjects/'
                              '${subject.uuid}'
                              '/chapters/'
                              '${chapter.uuid}',
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

class _ChapterDialog extends ConsumerStatefulWidget {
  const _ChapterDialog({
    required this.subjectUuid,
  });

  final String subjectUuid;

  @override
  ConsumerState<_ChapterDialog> createState() => _ChapterDialogState();
}

class _ChapterDialogState extends ConsumerState<_ChapterDialog> {
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
        error = 'Chapter title is required.';
      });

      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await ref.read(chapterRepositoryProvider).create(
            subjectUuid: widget.subjectUuid,
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
      title: const Text('Add Chapter'),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(
                labelText: 'Chapter Title',
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
            saving ? 'Saving...' : 'Save Chapter',
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
