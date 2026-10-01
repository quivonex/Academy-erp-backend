import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../courses/data/course.dart';
import '../../courses/data/course_repository.dart';

import '../../teachers/data/teacher.dart';
import '../../teachers/data/teacher_repository.dart';

import '../../subjects/data/subject.dart';
import '../../subjects/data/subject_repository.dart';

import '../../subjects/data/chapter.dart';
import '../../subjects/data/chapter_repository.dart';

import '../../subjects/data/lesson.dart';
import '../../subjects/data/lesson_repository.dart';

import '../data/live_class.dart';
import '../data/live_class_repository.dart';

class LiveClassesListScreen extends ConsumerStatefulWidget {
  const LiveClassesListScreen({
    super.key,
  });

  @override
  ConsumerState<LiveClassesListScreen> createState() =>
      _LiveClassesListScreenState();
}

class _LiveClassesListScreenState extends ConsumerState<LiveClassesListScreen> {
  final searchController = TextEditingController();

  late Future<LiveClassPage> result;

  String search = '';

  String? statusFilter;

  int page = 1;

  @override
  void initState() {
    super.initState();

    reload();
  }

  void reload() {
    result = ref.read(liveClassRepositoryProvider).list(
          page: page,
          search: search,
          status: statusFilter,
        );
  }

  void applySearch() {
    setState(() {
      search = searchController.text.trim();

      page = 1;

      reload();
    });
  }

  void refresh() {
    setState(reload);
  }

  void changePage(int value) {
    setState(() {
      page = value;

      reload();
    });
  }

  Future<void> createLiveClass() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _ScheduleLiveClassDialog(),
    );

    if (created == true && mounted) {
      setState(() {
        page = 1;

        reload();
      });
    }
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
              'Live Classes',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            FilledButton.icon(
              onPressed: createLiveClass,
              icon: const Icon(
                Icons.video_call_outlined,
              ),
              label: const Text(
                'Schedule Class',
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: refresh,
              icon: const Icon(
                Icons.refresh,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 350,
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Search live classes',
                  hintText: 'Title or course name',
                ),
                onSubmitted: (_) => applySearch(),
              ),
            ),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<String>(
                value: statusFilter ?? 'ALL',
                decoration: const InputDecoration(
                  labelText: 'Status',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'ALL',
                    child: Text('All'),
                  ),
                  DropdownMenuItem(
                    value: 'SCHEDULED',
                    child: Text('Scheduled'),
                  ),
                  DropdownMenuItem(
                    value: 'LIVE',
                    child: Text('Live'),
                  ),
                  DropdownMenuItem(
                    value: 'COMPLETED',
                    child: Text('Completed'),
                  ),
                  DropdownMenuItem(
                    value: 'CANCELLED',
                    child: Text('Cancelled'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    statusFilter = value == 'ALL' ? null : value;

                    page = 1;

                    reload();
                  });
                },
              ),
            ),
            FilledButton(
              onPressed: applySearch,
              child: const Text('Search'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<LiveClassPage>(
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
                        'Could not load live classes:\n'
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
                    'No live classes found.',
                  ),
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: data.results.length,
                      itemBuilder: (context, index) {
                        final liveClass = data.results[index];

                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(
                                Icons.videocam_outlined,
                              ),
                            ),
                            title: Text(
                              liveClass.title,
                            ),
                            subtitle: Text(
                              '${liveClass.courseName}'
                              ' • '
                              '${liveClass.teacherName}'
                              '\n'
                              '${_formatDateTime(liveClass.scheduledStartAt)}',
                            ),
                            isThreeLine: true,
                            trailing: _LiveStatusChip(
                              status: liveClass.status,
                            ),
                            onTap: () async {
                              await context.push(
                                '/live-classes/${liveClass.uuid}',
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

class _ScheduleLiveClassDialog extends ConsumerStatefulWidget {
  const _ScheduleLiveClassDialog();

  @override
  ConsumerState<_ScheduleLiveClassDialog> createState() =>
      _ScheduleLiveClassDialogState();
}

class _ScheduleLiveClassDialogState
    extends ConsumerState<_ScheduleLiveClassDialog> {
  final formKey = GlobalKey<FormState>();

  final title = TextEditingController();
  final description = TextEditingController();
  final meetingUrl = TextEditingController();
  final meetingId = TextEditingController();
  final meetingPassword = TextEditingController();

  Course? selectedCourse;
  Teacher? selectedTeacher;

  Subject? selectedSubject;
  Chapter? selectedChapter;
  Lesson? selectedLesson;

  List<Course> courses = [];
  List<Teacher> teachers = [];

  List<Subject> subjects = [];
  List<Chapter> chapters = [];
  List<Lesson> lessons = [];

  bool loadingCourses = false;
  bool loadingTeachers = false;
  bool loadingSubjects = false;
  bool loadingChapters = false;
  bool loadingLessons = false;

  DateTime? startAt;
  DateTime? endAt;

  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    if (!mounted) return;
    setState(() {
      loadingCourses = true;
      loadingTeachers = true;
      loadingSubjects = true;
    });

    try {
      final cResult = await ref.read(courseRepositoryProvider).list();
      final tResult = await ref.read(teacherRepositoryProvider).list(isActive: true);
      final sResult = await ref.read(subjectRepositoryProvider).list();

      if (mounted) {
        setState(() {
          courses = cResult.results;
          teachers = tResult.results;
          subjects = sResult.results;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          loadingCourses = false;
          loadingTeachers = false;
          loadingSubjects = false;
        });
      }
    }
  }

  Future<void> loadSubjects(String courseUuid) async {
    if (!mounted) return;
    setState(() {
      loadingSubjects = true;
      selectedSubject = null;
      selectedChapter = null;
      selectedLesson = null;
      chapters = [];
      lessons = [];
    });

    try {
      final result = await ref.read(subjectRepositoryProvider).list(
            courseUuid: courseUuid,
          );

      if (mounted) {
        setState(() {
          if (result.results.isNotEmpty) {
            subjects = result.results;
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          loadingSubjects = false;
        });
      }
    }
  }

  Future<void> loadChapters(String subjectUuid) async {
    if (!mounted) return;
    setState(() {
      loadingChapters = true;
      selectedChapter = null;
      selectedLesson = null;
      chapters = [];
      lessons = [];
    });

    try {
      final result = await ref.read(chapterRepositoryProvider).list(
            subjectUuid: subjectUuid,
          );

      if (mounted) {
        setState(() {
          chapters = result.results;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          loadingChapters = false;
        });
      }
    }
  }

  Future<void> loadLessons(String chapterUuid) async {
    if (!mounted) return;
    setState(() {
      loadingLessons = true;
      selectedLesson = null;
      lessons = [];
    });

    try {
      final result = await ref.read(lessonRepositoryProvider).list(
            chapterUuid: chapterUuid,
          );

      if (mounted) {
        setState(() {
          lessons = result.results;
        });
      }
    } catch (_) {
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
    meetingUrl.dispose();
    meetingId.dispose();
    meetingPassword.dispose();

    super.dispose();
  }

  Future<DateTime?> selectDateTime(
    DateTime? current,
  ) async {
    final initial = current ?? DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(
        const Duration(days: 1),
      ),
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
    if (!formKey.currentState!.validate()) {
      return;
    }

    if (selectedCourse == null) {
      setState(() {
        error = 'Please select a course.';
      });

      return;
    }

    if (selectedTeacher == null) {
      setState(() {
        error = 'Please select a teacher.';
      });

      return;
    }

    if (startAt == null) {
      setState(() {
        error = 'Please select class start time.';
      });

      return;
    }

    if (endAt == null) {
      setState(() {
        error = 'Please select class end time.';
      });

      return;
    }

    if (!endAt!.isAfter(startAt!)) {
      setState(() {
        error = 'End time must be after start time.';
      });

      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await ref
          .read(
            liveClassRepositoryProvider,
          )
          .create(
            courseUuid: selectedCourse!.uuid,
            teacherUuid: selectedTeacher!.uuid,
            subjectUuid: selectedSubject?.uuid,
            chapterUuid: selectedChapter?.uuid,
            lessonUuid: selectedLesson?.uuid,
            title: title.text,
            description: description.text,
            scheduledStartAt: startAt!,
            scheduledEndAt: endAt!,
            meetingUrl: meetingUrl.text,
            meetingId: meetingId.text,
            meetingPassword: meetingPassword.text,
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
      title: const Text('Schedule Live Class'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'Class Title',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: description,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey('course_dd_${courses.length}'),
                  value: courses.any((c) => c.uuid == selectedCourse?.uuid)
                      ? selectedCourse?.uuid
                      : null,
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
                  onChanged: (value) async {
                    if (value == null) return;
                    final course = courses.firstWhere((c) => c.uuid == value);
                    setState(() {
                      selectedCourse = course;
                      error = null;
                    });

                    await loadSubjects(course.uuid);
                  },
                ),
                if (loadingCourses) const LinearProgressIndicator(),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey('subject_dd_${selectedCourse?.uuid}_${subjects.length}'),
                  value: subjects.any((s) => s.uuid == selectedSubject?.uuid)
                      ? selectedSubject?.uuid
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Subject (Optional)',
                  ),
                  items: subjects
                      .map(
                        (subject) => DropdownMenuItem<String>(
                          value: subject.uuid,
                          child: Text(
                            subject.courseName.isNotEmpty
                                ? '${subject.name} (${subject.courseName})'
                                : subject.name,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    if (value == null) return;

                    final subject = subjects.firstWhere(
                      (item) => item.uuid == value,
                    );

                    setState(() {
                      selectedSubject = subject;
                    });

                    await loadChapters(
                      subject.uuid,
                    );
                  },
                ),
                if (loadingSubjects) const LinearProgressIndicator(),
                if (selectedSubject != null) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey('chapter_dd_${selectedSubject?.uuid}_${chapters.length}'),
                    value: chapters.any((c) => c.uuid == selectedChapter?.uuid)
                        ? selectedChapter?.uuid
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Chapter (Optional)',
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
                    onChanged: (value) async {
                      if (value == null) return;

                      final chapter = chapters.firstWhere(
                        (item) => item.uuid == value,
                      );

                      setState(() {
                        selectedChapter = chapter;
                      });

                      await loadLessons(
                        chapter.uuid,
                      );
                    },
                  ),
                  if (loadingChapters) const LinearProgressIndicator(),
                ],
                if (selectedChapter != null) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey('lesson_dd_${selectedChapter?.uuid}_${lessons.length}'),
                    value: lessons.any((l) => l.uuid == selectedLesson?.uuid)
                        ? selectedLesson?.uuid
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Lesson (Optional)',
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
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        selectedLesson = lessons.firstWhere(
                          (item) => item.uuid == value,
                        );
                      });
                    },
                  ),
                  if (loadingLessons) const LinearProgressIndicator(),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey('teacher_dd_${teachers.length}'),
                  value: teachers.any((t) => t.uuid == selectedTeacher?.uuid)
                      ? selectedTeacher?.uuid
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Teacher',
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
                    if (value == null) return;

                    setState(() {
                      selectedTeacher = teachers.firstWhere(
                        (t) => t.uuid == value,
                      );
                    });
                  },
                ),
                if (loadingTeachers) const LinearProgressIndicator(),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Scheduled Start',
                  ),
                  subtitle: Text(
                    _formatDateTime(
                      startAt,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.calendar_month,
                  ),
                  onTap: () async {
                    final value = await selectDateTime(
                      startAt,
                    );

                    if (value != null && mounted) {
                      setState(() {
                        startAt = value;
                      });
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Scheduled End',
                  ),
                  subtitle: Text(
                    _formatDateTime(
                      endAt,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.calendar_month,
                  ),
                  onTap: () async {
                    final value = await selectDateTime(
                      endAt,
                    );

                    if (value != null && mounted) {
                      setState(() {
                        endAt = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: meetingUrl,
                  decoration: const InputDecoration(
                    labelText: 'Meeting URL',
                    hintText: 'https://...',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: meetingId,
                  decoration: const InputDecoration(
                    labelText: 'Meeting ID',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: meetingPassword,
                  decoration: const InputDecoration(
                    labelText: 'Meeting Password',
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
            saving ? 'Scheduling...' : 'Schedule Class',
          ),
        ),
      ],
    );
  }
}

class _LiveStatusChip extends StatelessWidget {
  const _LiveStatusChip({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        status.toUpperCase(),
      ),
    );
  }
}

String _formatDateTime(
  DateTime? value,
) {
  if (value == null) {
    return 'Not selected';
  }

  final local = value.toLocal();

  String twoDigits(int number) => number.toString().padLeft(
        2,
        '0',
      );

  return '${twoDigits(local.day)}/'
      '${twoDigits(local.month)}/'
      '${local.year} '
      '${twoDigits(local.hour)}:'
      '${twoDigits(local.minute)}';
}
