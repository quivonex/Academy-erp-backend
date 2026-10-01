import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../data/enrollment.dart';
import '../data/enrollment_repository.dart';

class EnrollmentDetailScreen extends ConsumerStatefulWidget {
  const EnrollmentDetailScreen({
    super.key,
    required this.enrollmentUuid,
  });

  final String enrollmentUuid;

  @override
  ConsumerState<EnrollmentDetailScreen> createState() =>
      _EnrollmentDetailScreenState();
}

class _EnrollmentDetailScreenState
    extends ConsumerState<EnrollmentDetailScreen> {
  late Future<Enrollment> result;

  bool saving = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    result = ref
        .read(enrollmentManagementRepositoryProvider)
        .detail(widget.enrollmentUuid);
  }

  Future<void> editEnrollment(
    Enrollment enrollment,
  ) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _EditEnrollmentDialog(
        enrollment: enrollment,
      ),
    );

    if (updated == true && mounted) {
      setState(reload);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Enrollment>(
      future: result,
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.connectionState !=
            ConnectionState.done) {
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
                  'Could not load enrollment:\n${snapshot.error}',
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(reload);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final enrollment = snapshot.data!;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(
                  Icons.arrow_back,
                ),
                label:
                    const Text('Enrollments'),
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    child: Icon(
                      Icons.how_to_reg,
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          enrollment.studentName,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          enrollment
                              .admissionNumber,
                        ),
                      ],
                    ),
                  ),

                  _StatusChip(
                    status:
                        enrollment.status,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enrollment Information',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge,
                      ),

                      const SizedBox(height: 18),

                      _InfoRow(
                        label:
                            'Student Name',
                        value: enrollment
                            .studentName,
                      ),

                      _InfoRow(
                        label:
                            'Admission Number',
                        value: enrollment
                            .admissionNumber,
                      ),

                      _InfoRow(
                        label:
                            'Course Name',
                        value:
                            enrollment.courseName,
                      ),

                      _InfoRow(
                        label:
                            'Course Code',
                        value:
                            enrollment.courseCode,
                      ),

                      _InfoRow(
                        label: 'Status',
                        value:
                            enrollment.status,
                      ),

                      _InfoRow(
                        label:
                            'Enrolled At',
                        value: _formatDateTime(
                          enrollment.enrolledAt,
                        ),
                      ),

                      _InfoRow(
                        label:
                            'Access Start',
                        value: _formatDateTime(
                          enrollment.accessStartAt,
                        ),
                      ),

                      _InfoRow(
                        label:
                            'Access End',
                        value: _formatDateTime(
                          enrollment.accessEndAt,
                        ),
                      ),

                      _InfoRow(
                        label: 'Created',
                        value: _formatDateTime(
                          enrollment.createdAt,
                        ),
                      ),

                      _InfoRow(
                        label:
                            'Last Updated',
                        value: _formatDateTime(
                          enrollment.updatedAt,
                        ),
                      ),

                      _InfoRow(
                        label:
                            'Enrollment UUID',
                        value:
                            enrollment.uuid,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              FilledButton.icon(
                onPressed: () =>
                    editEnrollment(
                  enrollment,
                ),
                icon:
                    const Icon(Icons.edit),
                label: const Text(
                  'Manage Enrollment',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EditEnrollmentDialog
    extends ConsumerStatefulWidget {
  const _EditEnrollmentDialog({
    required this.enrollment,
  });

  final Enrollment enrollment;

  @override
  ConsumerState<_EditEnrollmentDialog>
      createState() =>
          _EditEnrollmentDialogState();
}

class _EditEnrollmentDialogState
    extends ConsumerState<
        _EditEnrollmentDialog> {
  late String status;

  DateTime? accessStart;
  DateTime? accessEnd;

  bool saving = false;

  String? error;

  @override
  void initState() {
    super.initState();

    status = widget.enrollment.status;

    accessStart =
        widget.enrollment.accessStartAt;

    accessEnd =
        widget.enrollment.accessEndAt;
  }

  Future<void> chooseStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          accessStart ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        accessStart ?? DateTime.now(),
      ),
    );

    if (time == null) {
      return;
    }

    setState(() {
      accessStart = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> chooseEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          accessEnd ??
          accessStart ??
          DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        accessEnd ??
            accessStart ??
            DateTime.now(),
      ),
    );

    if (time == null) {
      return;
    }

    setState(() {
      accessEnd = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> save() async {
    if (accessStart != null &&
        accessEnd != null &&
        !accessEnd!.isAfter(accessStart!)) {
      setState(() {
        error =
            'Access end time must be after access start time.';
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
            enrollmentManagementRepositoryProvider,
          )
          .update(
            uuid:
                widget.enrollment.uuid,
            status: status,
            accessStartAt:
                accessStart,
            accessEndAt:
                accessEnd,
          );

      if (mounted) {
        Navigator.pop(
          context,
          true,
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
        });
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
      title:
          const Text('Manage Enrollment'),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                widget.enrollment.studentName,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium,
              ),

              Text(
                '${widget.enrollment.courseName} '
                '(${widget.enrollment.courseCode})',
              ),

              const SizedBox(height: 20),

              DropdownButtonFormField<
                  String>(
                value: status,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Enrollment Status',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'PENDING',
                    child: Text(
                      'Pending',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'ACTIVE',
                    child: Text(
                      'Active',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'COMPLETED',
                    child: Text(
                      'Completed',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'CANCELLED',
                    child: Text(
                      'Cancelled',
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    status = value;
                  });
                },
              ),

              const SizedBox(height: 18),

              _DateField(
                label:
                    'Access Start',
                value:
                    _formatDateTime(
                  accessStart,
                ),
                onTap:
                    chooseStartDate,
                onClear:
                    accessStart == null
                        ? null
                        : () {
                            setState(() {
                              accessStart =
                                  null;
                            });
                          },
              ),

              const SizedBox(height: 12),

              _DateField(
                label:
                    'Access End',
                value:
                    _formatDateTime(
                  accessEnd,
                ),
                onTap:
                    chooseEndDate,
                onClear:
                    accessEnd == null
                        ? null
                        : () {
                            setState(() {
                              accessEnd =
                                  null;
                            });
                          },
              ),

              const SizedBox(height: 12),

              Text(
                'Use Access End to control how long the student can access course content and recorded videos.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall,
              ),

              if (error != null)
                Padding(
                  padding:
                      const EdgeInsets.only(
                    top: 14,
                  ),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving
              ? null
              : () =>
                  Navigator.pop(context),
          child:
              const Text('Cancel'),
        ),

        FilledButton(
          onPressed:
              saving ? null : save,
          child: Text(
            saving
                ? 'Saving...'
                : 'Save Changes',
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;

  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: Row(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              if (onClear != null)
                IconButton(
                  tooltip: 'Clear',
                  onPressed: onClear,
                  icon: const Icon(
                    Icons.close,
                  ),
                ),
              const Padding(
                padding:
                    EdgeInsets.only(
                  right: 12,
                ),
                child: Icon(
                  Icons.calendar_month,
                ),
              ),
            ],
          ),
        ),
        child: Text(value),
      ),
    );
  }
}

class _InfoRow
    extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child:
                SelectableText(value),
          ),
        ],
      ),
    );
  }
}

class _StatusChip
    extends StatelessWidget {
  const _StatusChip({
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
    return '—';
  }

  final local = value.toLocal();

  String twoDigits(int number) =>
      number.toString().padLeft(2, '0');

  return '${twoDigits(local.day)}/'
      '${twoDigits(local.month)}/'
      '${local.year} '
      '${twoDigits(local.hour)}:'
      '${twoDigits(local.minute)}';
}
