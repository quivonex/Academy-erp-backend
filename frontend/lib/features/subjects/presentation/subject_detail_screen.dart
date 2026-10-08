import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../teachers/data/teacher.dart';
import '../../teachers/data/teacher_repository.dart';
import '../data/subject.dart';
import '../data/subject_repository.dart';
import '../data/chapter.dart';
import '../data/chapter_repository.dart';

class SubjectDetailScreen extends ConsumerStatefulWidget {
  const SubjectDetailScreen({super.key, required this.subjectUuid});

  final String subjectUuid;

  @override
  ConsumerState<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends ConsumerState<SubjectDetailScreen> {
  late Future<Subject> subjectFuture;
  late Future<ChapterPage> chaptersFuture;
  int page = 1;
  bool busy = false;
  int revision = 0;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(covariant SubjectDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subjectUuid != widget.subjectUuid) {
      revision++;
      page = 1;
      reload();
    }
  }

  void reload() {
    subjectFuture = ref.read(subjectRepositoryProvider).detail(widget.subjectUuid);
    reloadChapters();
  }

  void reloadChapters() {
    chaptersFuture = ref.read(chapterRepositoryProvider).list(
      subjectUuid: widget.subjectUuid,
      page: page,
    );
  }

  void refresh() => setState(reload);

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> editSubject(Subject subject) async {
    if (busy) return;
    final requestRevision = revision;
    setState(() => busy = true);
    try {
      final updated = await showDialog<Subject>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SubjectEditDialog(subject: subject),
      );
      if (!mounted || requestRevision != revision || updated == null) return;
      setState(() => subjectFuture = Future.value(updated));
      showMessage('Subject updated successfully.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> addChapter() async {
    if (busy) return;
    final requestRevision = revision;
    setState(() => busy = true);
    try {
      final created = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ChapterDialog(subjectUuid: widget.subjectUuid),
      );
      if (!mounted || requestRevision != revision || created != true) return;
      setState(() {
        page = 1;
        reloadChapters();
      });
      showMessage('Chapter created successfully.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
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
              context.go('/subjects');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Subjects'),
        ),
      ),
      FutureBuilder<Subject>(
        future: subjectFuture,
        builder: (context, snapshot) {
          final state = adminFutureState(snapshot, noun: 'subject', onRetry: refresh);
          if (state != null) return state;
          final subject = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminPageHeader(
                eyebrow: const AdminEyebrow(section: 'Curriculum', detail: 'Subject details'),
                title: subject.name,
                subtitle: subject.courseName,
                titleTrailing: [ActiveBadge(active: subject.isActive)],
                actions: [
                  AdminOutlineButton(
                    label: 'Refresh',
                    icon: Icons.refresh_rounded,
                    onPressed: busy ? null : refresh,
                  ),
                  GradientButton(
                    label: 'Edit subject',
                    icon: Icons.edit_outlined,
                    onPressed: busy ? null : () => editSubject(subject),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AdminCard(
                child: Column(
                  children: [
                    _InfoRow(label: 'Course', value: subject.courseName),
                    _InfoRow(label: 'Subject name', value: subject.name),
                    _InfoRow(label: 'Subject code', value: subject.code.isEmpty ? '—' : subject.code),
                    _InfoRow(
                      label: 'Teacher',
                      value: (subject.teacherName ?? '').trim().isEmpty
                          ? 'Not assigned'
                          : subject.teacherName!,
                    ),
                    _InfoRow(label: 'Description', value: subject.description.isEmpty ? '—' : subject.description),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Text('Chapters', style: Theme.of(context).textTheme.titleLarge),
                  GradientButton(
                    label: 'Add chapter',
                    icon: Icons.add_rounded,
                    onPressed: busy ? null : addChapter,
                  ),
                ],
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 12),
      FutureBuilder<ChapterPage>(
        future: chaptersFuture,
        builder: (context, snapshot) {
          final state = adminFutureState(
            snapshot,
            noun: 'chapters',
            onRetry: () => setState(reloadChapters),
          );
          if (state != null) return state;
          final data = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (data.results.isEmpty)
                const AdminStateMessage(
                  icon: Icons.menu_book_outlined,
                  title: 'No chapters on this page',
                  message: 'Add a chapter or select another page.',
                ),
              for (final chapter in data.results)
                AdminListRow(
                  title: chapter.title,
                  initials: chapter.sequence.toString(),
                  subtitle: chapter.description.isEmpty ? 'No description' : chapter.description,
                  trailing: [ActiveBadge(active: chapter.isActive)],
                  onTap: busy
                      ? null
                      : () async {
                    final requestRevision = revision;
                    await context.push('/subjects/${widget.subjectUuid}/chapters/${chapter.uuid}');
                    if (mounted && requestRevision == revision) {
                      setState(reloadChapters);
                    }
                  },
                ),
              AdminPager(
                page: page,
                pageSize: 20,
                total: data.count,
                noun: 'chapters',
                onPage: (next) {
                  if (busy) return;
                  setState(() {
                    page = next;
                    reloadChapters();
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

class _SubjectEditDialog extends ConsumerStatefulWidget {
  const _SubjectEditDialog({required this.subject});

  final Subject subject;

  @override
  ConsumerState<_SubjectEditDialog> createState() => _SubjectEditDialogState();
}

class _SubjectEditDialogState extends ConsumerState<_SubjectEditDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController code;
  late final TextEditingController description;
  List<Teacher> teachers = [];
  String? selectedTeacherUuid;
  bool updateTeacher = false;
  bool loadingTeachers = false;
  bool saving = false;
  String? teacherError;
  String? error;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.subject.name);
    code = TextEditingController(text: widget.subject.code);
    description = TextEditingController(text: widget.subject.description);
    loadTeachers();
  }

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> loadTeachers() async {
    if (loadingTeachers || saving) return;
    setState(() {
      loadingTeachers = true;
      teacherError = null;
    });
    try {
      final repository = ref.read(teacherRepositoryProvider);
      final all = <String, Teacher>{};
      var next = 1;
      while (true) {
        final result = await repository.list(isActive: true, page: next);
        if (!mounted) return;
        for (final teacher in result.results) {
          all[teacher.uuid] = teacher;
        }
        if (result.results.isEmpty || next * 20 >= result.count) break;
        next++;
      }
      if (mounted) setState(() => teachers = all.values.toList());
    } on ApiException catch (e) {
      if (mounted) setState(() => teacherError = e.message);
    } catch (_) {
      if (mounted) setState(() => teacherError = 'Could not load teachers. Please retry.');
    } finally {
      if (mounted) setState(() => loadingTeachers = false);
    }
  }

  Future<void> save() async {
    if (saving || !formKey.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final result = await ref.read(subjectRepositoryProvider).update(
        uuid: widget.subject.uuid,
        name: name.text,
        code: code.text,
        description: description.text,
        teacherUuid: selectedTeacherUuid,
        updateTeacher: updateTeacher,
      );
      if (mounted) Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not update subject. Please try again.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AdminFormDialog(
      icon: Icons.edit_outlined,
      title: 'Edit subject',
      subtitle: widget.subject.courseName,
      onClose: saving ? null : () => Navigator.of(context).pop(),
      body: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldLabel(
              label: 'Subject name',
              required: true,
              child: TextFormField(
                controller: name,
                enabled: !saving,
                maxLength: 200,
                decoration: adminFieldDecoration(context, hint: 'Subject name'),
                validator: (value) => (value ?? '').trim().isEmpty ? 'Subject name is required.' : null,
              ),
            ),
            const SizedBox(height: 12),
            FieldLabel(
              label: 'Subject code',
              child: TextFormField(
                controller: code,
                enabled: !saving,
                maxLength: 50,
                decoration: adminFieldDecoration(context, hint: 'Optional code'),
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
                decoration: adminFieldDecoration(context, hint: 'Optional description'),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              updateTeacher
                  ? selectedTeacherUuid == null ? 'Teacher assignment will be removed.' : 'Teacher assignment will be changed.'
                  : 'Current teacher: ${(widget.subject.teacherName ?? '').trim().isEmpty ? 'Not assigned' : widget.subject.teacherName}',
            ),
            const SizedBox(height: 10),
            if (loadingTeachers) const LinearProgressIndicator(),
            if (teacherError != null) ...[
              Text(teacherError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              TextButton(onPressed: saving ? null : loadTeachers, child: const Text('Retry teachers')),
            ],
            if (!loadingTeachers && teacherError == null)
              DropdownButtonFormField<String>(
                value: selectedTeacherUuid,
                isExpanded: true,
                decoration: adminFieldDecoration(context, hint: 'Select replacement teacher'),
                items: [
                  for (final teacher in teachers)
                    DropdownMenuItem(
                      value: teacher.uuid,
                      child: Text('${teacher.fullName} (${teacher.employeeId})', overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: saving
                    ? null
                    : (value) => setState(() {
                  selectedTeacherUuid = value;
                  updateTeacher = true;
                }),
              ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: saving ? null : () => setState(() {
                    selectedTeacherUuid = null;
                    updateTeacher = false;
                  }),
                  child: const Text('Keep original teacher'),
                ),
                TextButton(
                  onPressed: saving ? null : () => setState(() {
                    selectedTeacherUuid = null;
                    updateTeacher = true;
                  }),
                  child: const Text('Remove assignment'),
                ),
              ],
            ),
            if (error != null)
              Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
      actions: [
        AdminOutlineButton(label: 'Cancel', onPressed: saving ? null : () => Navigator.of(context).pop()),
        GradientButton(label: 'Save subject', loading: saving, onPressed: saving ? null : save),
      ],
    ),
  );
}

class _ChapterDialog extends ConsumerStatefulWidget {
  const _ChapterDialog({required this.subjectUuid});

  final String subjectUuid;

  @override
  ConsumerState<_ChapterDialog> createState() => _ChapterDialogState();
}

class _ChapterDialogState extends ConsumerState<_ChapterDialog> {
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final description = TextEditingController();
  final sequence = TextEditingController();
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
    if (saving || !formKey.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ref.read(chapterRepositoryProvider).create(
        subjectUuid: widget.subjectUuid,
        title: title.text.trim(),
        description: description.text.trim(),
        sequence: int.parse(sequence.text.trim()),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not create chapter. Please try again.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AdminFormDialog(
      icon: Icons.menu_book_outlined,
      title: 'Add chapter',
      subtitle: 'Enter the chapter details and an unused sequence number.',
      onClose: saving ? null : () => Navigator.of(context).pop(),
      body: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldLabel(
              label: 'Chapter title',
              required: true,
              child: TextFormField(
                controller: title,
                enabled: !saving,
                maxLength: 255,
                decoration: adminFieldDecoration(context, hint: 'Chapter title'),
                validator: (value) => (value ?? '').trim().isEmpty ? 'Chapter title is required.' : null,
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
                decoration: adminFieldDecoration(context, hint: 'Optional description'),
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
                  if (!RegExp(r'^\d+$').hasMatch(text) || number == null || number > 2147483647) {
                    return 'Enter a whole number from 0 to 2147483647.';
                  }
                  return null;
                },
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        AdminOutlineButton(label: 'Cancel', onPressed: saving ? null : () => Navigator.of(context).pop()),
        GradientButton(label: 'Save chapter', loading: saving, onPressed: saving ? null : save),
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
        final heading = Text(label, style: const TextStyle(fontWeight: FontWeight.w600));
        if (constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, const SizedBox(height: 4), SelectableText(value)],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [SizedBox(width: 150, child: heading), Expanded(child: SelectableText(value))],
        );
      },
    ),
  );
}