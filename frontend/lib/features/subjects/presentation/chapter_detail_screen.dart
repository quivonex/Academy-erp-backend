import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';
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
  ConsumerState<ChapterDetailScreen> createState() => _ChapterDetailScreenState();
}

class _ChapterDetailScreenState extends ConsumerState<ChapterDetailScreen> {
  late Future<Chapter> chapterFuture;
  late Future<LessonPage> lessonsFuture;
  int page = 1;
  int revision = 0;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(covariant ChapterDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapterUuid != widget.chapterUuid ||
        oldWidget.subjectUuid != widget.subjectUuid) {
      revision++;
      page = 1;
      reload();
    }
  }

  void reload() {
    reloadChapter();
    reloadLessons();
  }

  void reloadChapter() {
    chapterFuture = ref.read(chapterRepositoryProvider).detail(widget.chapterUuid);
  }

  void reloadLessons() {
    lessonsFuture = ref.read(lessonRepositoryProvider).list(
      chapterUuid: widget.chapterUuid,
      page: page,
    );
  }

  void refresh() {
    if (!busy) setState(reload);
  }

  Future<void> openForm({Chapter? chapter}) async {
    if (busy) return;
    final requestRevision = revision;
    setState(() => busy = true);
    try {
      final result = await showDialog<Object>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ChapterFormDialog(
          chapterUuid: widget.chapterUuid,
          chapter: chapter,
        ),
      );
      if (!mounted || requestRevision != revision || result == null) return;
      if (result is Chapter) {
        setState(() => chapterFuture = Future.value(result));
      } else if (result == true) {
        setState(() {
          page = 1;
          reloadLessons();
        });
      } else {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result is Chapter
              ? 'Chapter updated successfully.'
              : 'Lesson created successfully.'),
        ),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openLesson(Lesson lesson) async {
    if (busy) return;
    final requestRevision = revision;
    await context.push(
      '/subjects/${widget.subjectUuid}'
          '/chapters/${widget.chapterUuid}'
          '/lessons/${lesson.uuid}',
    );
    if (mounted && requestRevision == revision) setState(reloadLessons);
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(bottom: 24),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: busy
              ? null
              : () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/subjects/${widget.subjectUuid}');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Subject'),
        ),
      ),
      FutureBuilder<Chapter>(
        future: chapterFuture,
        builder: (context, snapshot) {
          final state = adminFutureState(
            snapshot,
            noun: 'chapter',
            onRetry: () => setState(reloadChapter),
          );
          if (state != null) return state;
          final chapter = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminPageHeader(
                eyebrow: const AdminEyebrow(
                  section: 'Curriculum',
                  detail: 'Chapter details',
                ),
                title: chapter.title,
                subtitle: chapter.subjectName,
                titleTrailing: [
                  ActiveBadge(active: chapter.isActive),
                ],
                actions: [
                  AdminOutlineButton(
                    label: 'Refresh',
                    icon: Icons.refresh_rounded,
                    onPressed: busy ? null : refresh,
                  ),
                  GradientButton(
                    label: 'Edit chapter',
                    icon: Icons.edit_outlined,
                    onPressed: busy ? null : () => openForm(chapter: chapter),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AdminCard(
                child: Column(
                  children: [
                    _InfoRow(label: 'Subject', value: chapter.subjectName),
                    _InfoRow(label: 'Chapter title', value: chapter.title),
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
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Lessons',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  GradientButton(
                    label: 'Add lesson',
                    icon: Icons.add_rounded,
                    onPressed: busy ? null : () => openForm(),
                  ),
                ],
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 12),
      FutureBuilder<LessonPage>(
        future: lessonsFuture,
        builder: (context, snapshot) {
          final state = adminFutureState(
            snapshot,
            noun: 'lessons',
            onRetry: () => setState(reloadLessons),
          );
          if (state != null) return state;
          final data = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (data.results.isEmpty)
                AdminStateMessage(
                  icon: Icons.menu_book_outlined,
                  title: data.count == 0
                      ? 'No lessons added'
                      : 'No lessons on this page',
                  message: data.count == 0
                      ? 'Use Add lesson to create your first lesson.'
                      : 'Select a previous page to see lessons.',
                ),
              for (final lesson in data.results)
                AdminListRow(
                  title: lesson.title,
                  initials: lesson.sequence.toString(),
                  subtitle: lesson.description.isEmpty
                      ? 'No description'
                      : lesson.description,
                  trailing: [ActiveBadge(active: lesson.isActive)],
                  onTap: busy ? null : () => openLesson(lesson),
                ),
              if (data.count > 0 || page > 1)
                AdminPager(
                  page: page,
                  pageSize: 20,
                  total: data.count,
                  noun: 'lessons',
                  onPage: (next) {
                    if (busy) return;
                    setState(() {
                      page = next;
                      reloadLessons();
                    });
                  },
                ),
            ],
          );
        },
      ),
    ],
  );
}

class _ChapterFormDialog extends ConsumerStatefulWidget {
  const _ChapterFormDialog({
    required this.chapterUuid,
    this.chapter,
  });

  final String chapterUuid;
  final Chapter? chapter;

  @override
  ConsumerState<_ChapterFormDialog> createState() => _ChapterFormDialogState();
}

class _ChapterFormDialogState extends ConsumerState<_ChapterFormDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController title;
  late final TextEditingController description;
  late final TextEditingController sequence;
  bool saving = false;
  String? error;

  bool get editing => widget.chapter != null;
  String get noun => editing ? 'chapter' : 'lesson';

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.chapter?.title ?? '');
    description = TextEditingController(text: widget.chapter?.description ?? '');
    sequence = TextEditingController(
      text: widget.chapter?.sequence.toString() ?? '',
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
    if (saving || !formKey.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final sequenceNumber = int.parse(sequence.text.trim());
      if (editing) {
        final updated = await ref.read(chapterRepositoryProvider).update(
          uuid: widget.chapter!.uuid,
          title: title.text.trim(),
          description: description.text.trim(),
          sequence: sequenceNumber,
        );
        if (mounted) Navigator.of(context).pop(updated);
      } else {
        await ref.read(lessonRepositoryProvider).create(
          chapterUuid: widget.chapterUuid,
          title: title.text.trim(),
          description: description.text.trim(),
          sequence: sequenceNumber,
        );
        if (mounted) Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not save $noun. Please try again.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AdminFormDialog(
      icon: editing ? Icons.edit_outlined : Icons.menu_book_outlined,
      title: editing ? 'Edit chapter' : 'Add lesson',
      subtitle: editing
          ? 'Update the chapter details and sequence.'
          : 'Enter lesson details and an unused sequence in this chapter.',
      onClose: saving ? null : () => Navigator.of(context).pop(),
      body: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldLabel(
              label: editing ? 'Chapter title' : 'Lesson title',
              required: true,
              child: TextFormField(
                controller: title,
                enabled: !saving,
                maxLength: 255,
                decoration: adminFieldDecoration(context, hint: 'Title'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Title is required.'
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            FieldLabel(
              label: 'Description',
              child: TextFormField(
                controller: description,
                enabled: !saving,
                minLines: 3,
                maxLines: 6,
                decoration: adminFieldDecoration(
                  context,
                  hint: 'Optional description',
                ),
              ),
            ),
            const SizedBox(height: 12),
            FieldLabel(
              label: 'Sequence',
              required: true,
              child: TextFormField(
                controller: sequence,
                enabled: !saving,
                keyboardType: TextInputType.number,
                decoration: adminFieldDecoration(context, hint: 'For example, 1'),
                validator: (value) {
                  final text = (value ?? '').trim();
                  final number = int.tryParse(text);
                  if (!RegExp(r'^\d+$').hasMatch(text) ||
                      number == null ||
                      number > 2147483647) {
                    return 'Enter a whole number from 0 to 2147483647.';
                  }
                  return null;
                },
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        AdminOutlineButton(
          label: 'Cancel',
          onPressed: saving ? null : () => Navigator.of(context).pop(),
        ),
        GradientButton(
          label: editing ? 'Save chapter' : 'Add lesson',
          loading: saving,
          onPressed: saving ? null : save,
        ),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final heading = Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        );
        if (constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: 4),
              SelectableText(value),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 150, child: heading),
            Expanded(child: SelectableText(value)),
          ],
        );
      },
    ),
  );
}