import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../courses/data/course.dart';
import '../../courses/data/course_repository.dart';
import '../../teachers/data/teacher.dart';
import '../../teachers/data/teacher_repository.dart';
import '../data/subject.dart';
import '../data/subject_repository.dart';

class SubjectsListScreen extends ConsumerStatefulWidget {
  const SubjectsListScreen({super.key});

  @override
  ConsumerState<SubjectsListScreen> createState() => _SubjectsListScreenState();
}

class _SubjectsListScreenState extends ConsumerState<SubjectsListScreen> {
  late Future<SubjectPage> result;
  int page = 1;
  bool creating = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    result = ref.read(subjectRepositoryProvider).list(page: page);
  }

  void refresh() => setState(reload);

  void goToPage(int next) {
    setState(() {
      page = next;
      reload();
    });
  }

  Future<void> openCreate() async {
    if (creating) return;
    setState(() => creating = true);
    try {
      final created = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _SubjectDialog(),
      );
      if (!mounted || created != true) return;
      setState(() {
        page = 1;
        reload();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject created successfully.')),
      );
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AdminPageHeader(
        eyebrow: const AdminEyebrow(
          section: 'Curriculum',
          detail: 'Subjects & teacher assignments',
        ),
        title: 'Subjects',
        titleTrailing: [
          IconButton(
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
        actions: [
          GradientButton(
            label: 'Add subject',
            icon: Icons.add_rounded,
            onPressed: creating ? null : openCreate,
          ),
        ],
      ),
      const SizedBox(height: 20),
      Expanded(
        child: FutureBuilder<SubjectPage>(
          future: result,
          builder: (context, snapshot) {
            final state = adminFutureState(
              snapshot,
              noun: 'subjects',
              onRetry: refresh,
            );
            if (state != null) return state;
            final data = snapshot.data!;
            if (data.results.isEmpty) {
              return AdminStateMessage(
                icon: Icons.menu_book_outlined,
                title: 'No subjects found',
                message: 'Add a subject to organise your course.',
                actionLabel: 'Add subject',
                onAction: creating ? null : openCreate,
              );
            }

            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                for (final subject in data.results)
                  AdminListRow(
                    title: subject.name,
                    icon: Icons.menu_book_outlined,
                    subtitle: subject.courseName,
                    meta: [
                      if (subject.code.isNotEmpty)
                        SoftBadge(label: subject.code, monospace: true),
                      MetaChip(
                        icon: Icons.person_outline_rounded,
                        label: (subject.teacherName ?? '').trim().isEmpty
                            ? 'Teacher not assigned'
                            : subject.teacherName!,
                      ),
                    ],
                    trailing: [ActiveBadge(active: subject.isActive)],
                    onTap: () async {
                      await context.push('/subjects/${subject.uuid}');
                      if (mounted) refresh();
                    },
                  ),
                AdminPager(
                  page: page,
                  pageSize: 20,
                  total: data.count,
                  noun: 'subjects',
                  onPage: goToPage,
                ),
              ],
            );
          },
        ),
      ),
    ],
  );
}

class _SubjectDialog extends ConsumerStatefulWidget {
  const _SubjectDialog();

  @override
  ConsumerState<_SubjectDialog> createState() => _SubjectDialogState();
}

class _SubjectDialogState extends ConsumerState<_SubjectDialog> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final code = TextEditingController();
  Course? selectedCourse;
  Teacher? selectedTeacher;
  List<Course> courses = [];
  List<Teacher> teachers = [];
  bool loadingCourses = false;
  bool loadingTeachers = false;
  bool saving = false;
  String? courseError;
  String? teacherError;
  String? error;

  @override
  void initState() {
    super.initState();
    loadCourses();
    loadTeachers();
  }

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> loadCourses() async {
    if (loadingCourses || saving) return;
    final repository = ref.read(courseRepositoryProvider);
    setState(() {
      loadingCourses = true;
      courseError = null;
    });
    try {
      final all = <Course>[];
      var next = 1;
      var received = 0;
      while (true) {
        final response = await repository.list(page: next);
        if (!mounted) return;
        all.addAll(response.results);
        received += response.results.length;
        if (response.results.isEmpty || received >= response.count) break;
        next++;
      }
      if (!mounted) return;
      setState(() {
        courses = {for (final course in all) course.uuid: course}.values.toList();
        if (!courses.any((c) => c.uuid == selectedCourse?.uuid)) {
          selectedCourse = null;
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => courseError = e.message);
    } catch (_) {
      if (mounted) setState(() => courseError = 'Could not load courses.');
    } finally {
      if (mounted) setState(() => loadingCourses = false);
    }
  }

  Future<void> loadTeachers() async {
    if (loadingTeachers || saving) return;
    final repository = ref.read(teacherRepositoryProvider);
    setState(() {
      loadingTeachers = true;
      teacherError = null;
    });
    try {
      final all = <Teacher>[];
      var next = 1;
      var received = 0;
      while (true) {
        final response = await repository.list(page: next, isActive: true);
        if (!mounted) return;
        all.addAll(response.results);
        received += response.results.length;
        if (response.results.isEmpty || received >= response.count) break;
        next++;
      }
      if (!mounted) return;
      setState(() {
        teachers = {for (final teacher in all) teacher.uuid: teacher}.values.toList();
        if (!teachers.any((t) => t.uuid == selectedTeacher?.uuid)) {
          selectedTeacher = null;
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => teacherError = e.message);
    } catch (_) {
      if (mounted) setState(() => teacherError = 'Could not load teachers.');
    } finally {
      if (mounted) setState(() => loadingTeachers = false);
    }
  }

  Future<void> save() async {
    if (saving || loadingCourses || loadingTeachers) return;
    if (!(formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ref.read(subjectRepositoryProvider).create(
        courseUuid: selectedCourse!.uuid,
        name: name.text,
        code: code.text,
        teacherUuid: selectedTeacher?.uuid,
      );
      if (!mounted) return;
      setState(() => saving = false);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not create subject. Please try again.');
      }
    } finally {
      if (mounted && saving) setState(() => saving = false);
    }
  }

  Widget loadError(String message, VoidCallback retry) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 8),
      AdminErrorBanner(message: message),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: saving ? null : retry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AdminFormDialog(
      icon: Icons.menu_book_outlined,
      title: 'Add subject',
      subtitle: 'Assign a subject to a course and optionally a teacher.',
      onClose: saving ? null : () => Navigator.of(context).pop(),
      body: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldLabel(
              label: 'Subject name',
              required: true,
              child: TextFormField(
                controller: name,
                enabled: !saving,
                maxLength: 200,
                textInputAction: TextInputAction.next,
                decoration: adminFieldDecoration(context),
                validator: (value) =>
                value == null || value.trim().isEmpty
                    ? 'Subject name is required' : null,
              ),
            ),
            const SizedBox(height: 16),
            FieldLabel(
              label: 'Subject code',
              child: TextFormField(
                controller: code,
                enabled: !saving,
                maxLength: 50,
                textInputAction: TextInputAction.next,
                decoration: adminFieldDecoration(context, hint: 'Optional'),
              ),
            ),
            const SizedBox(height: 16),
            FieldLabel(
              label: 'Course',
              required: true,
              child: DropdownButtonFormField<String>(
                key: ValueKey('course_${selectedCourse?.uuid}_${courses.length}'),
                value: selectedCourse?.uuid,
                isExpanded: true,
                decoration: adminFieldDecoration(
                  context,
                  hint: loadingCourses ? 'Loading courses…' : 'Select course',
                ),
                items: courses.map((course) => DropdownMenuItem<String>(
                  value: course.uuid,
                  child: Text('${course.name} (${course.code})',
                      overflow: TextOverflow.ellipsis),
                )).toList(),
                validator: (value) => value == null ? 'Select a course' : null,
                onChanged: saving || loadingCourses ? null : (value) {
                  if (value == null) return;
                  setState(() {
                    selectedCourse = courses.firstWhere((c) => c.uuid == value);
                  });
                },
              ),
            ),
            if (loadingCourses) const LinearProgressIndicator(),
            if (courseError != null) loadError(courseError!, loadCourses),
            if (!loadingCourses && courseError == null && courses.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Create a course before adding a subject.'),
              ),
            const SizedBox(height: 16),
            FieldLabel(
              label: 'Teacher',
              child: DropdownButtonFormField<String>(
                key: ValueKey('teacher_${selectedTeacher?.uuid}_${teachers.length}'),
                value: selectedTeacher?.uuid,
                isExpanded: true,
                decoration: adminFieldDecoration(
                  context,
                  hint: loadingTeachers ? 'Loading teachers…' : 'Optional',
                ),
                items: teachers.map((teacher) => DropdownMenuItem<String>(
                  value: teacher.uuid,
                  child: Text('${teacher.fullName} (${teacher.employeeId})',
                      overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: saving || loadingTeachers ? null : (value) {
                  setState(() {
                    selectedTeacher = value == null
                        ? null : teachers.firstWhere((t) => t.uuid == value);
                  });
                },
              ),
            ),
            if (loadingTeachers) const LinearProgressIndicator(),
            if (teacherError != null) loadError(teacherError!, loadTeachers),
            if (selectedTeacher != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: saving
                      ? null : () => setState(() => selectedTeacher = null),
                  child: const Text('Clear teacher'),
                ),
              ),
            if (error != null) ...[
              const SizedBox(height: 16),
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
        GradientButton(
          label: 'Save subject',
          icon: Icons.check_rounded,
          loading: saving,
          onPressed: saving || loadingCourses || loadingTeachers
              ? null : save,
        ),
      ],
    ),
  );
}
