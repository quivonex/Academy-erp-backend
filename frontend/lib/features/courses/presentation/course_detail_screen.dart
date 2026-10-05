import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../course_categories/data/course_category.dart';
import '../../course_categories/data/course_category_repository.dart';
import '../../subjects/data/chapter.dart';
import '../../subjects/data/chapter_repository.dart';
import '../../subjects/data/lesson.dart';
import '../../subjects/data/lesson_repository.dart';
import '../../subjects/data/subject.dart';
import '../../subjects/data/subject_repository.dart';
import '../data/course.dart';
import '../data/course_repository.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  const CourseDetailScreen({super.key, required this.courseUuid});
  final String courseUuid;

  @override
  ConsumerState<CourseDetailScreen> createState() =>
      _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> {
  late Future<Course> result;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(covariant CourseDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courseUuid != widget.courseUuid) reload();
  }

  void reload() {
    result = ref.read(courseRepositoryProvider).detail(widget.courseUuid);
  }

  void goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/courses');
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> toggleStatus(Course course) async {
    if (busy) return;
    final repository = ref.read(courseRepositoryProvider);
    final uuid = course.uuid;
    setState(() => busy = true);
    try {
      final updated = await repository.setPublished(uuid, !course.isPublished);
      if (!mounted || widget.courseUuid != uuid) return;
      setState(() => result = Future<Course>.value(updated));
      showMessage(updated.isPublished
          ? 'Course published successfully.'
          : 'Course unpublished successfully.');
    } on ApiException catch (e) {
      if (mounted && widget.courseUuid == uuid) showMessage(e.message);
    } catch (_) {
      if (mounted && widget.courseUuid == uuid) {
        showMessage('Could not change publication status. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editCourse(Course course) async {
    if (busy) return;
    final repository = ref.read(courseRepositoryProvider);
    final uuid = course.uuid;
    setState(() => busy = true);
    try {
      final updated = await showDialog<Course>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _EditCourseDialog(
          course: course,
          repository: repository,
        ),
      );
      if (!mounted || updated == null || widget.courseUuid != uuid) return;
      setState(() => result = Future<Course>.value(updated));
      showMessage('Course updated successfully.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Course>(
    future: result,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError || !snapshot.hasData) {
        final error = snapshot.error;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: goBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Courses'),
                ),
              ),
              AdminStateMessage(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load course',
                message: error is ApiException
                    ? error.message
                    : 'Please try again.',
                actionLabel: 'Retry',
                onAction: () => setState(reload),
                isError: true,
              ),
            ],
          ),
        );
      }

      final course = snapshot.data!;
      final name = course.name.trim().isEmpty
          ? course.code
          : course.name;
      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: goBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Courses'),
              ),
            ),
            const SizedBox(height: 8),
            AdminCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InitialsBadge(label: adminInitials(name)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SoftBadge(
                              label: course.code,
                              monospace: true,
                            ),
                            ActiveBadge(active: course.isActive),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: busy ? null : () => setState(reload),
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Course information',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 14),
                  _InfoRow(label: 'Code', value: course.code),
                  _InfoRow(label: 'Category', value: course.categoryName ?? ''),
                  _InfoRow(label: 'Price', value: '₹${course.price}'),
                  _InfoRow(label: 'Delivery mode', value: course.deliveryMode),
                  _InfoRow(
                    label: 'Duration',
                    value: course.durationMonths == null
                        ? '—' : '${course.durationMonths} months',
                  ),
                  _InfoRow(
                    label: 'Student access',
                    value: course.accessDurationDays == null
                        ? '—' : '${course.accessDurationDays} days',
                  ),
                  _InfoRow(label: 'Active', value: course.isActive ? 'Yes' : 'No'),
                  _InfoRow(label: 'Published', value: course.isPublished ? 'Yes' : 'No'),
                  _InfoRow(label: 'Purchasable online',
                      value: course.isPurchasableOnline ? 'Yes' : 'No'),
                  _InfoRow(label: 'Featured', value: course.isFeatured ? 'Yes' : 'No'),
                  if (course.isFeatured)
                    _InfoRow(label: 'Featured order',
                        value: course.featuredOrder.toString()),
                  _InfoRow(label: 'Description', value: course.description),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                GradientButton(
                  label: 'Edit course',
                  icon: Icons.edit_outlined,
                  onPressed: busy ? null : () => editCourse(course),
                ),
                AdminOutlineButton(
                  label: course.isPublished
                      ? 'Unpublish course' : 'Publish course',
                  icon: Icons.public_rounded,
                  danger: course.isPublished,
                  onPressed: busy ? null : () => toggleStatus(course),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _CourseCurriculumSection(course: course),
            if (busy) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      );
    },
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final labelWidget = Text(label, style: textTheme.bodySmall);
    final valueWidget = SelectableText(
      value.trim().isEmpty ? '—' : value,
      style: textTheme.bodyMedium,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 480) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget,
                const SizedBox(height: 4),
                valueWidget,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 160, child: labelWidget),
              const SizedBox(width: 16),
              Expanded(child: valueWidget),
            ],
          );
        },
      ),
    );
  }
}

class _CourseCurriculumSection extends ConsumerStatefulWidget {
  const _CourseCurriculumSection({required this.course});
  final Course course;

  @override
  ConsumerState<_CourseCurriculumSection> createState() =>
      _CourseCurriculumSectionState();
}

class _CourseCurriculumSectionState
    extends ConsumerState<_CourseCurriculumSection> {
  late Future<SubjectPage> subjectsFuture;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  void _loadSubjects() {
    subjectsFuture = ref
        .read(subjectRepositoryProvider)
        .list(courseUuid: widget.course.uuid);
  }

  Future<void> _addSubject() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _AddSubjectDialog(courseUuid: widget.course.uuid),
    );
    if (added == true && mounted) {
      setState(_loadSubjects);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          eyebrow: const AdminEyebrow(
            section: 'Curriculum',
            detail: 'Subjects, Chapters & Lessons',
          ),
          title: 'Subjects & Curriculum',
          actions: [
            GradientButton(
              label: 'Add Subject',
              icon: Icons.add_rounded,
              onPressed: _addSubject,
            ),
          ],
        ),
        const SizedBox(height: 14),
        FutureBuilder<SubjectPage>(
          future: subjectsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return AdminStateMessage(
                icon: Icons.error_outline_rounded,
                title: 'Could not load subjects',
                message: 'Please try again.',
                actionLabel: 'Retry',
                onAction: () => setState(_loadSubjects),
                isError: true,
              );
            }

            final subjects = snapshot.data!.results;
            if (subjects.isEmpty) {
              return AdminStateMessage(
                icon: Icons.menu_book_outlined,
                title: 'No subjects in this course yet',
                message: 'Click "Add Subject" to create subjects for this course.',
                actionLabel: 'Add Subject',
                onAction: _addSubject,
              );
            }

            return Column(
              children: [
                for (final subject in subjects)
                  _SubjectCard(
                    subject: subject,
                    onReload: () => setState(_loadSubjects),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SubjectCard extends ConsumerStatefulWidget {
  const _SubjectCard({required this.subject, required this.onReload});
  final Subject subject;
  final VoidCallback onReload;

  @override
  ConsumerState<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends ConsumerState<_SubjectCard> {
  late Future<ChapterPage> chaptersFuture;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  void _loadChapters() {
    chaptersFuture = ref
        .read(chapterRepositoryProvider)
        .list(subjectUuid: widget.subject.uuid);
  }

  Future<void> _addChapter() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _AddChapterDialog(subjectUuid: widget.subject.uuid),
    );
    if (added == true && mounted) {
      setState(_loadChapters);
    }
  }

  Future<void> _editSubject() async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _AddSubjectDialog(
        courseUuid: '',
        subject: widget.subject,
      ),
    );
    if (updated == true && mounted) {
      widget.onReload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.book_rounded, color: Theme.of(context).primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.subject.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.subject.code.isNotEmpty)
                        Text(
                          'Code: ${widget.subject.code}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if ((widget.subject.teacherName ?? '').isNotEmpty)
                        Text(
                          'Teacher: ${widget.subject.teacherName}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _editSubject,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: _addChapter,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Chapter'),
                ),
              ],
            ),
            if (widget.subject.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                widget.subject.description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            FutureBuilder<ChapterPage>(
              future: chaptersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const Text('Could not load chapters.');
                }
                final chapters = snapshot.data!.results;
                if (chapters.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No chapters yet in this subject.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final chapter in chapters)
                      _ChapterTile(
                        chapter: chapter,
                        onReload: () => setState(_loadChapters),
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

class _ChapterTile extends ConsumerStatefulWidget {
  const _ChapterTile({required this.chapter, required this.onReload});
  final Chapter chapter;
  final VoidCallback onReload;

  @override
  ConsumerState<_ChapterTile> createState() => _ChapterTileState();
}

class _ChapterTileState extends ConsumerState<_ChapterTile> {
  late Future<LessonPage> lessonsFuture;
  bool expanded = false;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  void _loadLessons() {
    lessonsFuture = ref
        .read(lessonRepositoryProvider)
        .list(chapterUuid: widget.chapter.uuid);
  }

  Future<void> _addLesson() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _AddLessonDialog(chapterUuid: widget.chapter.uuid),
    );
    if (added == true && mounted) {
      setState(() {
        expanded = true;
        _loadLessons();
      });
    }
  }

  Future<void> _editChapter() async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _AddChapterDialog(
        subjectUuid: '',
        chapter: widget.chapter,
      ),
    );
    if (updated == true && mounted) {
      widget.onReload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ExpansionTile(
        initiallyExpanded: expanded,
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: const Color(0xFFE2E8F0),
          child: Text(
            '${widget.chapter.sequence}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          widget.chapter.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: widget.chapter.description.isNotEmpty
            ? Text(
                widget.chapter.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: _editChapter,
              tooltip: 'Edit Chapter',
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 18),
              onPressed: _addLesson,
              tooltip: 'Add Lesson',
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: FutureBuilder<LessonPage>(
              future: lessonsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const Text('Could not load lessons.');
                }
                final lessons = snapshot.data!.results;
                if (lessons.isEmpty) {
                  return const Text(
                    'No lessons yet in this chapter.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  );
                }
                return Column(
                  children: [
                    for (final lesson in lessons)
                      _LessonRow(
                        lesson: lesson,
                        onReload: () => setState(_loadLessons),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonRow extends ConsumerWidget {
  const _LessonRow({required this.lesson, required this.onReload});
  final Lesson lesson;
  final VoidCallback onReload;

  Future<void> _editLesson(BuildContext context, WidgetRef ref) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _AddLessonDialog(
        chapterUuid: '',
        lesson: lesson,
      ),
    );
    if (updated == true) {
      onReload();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.play_circle_outline_rounded, size: 18),
          const SizedBox(width: 8),
          Text('${lesson.sequence}.',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(lesson.title),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            onPressed: () => _editLesson(context, ref),
            tooltip: 'Edit Lesson',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Dialogs for Curriculum ───────────────────────────

class _AddSubjectDialog extends ConsumerStatefulWidget {
  const _AddSubjectDialog({required this.courseUuid, this.subject});
  final String courseUuid;
  final Subject? subject;

  @override
  ConsumerState<_AddSubjectDialog> createState() => _AddSubjectDialogState();
}

class _AddSubjectDialogState extends ConsumerState<_AddSubjectDialog> {
  final formKey = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.subject?.name ?? '');
  late final code = TextEditingController(text: widget.subject?.code ?? '');
  late final desc =
      TextEditingController(text: widget.subject?.description ?? '');
  bool saving = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (saving || !(formKey.currentState?.validate() ?? false)) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final repo = ref.read(subjectRepositoryProvider);
      if (widget.subject == null) {
        await repo.create(
          courseUuid: widget.courseUuid,
          name: name.text,
          code: code.text,
          description: desc.text,
        );
      } else {
        await repo.update(
          uuid: widget.subject!.uuid,
          name: name.text,
          code: code.text,
          description: desc.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not save subject.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.subject != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Subject' : 'Add Subject'),
      content: Form(
        key: formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Subject Name *'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: code,
                decoration: const InputDecoration(labelText: 'Subject Code'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: desc,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                AdminErrorBanner(message: error!),
              ],
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
          onPressed: saving ? null : _save,
          child: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEdit ? 'Save Changes' : 'Add Subject'),
        ),
      ],
    );
  }
}

class _AddChapterDialog extends ConsumerStatefulWidget {
  const _AddChapterDialog({required this.subjectUuid, this.chapter});
  final String subjectUuid;
  final Chapter? chapter;

  @override
  ConsumerState<_AddChapterDialog> createState() => _AddChapterDialogState();
}

class _AddChapterDialogState extends ConsumerState<_AddChapterDialog> {
  final formKey = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.chapter?.title ?? '');
  late final desc =
      TextEditingController(text: widget.chapter?.description ?? '');
  late final sequence = TextEditingController(
      text: widget.chapter?.sequence.toString() ?? '1');
  bool saving = false;
  String? error;

  @override
  void dispose() {
    title.dispose();
    desc.dispose();
    sequence.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (saving || !(formKey.currentState?.validate() ?? false)) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final repo = ref.read(chapterRepositoryProvider);
      final seq = int.tryParse(sequence.text.trim()) ?? 1;
      if (widget.chapter == null) {
        await repo.create(
          subjectUuid: widget.subjectUuid,
          title: title.text,
          description: desc.text,
          sequence: seq,
        );
      } else {
        await repo.update(
          uuid: widget.chapter!.uuid,
          title: title.text,
          description: desc.text,
          sequence: seq,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not save chapter.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.chapter != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Chapter' : 'Add Chapter'),
      content: Form(
        key: formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Chapter Title *'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: sequence,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sequence Number'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: desc,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                AdminErrorBanner(message: error!),
              ],
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
          onPressed: saving ? null : _save,
          child: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEdit ? 'Save Changes' : 'Add Chapter'),
        ),
      ],
    );
  }
}

class _AddLessonDialog extends ConsumerStatefulWidget {
  const _AddLessonDialog({required this.chapterUuid, this.lesson});
  final String chapterUuid;
  final Lesson? lesson;

  @override
  ConsumerState<_AddLessonDialog> createState() => _AddLessonDialogState();
}

class _AddLessonDialogState extends ConsumerState<_AddLessonDialog> {
  final formKey = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.lesson?.title ?? '');
  late final desc =
      TextEditingController(text: widget.lesson?.description ?? '');
  late final sequence = TextEditingController(
      text: widget.lesson?.sequence.toString() ?? '1');
  bool saving = false;
  String? error;

  @override
  void dispose() {
    title.dispose();
    desc.dispose();
    sequence.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (saving || !(formKey.currentState?.validate() ?? false)) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final repo = ref.read(lessonRepositoryProvider);
      final seq = int.tryParse(sequence.text.trim()) ?? 1;
      if (widget.lesson == null) {
        await repo.create(
          chapterUuid: widget.chapterUuid,
          title: title.text,
          description: desc.text,
          sequence: seq,
        );
      } else {
        await repo.update(
          uuid: widget.lesson!.uuid,
          title: title.text,
          description: desc.text,
          sequence: seq,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not save lesson.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.lesson != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Lesson' : 'Add Lesson'),
      content: Form(
        key: formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Lesson Title *'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: sequence,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sequence Number'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: desc,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                AdminErrorBanner(message: error!),
              ],
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
          onPressed: saving ? null : _save,
          child: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEdit ? 'Save Changes' : 'Add Lesson'),
        ),
      ],
    );
  }
}

class _EditCourseDialog extends ConsumerStatefulWidget {
  const _EditCourseDialog({required this.course, required this.repository});
  final Course course;
  final CourseRepository repository;

  @override
  ConsumerState<_EditCourseDialog> createState() => _EditCourseDialogState();
}

class _EditCourseDialogState extends ConsumerState<_EditCourseDialog> {
  final key = GlobalKey<FormState>();

  late final name = TextEditingController(text: widget.course.name);
  late final code = TextEditingController(text: widget.course.code);
  late final description = TextEditingController(text: widget.course.description);
  late final price = TextEditingController(text: widget.course.price);
  late final durationMonths = TextEditingController(text: widget.course.durationMonths?.toString() ?? '');
  late final accessDays = TextEditingController(text: widget.course.accessDurationDays?.toString() ?? '');
  late final featuredOrder = TextEditingController(text: widget.course.featuredOrder.toString());

  late String mode = widget.course.deliveryMode;

  List<AdminCourseCategory> categories = [];
  AdminCourseCategory? selectedCategory;
  bool categoryChanged = false;
  bool choosingCategory = false;

  late bool isActive = widget.course.isActive;
  late bool isPublished = widget.course.isPublished;
  late bool isPurchasableOnline = widget.course.isPurchasableOnline;
  late bool isFeatured = widget.course.isFeatured;

  bool loadingCategories = false;
  bool saving = false;
  String? error;
  String? categoryError;

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  Future<void> loadCategories() async {
    if (loadingCategories || saving) return;
    final repository = ref.read(courseCategoryRepositoryProvider);
    setState(() {
      loadingCategories = true;
      categoryError = null;
    });
    try {
      final all = <AdminCourseCategory>[];
      var nextPage = 1;
      var received = 0;
      while (true) {
        final response = await repository.list(page: nextPage);
        if (!mounted) return;
        all.addAll(response.results);
        received += response.results.length;
        if (response.results.isEmpty || received >= response.count) break;
        nextPage++;
      }
      if (!mounted) return;
      setState(() {
        final unique = {for (final item in all) item.uuid: item};
        categories = unique.values.where((item) => item.isActive).toList();
        if (selectedCategory == null && widget.course.categoryName != null) {
          try {
            selectedCategory = categories.firstWhere(
              (c) => c.name == widget.course.categoryName,
            );
          } catch (_) {}
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => categoryError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => categoryError = 'Could not load course categories.');
      }
    } finally {
      if (mounted) setState(() => loadingCategories = false);
    }
  }

  Future<void> _addNewCategory() async {
    final newCat = await showDialog<AdminCourseCategory>(
      context: context,
      builder: (_) => const _CreateCategoryQuickDialog(),
    );
    if (newCat != null && mounted) {
      await loadCategories();
      setState(() {
        selectedCategory = categories.firstWhere(
          (c) => c.uuid == newCat.uuid,
          orElse: () => newCat,
        );
        categoryChanged = true;
      });
    }
  }

  String? validateInteger(String? value, {bool optional = false}) {
    final text = (value ?? '').trim();
    if (optional && text.isEmpty) return null;
    final number = int.tryParse(text);
    return number == null || number < 0 || number > 2147483647
        ? 'Enter a whole number from 0 to 2147483647'
        : null;
  }

  String? validatePrice(String? value) {
    final text = (value ?? '').trim();
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) {
      return 'Enter a non-negative price with up to 2 decimal places';
    }
    final whole = text.split('.').first.replaceFirst(RegExp(r'^0+'), '');
    return whole.length > 8 ? 'Maximum price is 99999999.99' : null;
  }

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    description.dispose();
    price.dispose();
    durationMonths.dispose();
    accessDays.dispose();
    featuredOrder.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || loadingCategories) return;
    if (!(key.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() {
      saving = true;
      error = null;
    });

    try {
      final updated = await widget.repository.update(
        uuid: widget.course.uuid,
        name: name.text,
        code: code.text,
        description: description.text,
        price: price.text.trim(),
        deliveryMode: mode,
        categoryUuid: selectedCategory?.uuid,
        updateCategory: true,
        durationMonths: durationMonths.text.trim().isEmpty
            ? null
            : int.parse(durationMonths.text.trim()),
        accessDurationDays: accessDays.text.trim().isEmpty
            ? null
            : int.parse(accessDays.text.trim()),
        isActive: isActive,
        isPublished: isPublished,
        isPurchasableOnline: isPurchasableOnline,
        isFeatured: isFeatured,
        featuredOrder: isFeatured ? int.parse(featuredOrder.text.trim()) : widget.course.featuredOrder,
      );

      if (!mounted) return;
      setState(() => saving = false);
      Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not update course. Please try again.');
      }
    } finally {
      if (mounted && saving) setState(() => saving = false);
    }
  }

  Widget categoryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('cat_edit_${categories.length}_${selectedCategory?.uuid}'),
                value: categories.any((c) => c.uuid == selectedCategory?.uuid)
                    ? selectedCategory?.uuid
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Course Category',
                ),
                items: categories
                    .map(
                      (category) => DropdownMenuItem<String>(
                        value: category.uuid,
                        child: Text(category.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: saving || loadingCategories
                    ? null
                    : (value) {
                        setState(() {
                          selectedCategory = value == null
                              ? null
                              : categories.firstWhere((c) => c.uuid == value);
                          categoryChanged = true;
                        });
                      },
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: saving || loadingCategories ? null : _addNewCategory,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('New'),
            ),
          ],
        ),
        if (loadingCategories) const LinearProgressIndicator(),
        if (categoryError != null) ...[
          const SizedBox(height: 8),
          AdminErrorBanner(message: categoryError!),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: saving ? null : loadCategories,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry categories'),
            ),
          ),
        ],
        if (selectedCategory != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: saving || loadingCategories
                  ? null
                  : () => setState(() {
                        selectedCategory = null;
                        categoryChanged = true;
                      }),
              child: const Text('Clear category'),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AdminFormDialog(
      icon: Icons.edit_outlined,
      title: 'Edit course',
      subtitle: 'Update this course’s information.',
      onClose: saving ? null : () => Navigator.of(context).pop(),
      body: IgnorePointer(
        ignoring: saving,
        child: Form(
          key: key,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                enabled: !saving,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Course name'),
                validator: requiredField,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: code,
                enabled: !saving,
                maxLength: 50,
                decoration: const InputDecoration(labelText: 'Course code'),
                validator: requiredField,
              ),
              const SizedBox(height: 10),
              categoryField(),
              const SizedBox(height: 10),
              TextFormField(
                controller: description,
                enabled: !saving,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: durationMonths,
                enabled: !saving,
                validator: (value) => validateInteger(value, optional: true),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration (Months)',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: accessDays,
                enabled: !saving,
                validator: (value) => validateInteger(value, optional: true),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Student Access Duration (Days)',
                  hintText: 'Example: 180',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: price,
                enabled: !saving,
                decoration: const InputDecoration(labelText: 'Price (₹)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: validatePrice,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: mode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Delivery mode'),
                items: const [
                  DropdownMenuItem(value: 'ONLINE', child: Text('Online')),
                  DropdownMenuItem(value: 'OFFLINE', child: Text('Offline')),
                  DropdownMenuItem(value: 'HYBRID', child: Text('Hybrid')),
                ],
                onChanged: saving ? null : (value) => setState(() => mode = value ?? mode),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: isActive,
                onChanged: saving ? null : (value) {
                  setState(() {
                    isActive = value;
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Published'),
                value: isPublished,
                onChanged: saving ? null : (value) {
                  setState(() {
                    isPublished = value;
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Purchasable Online'),
                value: isPurchasableOnline,
                onChanged: saving ? null : (value) {
                  setState(() {
                    isPurchasableOnline = value;
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Featured Course'),
                value: isFeatured,
                onChanged: saving ? null : (value) {
                  setState(() {
                    isFeatured = value;
                  });
                },
              ),
              if (isFeatured) ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: featuredOrder,
                  enabled: !saving,
                  validator: validateInteger,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Featured Order',
                    hintText: '0 = first priority',
                  ),
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
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
        GradientButton(
          label: 'Save changes',
          icon: Icons.check_rounded,
          loading: saving,
          onPressed: saving || loadingCategories ? null : save,
        ),
      ],
    ),
  );
}

class _CreateCategoryQuickDialog extends ConsumerStatefulWidget {
  const _CreateCategoryQuickDialog();

  @override
  ConsumerState<_CreateCategoryQuickDialog> createState() =>
      __CreateCategoryQuickDialogState();
}

class __CreateCategoryQuickDialogState
    extends ConsumerState<_CreateCategoryQuickDialog> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final descController = TextEditingController();
  bool saving = false;
  String? error;

  @override
  void dispose() {
    nameController.dispose();
    descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (saving || !(formKey.currentState?.validate() ?? false)) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final created = await ref.read(courseCategoryRepositoryProvider).create(
            name: nameController.text,
            description: descController.text,
          );
      if (mounted) Navigator.of(context).pop(created);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not create category.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Course Category'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Category Name *'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              AdminErrorBanner(message: error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : _save,
          child: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save Category'),
        ),
      ],
    );
  }
}

String? requiredField(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;
