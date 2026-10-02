import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../courses/data/course.dart';
import '../../courses/data/course_repository.dart';

import '../../subjects/data/subject.dart';
import '../../subjects/data/subject_repository.dart';

import '../../subjects/data/chapter.dart';
import '../../subjects/data/chapter_repository.dart';

import '../../subjects/data/lesson.dart';
import '../../subjects/data/lesson_repository.dart';

import '../data/assignment.dart';
import '../data/assignment_repository.dart';

class AssignmentsListScreen extends ConsumerStatefulWidget {
  const AssignmentsListScreen({
    super.key,
  });

  @override
  ConsumerState<AssignmentsListScreen> createState() =>
      _AssignmentsListScreenState();
}

class _AssignmentsListScreenState
    extends ConsumerState<AssignmentsListScreen> {
  final searchController = TextEditingController();

  late Future<AssignmentPage> result;

  String search = '';

  int page = 1;

  @override
  void initState() {
    super.initState();

    reload();
  }

  void reload() {
    result = ref.read(assignmentRepositoryProvider).list(
          search: search,
          page: page,
        );
  }

  void refresh() {
    setState(reload);
  }

  void applySearch() {
    setState(() {
      search = searchController.text.trim();

      page = 1;

      reload();
    });
  }

  void changePage(int value) {
    setState(() {
      page = value;

      reload();
    });
  }

  @override
  void dispose() {
    searchController.dispose();

    super.dispose();
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
              'Assignments',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            FilledButton.icon(
              onPressed: () async {
                final created = await showDialog<bool>(
                  context: context,
                  builder: (_) => const _CreateAssignmentDialog(),
                );

                if (created == true && mounted) {
                  setState(() {
                    page = 1;

                    reload();
                  });
                }
              },
              icon: const Icon(
                Icons.assignment_add,
              ),
              label: const Text(
                'Create Assignment',
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                context.push(
                  '/assignments/import-pdf',
                );
              },
              icon: const Icon(
                Icons.picture_as_pdf_outlined,
              ),
              label: const Text(
                'Import PDF',
              ),
            ),
            IconButton(
              onPressed: refresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Search assignments',
                  hintText: 'Title or description',
                ),
                onSubmitted: (_) => applySearch(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: applySearch,
              child: const Text('Search'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<AssignmentPage>(
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
                        'Could not load assignments:\n'
                        '${snapshot.error}',
                      ),
                      TextButton(
                        onPressed: refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final data = snapshot.data!;

              if (data.results.isEmpty) {
                return const Center(
                  child: Text(
                    'No assignments found.',
                  ),
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: data.results.length,
                      itemBuilder: (context, index) {
                        final assignment = data.results[index];

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(
                                assignment.isPublished
                                    ? Icons.assignment_turned_in_outlined
                                    : Icons.assignment_outlined,
                              ),
                            ),
                            title: Text(
                              assignment.title,
                            ),
                            subtitle: Text(
                              '${assignment.courseName}'
                              ' • '
                              '${assignment.maxMarks} Marks'
                              '\n'
                              'Due: ${_formatDateTime(assignment.dueAt)}',
                            ),
                            isThreeLine: true,
                            trailing: Chip(
                              label: Text(
                                assignment.isPublished ? 'Published' : 'Draft',
                              ),
                            ),
                            onTap: () async {
                              await context.push(
                                '/assignments/${assignment.uuid}',
                              );

                              if (mounted) {
                                refresh();
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${data.count} total • Page $page',
                      ),
                      IconButton(
                        onPressed:
                            page > 1 ? () => changePage(page - 1) : null,
                        icon: const Icon(
                          Icons.chevron_left,
                        ),
                      ),
                      IconButton(
                        onPressed: page * 20 < data.count
                            ? () => changePage(page + 1)
                            : null,
                        icon: const Icon(
                          Icons.chevron_right,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CreateAssignmentDialog extends ConsumerStatefulWidget {
  const _CreateAssignmentDialog();

  @override
  ConsumerState<_CreateAssignmentDialog> createState() =>
      _CreateAssignmentDialogState();
}

class _CreateAssignmentDialogState
    extends ConsumerState<_CreateAssignmentDialog> {
  final title = TextEditingController();
  final description = TextEditingController();
  final instructions = TextEditingController();
  final maxMarks = TextEditingController(text: '0');

  List<Course> courses = [];
  Course? selectedCourse;
  bool loadingCourses = false;

  List<Subject> subjects = [];
  Subject? selectedSubject;
  bool loadingSubjects = false;

  List<Chapter> chapters = [];
  Chapter? selectedChapter;
  bool loadingChapters = false;

  List<Lesson> lessons = [];
  Lesson? selectedLesson;
  bool loadingLessons = false;

  DateTime? dueAt;
  bool allowLateSubmission = false;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadCourses();
  }

  Future<void> loadCourses() async {
    setState(() {
      loadingCourses = true;
    });

    try {
      final result = await ref.read(courseRepositoryProvider).list();
      if (mounted) {
        setState(() {
          courses = result.results;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          loadingCourses = false;
        });
      }
    }
  }

  Future<void> loadSubjects(
    String courseUuid,
  ) async {
    setState(() {
      loadingSubjects = true;

      subjects = [];
      selectedSubject = null;

      chapters = [];
      selectedChapter = null;

      lessons = [];
      selectedLesson = null;
    });

    try {
      final result = await ref
          .read(subjectRepositoryProvider)
          .list(
            courseUuid: courseUuid,
          );

      if (!mounted) return;

      setState(() {
        subjects = result.results
            .where(
              (subject) =>
                  subject.isActive,
            )
            .toList();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error =
            'Could not load subjects: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          loadingSubjects = false;
        });
      }
    }
  }

  Future<void> loadChapters(
    String subjectUuid,
  ) async {
    setState(() {
      loadingChapters = true;

      chapters = [];
      selectedChapter = null;

      lessons = [];
      selectedLesson = null;
    });

    try {
      final result = await ref
          .read(chapterRepositoryProvider)
          .list(
            subjectUuid: subjectUuid,
          );

      if (!mounted) return;

      setState(() {
        chapters = result.results
            .where(
              (chapter) =>
                  chapter.isActive,
            )
            .toList();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error =
            'Could not load chapters: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          loadingChapters = false;
        });
      }
    }
  }

  Future<void> loadLessons(
    String chapterUuid,
  ) async {
    setState(() {
      loadingLessons = true;

      lessons = [];
      selectedLesson = null;
    });

    try {
      final result = await ref
          .read(lessonRepositoryProvider)
          .list(
            chapterUuid: chapterUuid,
          );

      if (!mounted) return;

      setState(() {
        lessons = result.results
            .where(
              (lesson) =>
                  lesson.isActive,
            )
            .toList();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error =
            'Could not load lessons: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          loadingLessons = false;
        });
      }
    }
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    instructions.dispose();
    maxMarks.dispose();

    super.dispose();
  }

  Future<DateTime?> pickDateTime() async {
    final initial = dueAt ?? DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
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
    if (selectedCourse == null) {
      setState(() {
        error = 'Please select a course.';
      });

      return;
    }

    if (title.text.trim().isEmpty) {
      setState(() {
        error = 'Assignment title is required.';
      });

      return;
    }

    final marks = double.tryParse(
          maxMarks.text,
        ) ??
        0;

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await ref.read(assignmentRepositoryProvider).create(
            courseUuid: selectedCourse!.uuid,
            subjectUuid: selectedSubject?.uuid,
            chapterUuid: selectedChapter?.uuid,
            lessonUuid: selectedLesson?.uuid,
            title: title.text,
            description: description.text,
            instructions: instructions.text,
            maxMarks: marks,
            dueAt: dueAt,
            allowLateSubmission: allowLateSubmission,
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
      title: const Text('Create Assignment'),
      content: SizedBox(
        width: 550,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(
                  labelText: 'Assignment Title *',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: description,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: instructions,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Instructions',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: maxMarks,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Maximum Marks',
                ),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                key: ValueKey('course_dd_${courses.length}'),
                value: courses.any((c) => c.uuid == selectedCourse?.uuid)
                    ? selectedCourse?.uuid
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Course *',
                ),
                items: courses
                    .map(
                      (course) => DropdownMenuItem<String>(
                        value: course.uuid,
                        child: Text(
                          '${course.name} (${course.code})',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: loadingCourses
                    ? null
                    : (value) async {
                        if (value == null) {
                          return;
                        }

                        final course = courses.firstWhere(
                          (item) => item.uuid == value,
                        );

                        setState(() {
                          selectedCourse = course;

                          selectedSubject = null;
                          subjects = [];

                          selectedChapter = null;
                          chapters = [];

                          selectedLesson = null;
                          lessons = [];

                          error = null;
                        });

                        await loadSubjects(
                          course.uuid,
                        );
                      },
              ),
              if (loadingCourses) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('subject_dd_${selectedCourse?.uuid}_${subjects.length}'),
                value: subjects.any((s) => s.uuid == selectedSubject?.uuid)
                    ? selectedSubject?.uuid
                    : null,
                decoration: InputDecoration(
                  labelText: 'Subject',
                  helperText: selectedCourse == null
                      ? 'Select course first'
                      : subjects.isEmpty && !loadingSubjects
                          ? 'No subjects available'
                          : null,
                ),
                items: subjects
                    .map(
                      (subject) => DropdownMenuItem<String>(
                        value: subject.uuid,
                        child: Text(
                          subject.code.isEmpty
                              ? subject.name
                              : '${subject.name} (${subject.code})',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: selectedCourse == null || loadingSubjects
                    ? null
                    : (value) async {
                        if (value == null) {
                          return;
                        }

                        final subject = subjects.firstWhere(
                          (item) => item.uuid == value,
                        );

                        setState(() {
                          selectedSubject = subject;

                          selectedChapter = null;
                          chapters = [];

                          selectedLesson = null;
                          lessons = [];

                          error = null;
                        });

                        await loadChapters(
                          subject.uuid,
                        );
                      },
              ),
              if (loadingSubjects) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('chapter_dd_${selectedSubject?.uuid}_${chapters.length}'),
                value: chapters.any((c) => c.uuid == selectedChapter?.uuid)
                    ? selectedChapter?.uuid
                    : null,
                decoration: InputDecoration(
                  labelText: 'Chapter',
                  helperText: selectedSubject == null
                      ? 'Select subject first'
                      : chapters.isEmpty && !loadingChapters
                          ? 'No chapters available'
                          : null,
                ),
                items: chapters
                    .map(
                      (chapter) => DropdownMenuItem<String>(
                        value: chapter.uuid,
                        child: Text(
                          chapter.title,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: selectedSubject == null || loadingChapters
                    ? null
                    : (value) async {
                        if (value == null) {
                          return;
                        }

                        final chapter = chapters.firstWhere(
                          (item) => item.uuid == value,
                        );

                        setState(() {
                          selectedChapter = chapter;

                          selectedLesson = null;
                          lessons = [];

                          error = null;
                        });

                        await loadLessons(
                          chapter.uuid,
                        );
                      },
              ),
              if (loadingChapters) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('lesson_dd_${selectedChapter?.uuid}_${lessons.length}'),
                value: lessons.any((l) => l.uuid == selectedLesson?.uuid)
                    ? selectedLesson?.uuid
                    : null,
                decoration: InputDecoration(
                  labelText: 'Lesson',
                  helperText: selectedChapter == null
                      ? 'Select chapter first'
                      : lessons.isEmpty && !loadingLessons
                          ? 'No lessons available'
                          : null,
                ),
                items: lessons
                    .map(
                      (lesson) => DropdownMenuItem<String>(
                        value: lesson.uuid,
                        child: Text(
                          lesson.title,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: selectedChapter == null || loadingLessons
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          selectedLesson = lessons.firstWhere(
                            (item) => item.uuid == value,
                          );

                          error = null;
                        });
                      },
              ),
              if (loadingLessons) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Due Date'),
                subtitle: Text(
                  _formatDateTime(
                    dueAt,
                  ),
                ),
                trailing: const Icon(
                  Icons.calendar_month,
                ),
                onTap: () async {
                  final value = await pickDateTime();

                  if (value != null && mounted) {
                    setState(() {
                      dueAt = value;
                    });
                  }
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Allow Late Submission',
                ),
                value: allowLateSubmission,
                onChanged: (value) {
                  setState(() {
                    allowLateSubmission = value;
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
            saving ? 'Creating...' : 'Create Assignment',
          ),
        ),
      ],
    );
  }
}

String _formatDateTime(
  DateTime? value,
) {
  if (value == null) {
    return 'Not set';
  }

  final local = value.toLocal();

  String twoDigits(int value) => value.toString().padLeft(
        2,
        '0',
      );

  return '${twoDigits(local.day)}/'
      '${twoDigits(local.month)}/'
      '${local.year} '
      '${twoDigits(local.hour)}:'
      '${twoDigits(local.minute)}';
}
