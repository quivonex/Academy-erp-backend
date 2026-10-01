import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../courses/data/course.dart';
import '../../courses/data/course_repository.dart';

import '../../teachers/data/teacher.dart';
import '../../teachers/data/teacher_repository.dart';

import '../data/subject.dart';
import '../data/subject_repository.dart';

class SubjectsListScreen extends ConsumerStatefulWidget {
  const SubjectsListScreen({
    super.key,
  });

  @override
  ConsumerState<SubjectsListScreen> createState() =>
      _SubjectsListScreenState();
}

class _SubjectsListScreenState extends ConsumerState<SubjectsListScreen> {
  late Future<SubjectPage> result;

  int page = 1;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    result = ref.read(subjectRepositoryProvider).list(
          page: page,
        );
  }

  void refresh() {
    setState(reload);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Subjects',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            FilledButton.icon(
              onPressed: () async {
                final created = await showDialog<bool>(
                  context: context,
                  builder: (_) => const _SubjectDialog(),
                );

                if (created == true && mounted) {
                  refresh();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Subject'),
            ),
            IconButton(
              onPressed: refresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<SubjectPage>(
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
                  child: Text(
                    'Could not load subjects:\n'
                    '${snapshot.error}',
                  ),
                );
              }

              final data = snapshot.data!;

              if (data.results.isEmpty) {
                return const Center(
                  child: Text('No subjects found.'),
                );
              }

              return ListView.builder(
                itemCount: data.results.length,
                itemBuilder: (context, index) {
                  final subject = data.results[index];

                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(
                          Icons.menu_book_outlined,
                        ),
                      ),
                      title: Text(subject.name),
                      subtitle: Text(
                        '${subject.courseName}'
                        '${subject.code.isEmpty ? '' : ' • ${subject.code}'}'
                        '\nTeacher: '
                        '${subject.teacherName ?? 'Not assigned'}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(
                        Icons.chevron_right,
                      ),
                      onTap: () async {
                        await context.push(
                          '/subjects/${subject.uuid}',
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
  }
}

class _SubjectDialog extends ConsumerStatefulWidget {
  const _SubjectDialog();

  @override
  ConsumerState<_SubjectDialog> createState() => _SubjectDialogState();
}

class _SubjectDialogState extends ConsumerState<_SubjectDialog> {
  final name = TextEditingController();
  final code = TextEditingController();

  Course? selectedCourse;
  Teacher? selectedTeacher;

  List<Course> courses = [];
  List<Teacher> teachers = [];

  bool loadingCourses = false;
  bool loadingTeachers = false;
  bool saving = false;

  String? error;

  @override
  void initState() {
    super.initState();
    loadCoursesAndTeachers();
  }

  Future<void> loadCoursesAndTeachers() async {
    setState(() {
      loadingCourses = true;
      loadingTeachers = true;
    });

    try {
      final cResult = await ref.read(courseRepositoryProvider).list();
      final tResult = await ref.read(teacherRepositoryProvider).list(isActive: true);

      if (mounted) {
        setState(() {
          courses = cResult.results;
          teachers = tResult.results;
        });
      }
    } catch (_) {
      // ignore silently or show in error
    } finally {
      if (mounted) {
        setState(() {
          loadingCourses = false;
          loadingTeachers = false;
        });
      }
    }
  }

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty) {
      setState(() {
        error = 'Subject Name is required.';
      });
      return;
    }

    if (selectedCourse == null) {
      setState(() {
        error = 'Please select a Course.';
      });
      return;
    }

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
      title: const Text('Add Subject'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Subject Name',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: code,
                decoration: const InputDecoration(
                  labelText: 'Subject Code',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCourse?.uuid,
                decoration: const InputDecoration(
                  labelText: 'Course',
                ),
                items: courses
                    .map(
                      (course) => DropdownMenuItem<String>(
                        value: course.uuid,
                        child: Text('${course.name} (${course.code})'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selectedCourse = courses.firstWhere((c) => c.uuid == value);
                    error = null;
                  });
                },
              ),
              if (loadingCourses) const LinearProgressIndicator(),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedTeacher?.uuid,
                decoration: const InputDecoration(
                  labelText: 'Teacher (Optional)',
                ),
                items: teachers
                    .map(
                      (teacher) => DropdownMenuItem<String>(
                        value: teacher.uuid,
                        child: Text('${teacher.fullName} (${teacher.employeeId})'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedTeacher = value == null
                        ? null
                        : teachers.firstWhere((t) => t.uuid == value);
                  });
                },
              ),
              if (loadingTeachers) const LinearProgressIndicator(),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
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
            saving ? 'Saving...' : 'Save Subject',
          ),
        ),
      ],
    );
  }
}
