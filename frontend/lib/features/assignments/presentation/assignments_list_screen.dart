import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/admin_ui.dart';

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

  Future<void> _openCreate() async {
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
  }

  String _marks(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          eyebrow: const AdminEyebrow(
            section: 'Evaluation hub',
            detail: 'Assignments & submissions',
          ),
          title: 'Assignments',
          titleTrailing: [
            IconButton(
              onPressed: refresh,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
            ),
          ],
          actions: [
            AdminOutlineButton(
              label: 'Import PDF',
              icon: Icons.picture_as_pdf_outlined,
              onPressed: () => context.push('/assignments/import-pdf'),
            ),
            GradientButton(
              label: 'Create assignment',
              icon: Icons.assignment_add,
              onPressed: _openCreate,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: FutureBuilder<AssignmentPage>(
            future: result,
            builder: (context, snapshot) {
              final state = adminFutureState(
                snapshot,
                noun: 'assignments',
                onRetry: refresh,
              );
              final data = snapshot.data;
              final rows = data?.results ?? const <Assignment>[];
              final now = DateTime.now();
              final published = rows.where((a) => a.isPublished).length;
              final open = rows
                  .where((a) => a.dueAt == null || a.dueAt!.isAfter(now))
                  .length;
              final dueSoon = rows.where((a) {
                final due = a.dueAt;
                return due != null &&
                    due.isAfter(now) &&
                    due.difference(now).inDays <= 7;
              }).length;

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  AdminKpiGrid(
                    children: [
                      AdminKpiCard(
                        label: 'Total assignments',
                        value: data == null ? '…' : '${data.count}',
                        icon: Icons.assignment_outlined,
                      ),
                      AdminKpiCard(
                        label: 'Published',
                        value: data == null ? '…' : '$published',
                        icon: Icons.public_rounded,
                        iconBackground: const Color(0xFFECFDF5),
                        iconForeground: const Color(0xFF059669),
                        caption: data == null
                            ? null
                            : '${rows.length - published} drafts on this page',
                      ),
                      AdminKpiCard(
                        label: 'Open for submission',
                        value: data == null ? '…' : '$open',
                        icon: Icons.inbox_outlined,
                        iconBackground: const Color(0xFFF0F9FF),
                        iconForeground: const Color(0xFF0284C7),
                        caption: 'On this page',
                      ),
                      AdminKpiCard(
                        label: 'Due in 7 days',
                        value: data == null ? '…' : '$dueSoon',
                        icon: Icons.alarm_rounded,
                        iconBackground: const Color(0xFFFFFBEB),
                        iconForeground: const Color(0xFFD97706),
                        caption: 'On this page',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AdminToolbar(
                    controller: searchController,
                    hint: 'Search by title or description…',
                    onSearch: applySearch,
                  ),
                  const SizedBox(height: 18),
                  if (state != null)
                    state
                  else if (rows.isEmpty)
                    AdminStateMessage(
                      icon: Icons.assignment_add,
                      title: 'No assignments found',
                      message: search.isEmpty
                          ? 'Create an assignment or import one from a PDF.'
                          : 'Try a different search.',
                      actionLabel: search.isEmpty ? 'Create assignment' : null,
                      onAction: search.isEmpty ? _openCreate : null,
                    )
                  else ...[
                    for (final assignment in rows)
                      AdminListRow(
                        title: assignment.title,
                        icon: assignment.isPublished
                            ? Icons.assignment_turned_in_outlined
                            : Icons.assignment_outlined,
                        subtitle: assignment.description,
                        meta: [
                          MetaChip(
                            icon: Icons.auto_stories_outlined,
                            label: assignment.courseName,
                          ),
                          MetaChip(
                            icon: Icons.star_outline_rounded,
                            label: '${_marks(assignment.maxMarks)} marks',
                          ),
                          MetaChip(
                            icon: Icons.event_outlined,
                            label: 'Due ${_formatDateTime(assignment.dueAt)}',
                          ),
                          if (assignment.allowLateSubmission)
                            const SoftBadge(
                              label: 'Late allowed',
                              background: Color(0xFFFFFBEB),
                              foreground: Color(0xFFD97706),
                            ),
                        ],
                        trailing: [
                          ActiveBadge(
                            active: assignment.isPublished,
                            activeLabel: 'Published',
                            inactiveLabel: 'Draft',
                          ),
                        ],
                        onTap: () async {
                          await context.push(
                            '/assignments/${assignment.uuid}',
                          );
                          if (mounted) refresh();
                        },
                      ),
                    AdminPager(
                      page: page,
                      pageSize: 20,
                      total: data!.count,
                      noun: 'assignments',
                      onPage: changePage,
                    ),
                  ],
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
