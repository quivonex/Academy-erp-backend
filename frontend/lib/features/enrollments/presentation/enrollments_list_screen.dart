import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/status_pill.dart';

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

  Future<void> _openBulk() async {
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
  }

  String _date(DateTime? value) {
    if (value == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final d = value.toLocal();
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          eyebrow: const AdminEyebrow(
            section: 'Admissions',
            detail: 'Course enrollments & access',
          ),
          title: 'Enrollments',
          titleTrailing: [
            IconButton(
              onPressed: refresh,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
            ),
          ],
          actions: [
            AdminOutlineButton(
              label: 'Bulk assign',
              icon: Icons.group_add_outlined,
              onPressed: _openBulk,
            ),
            GradientButton(
              label: 'Enroll student',
              icon: Icons.person_add_alt_1_rounded,
              onPressed: addEnrollment,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: FutureBuilder<EnrollmentPage>(
            future: result,
            builder: (context, snapshot) {
              final state = adminFutureState(
                snapshot,
                noun: 'enrollments',
                onRetry: refresh,
              );
              final data = snapshot.data;
              final rows = data?.results ?? const <Enrollment>[];
              final active =
                  rows.where((e) => e.status.toUpperCase() == 'ACTIVE').length;
              final now = DateTime.now();
              final endingSoon = rows.where((e) {
                final end = e.accessEndAt;
                return end != null &&
                    end.isAfter(now) &&
                    end.difference(now).inDays <= 30;
              }).length;
              final courses = rows.map((e) => e.courseCode).toSet().length;

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  AdminKpiGrid(
                    children: [
                      AdminKpiCard(
                        label: 'Total enrollments',
                        value: data == null ? '…' : '${data.count}',
                        icon: Icons.how_to_reg_outlined,
                      ),
                      AdminKpiCard(
                        label: 'Active on this page',
                        value: data == null ? '…' : '$active',
                        icon: Icons.verified_outlined,
                        iconBackground: const Color(0xFFECFDF5),
                        iconForeground: const Color(0xFF059669),
                      ),
                      AdminKpiCard(
                        label: 'Access ending ≤ 30 days',
                        value: data == null ? '…' : '$endingSoon',
                        icon: Icons.hourglass_bottom_rounded,
                        iconBackground: const Color(0xFFFFFBEB),
                        iconForeground: const Color(0xFFD97706),
                        caption: 'On this page',
                      ),
                      AdminKpiCard(
                        label: 'Courses on this page',
                        value: data == null ? '…' : '$courses',
                        icon: Icons.auto_stories_outlined,
                        iconBackground: const Color(0xFFF5F3FF),
                        iconForeground: const Color(0xFF7C3AED),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (state != null)
                    state
                  else if (rows.isEmpty)
                    AdminStateMessage(
                      icon: Icons.how_to_reg_outlined,
                      title: 'No enrollments yet',
                      message: 'Enroll a student into a course to get started.',
                      actionLabel: 'Enroll student',
                      onAction: addEnrollment,
                    )
                  else ...[
                    for (final enrollment in rows)
                      AdminListRow(
                        title: enrollment.studentName,
                        initials: adminInitials(enrollment.studentName),
                        seed: enrollment.admissionNumber,
                        titleBadge: enrollment.admissionNumber.isEmpty
                            ? null
                            : SoftBadge(
                                label: enrollment.admissionNumber,
                                monospace: true,
                                background: const Color(0xFFF1F5F9),
                                foreground: const Color(0xFF334155),
                              ),
                        subtitle:
                            '${enrollment.courseName} (${enrollment.courseCode})',
                        meta: [
                          if (enrollment.enrolledAt != null)
                            MetaChip(
                              icon: Icons.event_available_outlined,
                              label:
                                  'Enrolled ${_date(enrollment.enrolledAt)}',
                            ),
                          if (enrollment.accessEndAt != null)
                            MetaChip(
                              icon: Icons.lock_clock_outlined,
                              label:
                                  'Access until ${_date(enrollment.accessEndAt)}',
                            ),
                        ],
                        trailing: [
                          StatusPill(
                            label: enrollment.status.toUpperCase(),
                            tone: toneForStatus(enrollment.status),
                            compact: true,
                          ),
                        ],
                        onTap: () async {
                          await context.push(
                            '/enrollments/${enrollment.uuid}',
                          );
                          if (mounted) refresh();
                        },
                      ),
                    AdminPager(
                      page: page,
                      pageSize: 20,
                      total: data!.count,
                      noun: 'enrollments',
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
