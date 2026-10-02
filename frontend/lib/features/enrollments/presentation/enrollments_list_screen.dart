import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../courses/data/course.dart';
import '../../courses/data/course_repository.dart';

import '../../students/data/student.dart';
import '../../students/data/student_repository.dart';

import '../data/enrollment.dart';
import '../data/enrollment_repository.dart';

class EnrollmentsListScreen extends ConsumerStatefulWidget {
  const EnrollmentsListScreen({
    super.key,
  });

  @override
  ConsumerState<EnrollmentsListScreen> createState() =>
      _EnrollmentsListScreenState();
}

class _EnrollmentsListScreenState
    extends ConsumerState<EnrollmentsListScreen> {
  late Future<EnrollmentPage> result;

  int page = 1;

  @override
  void initState() {
    super.initState();

    reload();
  }

  void reload() {
    result = ref
        .read(
          enrollmentManagementRepositoryProvider,
        )
        .list(
          page: page,
        );
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

  Future<void> addEnrollment() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _CreateEnrollmentDialog(),
    );

    if (created == true && mounted) {
      setState(() {
        page = 1;

        reload();
      });
    }
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
              'Enrollments',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            FilledButton.icon(
              onPressed: addEnrollment,
              icon: const Icon(
                Icons.person_add_alt,
              ),
              label: const Text(
                'Enroll Student',
              ),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final done = await showDialog<bool>(
                  context: context,
                  builder: (_) => const _BulkEnrollmentDialog(),
                );

                if (done == true && mounted) {
                  setState(() {
                    page = 1;
                    reload();
                  });
                }
              },
              icon: const Icon(
                Icons.group_add_outlined,
              ),
              label: const Text(
                'Bulk Assign',
              ),
            ),
            IconButton(
              onPressed: refresh,
              icon: const Icon(
                Icons.refresh,
              ),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<EnrollmentPage>(
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
                        'Could not load enrollments:\n'
                        '${snapshot.error}',
                      ),
                      TextButton(
                        onPressed: refresh,
                        child: const Text(
                          'Retry',
                        ),
                      ),
                    ],
                  ),
                );
              }

              final data = snapshot.data!;

              if (data.results.isEmpty) {
                return const Center(
                  child: Text(
                    'No enrollments found.',
                  ),
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: data.results.length,
                      itemBuilder: (context, index) {
                        final enrollment = data.results[index];

                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(
                                Icons.school,
                              ),
                            ),
                            title: Text(
                              enrollment.studentName,
                            ),
                            subtitle: Text(
                              '${enrollment.admissionNumber}'
                              ' • '
                              '${enrollment.courseName}'
                              ' (${enrollment.courseCode})',
                            ),
                            trailing: Chip(
                              label: Text(
                                enrollment.status,
                              ),
                            ),
                            onTap: () async {
                              await context.push(
                                '/enrollments/${enrollment.uuid}',
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
                        onPressed: page > 1
                            ? () => changePage(
                                  page - 1,
                                )
                            : null,
                        icon: const Icon(
                          Icons.chevron_left,
                        ),
                      ),
                      IconButton(
                        onPressed: page * 20 < data.count
                            ? () => changePage(
                                  page + 1,
                                )
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

class _CreateEnrollmentDialog extends ConsumerStatefulWidget {
  const _CreateEnrollmentDialog();

  @override
  ConsumerState<_CreateEnrollmentDialog> createState() =>
      _CreateEnrollmentDialogState();
}

class _CreateEnrollmentDialogState
    extends ConsumerState<_CreateEnrollmentDialog> {
  Student? selectedStudent;
  Course? selectedCourse;
  String status = 'ACTIVE';

  List<Student> students = [];
  List<Course> courses = [];

  bool loadingStudents = false;
  bool loadingCourses = false;
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
      loadingStudents = true;
      loadingCourses = true;
    });

    try {
      final sResult = await ref.read(studentRepositoryProvider).list();
      final cResult = await ref.read(courseRepositoryProvider).list();

      if (mounted) {
        setState(() {
          students = sResult.results;
          courses = cResult.results;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          loadingStudents = false;
          loadingCourses = false;
        });
      }
    }
  }

  Future<void> save() async {
    if (selectedStudent == null) {
      setState(() {
        error = 'Please select a student.';
      });
      return;
    }

    if (selectedCourse == null) {
      setState(() {
        error = 'Please select a course.';
      });
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await ref.read(enrollmentManagementRepositoryProvider).create(
            studentUuid: selectedStudent!.uuid,
            courseUuid: selectedCourse!.uuid,
            status: status,
          );

      if (mounted) {
        Navigator.pop(context, true);
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
      title: const Text('Enroll Student'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey('student_dd_${students.length}'),
                value: students.any((s) => s.uuid == selectedStudent?.uuid)
                    ? selectedStudent?.uuid
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Student',
                ),
                items: students
                    .map(
                      (student) => DropdownMenuItem<String>(
                        value: student.uuid,
                        child: Text('${student.fullName} (${student.admissionNumber})'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selectedStudent = students.firstWhere((s) => s.uuid == value);
                    error = null;
                  });
                },
              ),
              if (loadingStudents) const LinearProgressIndicator(),
              const SizedBox(height: 18),
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
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selectedCourse = courses.firstWhere((c) => c.uuid == value);
                    error = null;
                  });
                },
              ),
              if (loadingCourses) const LinearProgressIndicator(),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(
                  labelText: 'Enrollment Status',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'ACTIVE',
                    child: Text('Active'),
                  ),
                  DropdownMenuItem(
                    value: 'PENDING',
                    child: Text('Pending'),
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
                    status = value ?? 'ACTIVE';
                  });
                },
              ),
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
            saving ? 'Enrolling...' : 'Enroll Student',
          ),
        ),
      ],
    );
  }
}

class _BulkEnrollmentDialog extends ConsumerStatefulWidget {
  const _BulkEnrollmentDialog();

  @override
  ConsumerState<_BulkEnrollmentDialog> createState() =>
      _BulkEnrollmentDialogState();
}

class _BulkEnrollmentDialogState
    extends ConsumerState<_BulkEnrollmentDialog> {
  List<Course> courses = [];

  Course? selectedCourse;

  DateTime? joinedDateFrom;
  DateTime? joinedDateTo;

  bool grantAccess = true;

  DateTime? accessStartAt;
  DateTime? accessEndAt;

  bool loadingCourses = false;
  bool saving = false;

  String? error;

  Map<String, dynamic>? result;

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
      final response = await ref.read(courseRepositoryProvider).list();

      if (!mounted) return;

      setState(() {
        courses = response.results;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = 'Could not load courses: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          loadingCourses = false;
        });
      }
    }
  }

  Future<DateTime?> pickDate(
    DateTime? current,
  ) async {
    return showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
  }

  Future<DateTime?> pickDateTime(
    DateTime? current,
  ) async {
    final initial = current ?? DateTime.now();

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

  Future<void> submit() async {
    if (selectedCourse == null) {
      setState(() {
        error = 'Please select a course.';
      });

      return;
    }

    if (joinedDateFrom == null) {
      setState(() {
        error = 'Joined Date From is required.';
      });

      return;
    }

    if (joinedDateTo != null && joinedDateTo!.isBefore(joinedDateFrom!)) {
      setState(() {
        error = 'Joined Date To must be on or after Joined Date From.';
      });

      return;
    }

    if (accessStartAt != null &&
        accessEndAt != null &&
        !accessEndAt!.isAfter(accessStartAt!)) {
      setState(() {
        error = 'Access end time must be after access start time.';
      });

      return;
    }

    setState(() {
      saving = true;
      error = null;
      result = null;
    });

    try {
      final response = await ref
          .read(
            enrollmentManagementRepositoryProvider,
          )
          .bulkAssignByAdmissionDate(
            courseUuid: selectedCourse!.uuid,
            joinedDateFrom: joinedDateFrom!,
            joinedDateTo: joinedDateTo,
            grantAccess: grantAccess,
            accessStartAt: accessStartAt,
            accessEndAt: accessEndAt,
          );

      if (!mounted) return;

      setState(() {
        result = response;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  String formatDate(
    DateTime? value,
  ) {
    if (value == null) {
      return 'Not selected';
    }

    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  String formatDateTime(
    DateTime? value,
  ) {
    if (value == null) {
      return 'Not selected';
    }

    return '${formatDate(value)} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return AlertDialog(
      title: const Text('Bulk Assign Course'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey('bulk_course_dd_${courses.length}'),
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
                    : (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          selectedCourse = courses.firstWhere(
                            (c) => c.uuid == value,
                          );

                          error = null;
                        });
                      },
              ),
              if (loadingCourses) const LinearProgressIndicator(),
              const SizedBox(
                height: 16,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Joined Date From *',
                ),
                subtitle: Text(
                  formatDate(
                    joinedDateFrom,
                  ),
                ),
                trailing: const Icon(
                  Icons.calendar_month_outlined,
                ),
                onTap: () async {
                  final value = await pickDate(
                    joinedDateFrom,
                  );

                  if (value != null && mounted) {
                    setState(() {
                      joinedDateFrom = value;
                    });
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Joined Date To',
                ),
                subtitle: Text(
                  formatDate(
                    joinedDateTo,
                  ),
                ),
                trailing: const Icon(
                  Icons.calendar_month_outlined,
                ),
                onTap: () async {
                  final value = await pickDate(
                    joinedDateTo,
                  );

                  if (value != null && mounted) {
                    setState(() {
                      joinedDateTo = value;
                    });
                  }
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Grant Access',
                ),
                subtitle: const Text(
                  'Create active course access for matched students',
                ),
                value: grantAccess,
                onChanged: (value) {
                  setState(() {
                    grantAccess = value;
                  });
                },
              ),
              if (grantAccess) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Access Start',
                  ),
                  subtitle: Text(
                    formatDateTime(
                      accessStartAt,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.schedule,
                  ),
                  onTap: () async {
                    final value = await pickDateTime(
                      accessStartAt,
                    );

                    if (value != null && mounted) {
                      setState(() {
                        accessStartAt = value;
                      });
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Access End',
                  ),
                  subtitle: Text(
                    formatDateTime(
                      accessEndAt,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.event_available,
                  ),
                  onTap: () async {
                    final value = await pickDateTime(
                      accessEndAt,
                    );

                    if (value != null && mounted) {
                      setState(() {
                        accessEndAt = value;
                      });
                    }
                  },
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(
                    top: 12,
                  ),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.error,
                    ),
                  ),
                ),
              if (result != null) ...[
                const SizedBox(
                  height: 18,
                ),
                const Divider(),
                const SizedBox(
                  height: 8,
                ),
                Text(
                  'Bulk Enrollment Result',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium,
                ),
                const SizedBox(
                  height: 12,
                ),
                Text(
                  'Course: ${result!['course_name'] ?? '-'}',
                ),
                Text(
                  'Matched Students: ${result!['matched_students_count'] ?? 0}',
                ),
                Text(
                  'Created Enrollments: ${result!['created_enrollments_count'] ?? 0}',
                ),
                Text(
                  'Skipped Students: ${result!['skipped_students_count'] ?? 0}',
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving
              ? null
              : () {
                  Navigator.pop(
                    context,
                    result != null,
                  );
                },
          child: Text(
            result == null ? 'Cancel' : 'Close',
          ),
        ),
        if (result == null)
          FilledButton.icon(
            onPressed: saving ? null : submit,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.group_add,
                  ),
            label: Text(
              saving ? 'Assigning...' : 'Assign Course',
            ),
          ),
      ],
    );
  }
}
