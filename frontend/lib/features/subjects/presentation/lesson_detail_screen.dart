import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';
import '../data/lesson.dart';
import '../data/lesson_repository.dart';

class LessonDetailScreen extends ConsumerStatefulWidget {
  const LessonDetailScreen({super.key, required this.lessonUuid});

  final String lessonUuid;

  @override
  ConsumerState<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends ConsumerState<LessonDetailScreen> {
  late Future<Lesson> lessonFuture;
  bool editing = false;
  int revision = 0;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(covariant LessonDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lessonUuid != widget.lessonUuid) {
      revision++;
      reload();
    }
  }

  void reload() {
    lessonFuture = ref.read(lessonRepositoryProvider).detail(widget.lessonUuid);
  }

  void refresh() {
    if (!editing) setState(reload);
  }

  void backToChapter() {
    if (editing) return;
    if (context.canPop()) {
      context.pop();
      return;
    }
    final parameters = GoRouterState.of(context).pathParameters;
    final subjectUuid = parameters['subjectUuid'];
    final chapterUuid = parameters['chapterUuid'];
    if (subjectUuid != null && chapterUuid != null) {
      context.go('/subjects/$subjectUuid/chapters/$chapterUuid');
    } else {
      context.go('/subjects');
    }
  }

  Future<void> editLesson(Lesson lesson) async {
    if (editing) return;
    final requestRevision = revision;
    setState(() => editing = true);
    try {
      final updated = await showDialog<Lesson>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _EditLessonDialog(lesson: lesson),
      );
      if (!mounted || requestRevision != revision || updated == null) return;
      setState(() => lessonFuture = Future.value(updated));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lesson updated successfully.')),
      );
    } finally {
      if (mounted) setState(() => editing = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(bottom: 24),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: editing ? null : backToChapter,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Chapter'),
        ),
      ),
      FutureBuilder<Lesson>(
        future: lessonFuture,
        builder: (context, snapshot) {
          final state = adminFutureState(
            snapshot,
            noun: 'lesson',
            onRetry: refresh,
          );
          if (state != null) return state;
          final lesson = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminPageHeader(
                eyebrow: const AdminEyebrow(
                  section: 'Curriculum',
                  detail: 'Lesson details',
                ),
                title: lesson.title,
                subtitle: lesson.chapterTitle,
                titleTrailing: [ActiveBadge(active: lesson.isActive)],
                actions: [
                  AdminOutlineButton(
                    label: 'Refresh',
                    icon: Icons.refresh_rounded,
                    onPressed: editing ? null : refresh,
                  ),
                  GradientButton(
                    label: 'Edit lesson',
                    icon: Icons.edit_outlined,
                    onPressed: editing ? null : () => editLesson(lesson),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AdminCard(
                child: Column(
                  children: [
                    _InfoRow(label: 'Chapter', value: lesson.chapterTitle),
                    _InfoRow(label: 'Lesson title', value: lesson.title),
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
            ],
          );
        },
      ),
    ],
  );
}

class _EditLessonDialog extends ConsumerStatefulWidget {
  const _EditLessonDialog({required this.lesson});

  final Lesson lesson;

  @override
  ConsumerState<_EditLessonDialog> createState() => _EditLessonDialogState();
}

class _EditLessonDialogState extends ConsumerState<_EditLessonDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController title;
  late final TextEditingController description;
  late final TextEditingController sequence;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.lesson.title);
    description = TextEditingController(text: widget.lesson.description);
    sequence = TextEditingController(text: widget.lesson.sequence.toString());
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
      final updated = await ref.read(lessonRepositoryProvider).update(
        uuid: widget.lesson.uuid,
        title: title.text.trim(),
        description: description.text.trim(),
        sequence: int.parse(sequence.text.trim()),
      );
      if (mounted) Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not update lesson. Please try again.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AdminFormDialog(
      icon: Icons.edit_outlined,
      title: 'Edit lesson',
      subtitle: widget.lesson.chapterTitle,
      onClose: saving ? null : () => Navigator.of(context).pop(),
      body: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldLabel(
              label: 'Lesson title',
              required: true,
              child: TextFormField(
                controller: title,
                enabled: !saving,
                maxLength: 255,
                decoration: adminFieldDecoration(context, hint: 'Lesson title'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Lesson title is required.'
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
          label: 'Save lesson',
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

