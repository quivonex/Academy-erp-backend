import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/status_pill.dart';
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
  bool busy = false;
  int revision = 0;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(covariant EnrollmentDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.enrollmentUuid != widget.enrollmentUuid) {
      revision++;
      reload();
    }
  }

  void reload() {
    result = ref
        .read(enrollmentManagementRepositoryProvider)
        .detail(widget.enrollmentUuid);
  }

  void refresh() {
    if (!busy) setState(reload);
  }

  Future<void> editEnrollment(Enrollment enrollment) async {
    if (busy) return;

    final currentRevision = revision;
    setState(() => busy = true);

    try {
      final updated = await showDialog<Enrollment>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _EditEnrollmentDialog(
          enrollment: enrollment,
        ),
      );

      if (!mounted ||
          currentRevision != revision ||
          updated == null) {
        return;
      }

      setState(() => result = Future.value(updated));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enrollment updated successfully.'),
        ),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openFees(Enrollment enrollment) async {
    if (busy) return;

    final currentRevision = revision;
    setState(() => busy = true);

    try {
      await context.push('/fees/${enrollment.uuid}');

      if (mounted && currentRevision == revision) {
        setState(reload);
      }
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
              context.go('/enrollments');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Enrollments'),
        ),
      ),
      FutureBuilder<Enrollment>(
        future: result,
        builder: (context, snapshot) {
          final state = adminFutureState(
            snapshot,
            noun: 'enrollment',
            onRetry: refresh,
          );

          if (state != null) return state;

          final enrollment = snapshot.data!;
          final status = enrollment.status.toUpperCase();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminPageHeader(
                eyebrow: const AdminEyebrow(
                  section: 'Admissions',
                  detail: 'Enrollment details',
                ),
                title: enrollment.studentName,
                subtitle: enrollment.admissionNumber,
                titleTrailing: [
                  StatusPill(
                    label: status,
                    compact: true,
                    tone: switch (status) {
                      'ACTIVE' => PillTone.success,
                      'PENDING' => PillTone.info,
                      'CANCELLED' => PillTone.danger,
                      _ => PillTone.neutral,
                    },
                  ),
                ],
                actions: [
                  AdminOutlineButton(
                    label: 'Refresh',
                    icon: Icons.refresh_rounded,
                    onPressed: busy ? null : refresh,
                  ),
                  AdminOutlineButton(
                    label: 'Fees & payments',
                    icon: Icons.account_balance_wallet_outlined,
                    onPressed:
                    busy ? null : () => openFees(enrollment),
                  ),
                  GradientButton(
                    label: 'Manage enrollment',
                    icon: Icons.edit_outlined,
                    onPressed: busy
                        ? null
                        : () => editEnrollment(enrollment),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AdminCard(
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'Student name',
                      value: enrollment.studentName,
                    ),
                    _InfoRow(
                      label: 'Admission number',
                      value: enrollment.admissionNumber,
                    ),
                    _InfoRow(
                      label: 'Course name',
                      value: enrollment.courseName,
                    ),
                    _InfoRow(
                      label: 'Course code',
                      value: enrollment.courseCode,
                    ),
                    _InfoRow(
                      label: 'Status',
                      value: status,
                    ),
                    _InfoRow(
                      label: 'Enrolled at',
                      value: _date(enrollment.enrolledAt),
                    ),
                    _InfoRow(
                      label: 'Access start',
                      value: _date(enrollment.accessStartAt),
                    ),
                    _InfoRow(
                      label: 'Access end',
                      value: _date(enrollment.accessEndAt),
                    ),
                    _InfoRow(
                      label: 'Created',
                      value: _date(enrollment.createdAt),
                    ),
                    _InfoRow(
                      label: 'Last updated',
                      value: _date(enrollment.updatedAt),
                    ),
                    _InfoRow(
                      label: 'Enrollment UUID',
                      value: enrollment.uuid,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

class _EditEnrollmentDialog extends ConsumerStatefulWidget {
  const _EditEnrollmentDialog({required this.enrollment});

  final Enrollment enrollment;

  @override
  ConsumerState<_EditEnrollmentDialog> createState() =>
      _EditEnrollmentDialogState();
}

class _EditEnrollmentDialogState
    extends ConsumerState<_EditEnrollmentDialog> {
  static const statuses = [
    'PENDING',
    'ACTIVE',
    'COMPLETED',
    'CANCELLED',
  ];

  final formKey = GlobalKey<FormState>();

  late String status;
  DateTime? accessStart;
  DateTime? accessEnd;
  bool saving = false;
  bool picking = false;
  String? error;

  bool get pending => status == 'PENDING';

  @override
  void initState() {
    super.initState();

    status = widget.enrollment.status.toUpperCase();
    accessStart = widget.enrollment.accessStartAt?.toLocal();
    accessEnd = widget.enrollment.accessEndAt?.toLocal();
  }

  Future<void> pick(bool start) async {
    if (saving || picking || pending) return;

    setState(() => picking = true);

    try {
      final initial =
          (start ? accessStart : accessEnd ?? accessStart) ??
              DateTime.now();

      final day = DateTime(
        initial.year,
        initial.month,
        initial.day,
      );

      final first =
      day.isBefore(DateTime(2000)) ? day : DateTime(2000);

      final last = day.isAfter(DateTime(2100, 12, 31))
          ? day
          : DateTime(2100, 12, 31);

      final date = await showDatePicker(
        context: context,
        initialDate: day,
        firstDate: first,
        lastDate: last,
      );

      if (!mounted || date == null) return;

      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );

      if (!mounted || time == null) return;

      setState(() {
        final value = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        if (start) {
          accessStart = value;
        } else {
          accessEnd = value;
        }

        error = null;
      });
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  void clearDate(bool start) {
    if (saving || picking || pending) return;

    setState(() {
      if (start) {
        accessStart = null;
      } else {
        accessEnd = null;
      }

      error = null;
    });
  }

  Future<void> save() async {
    if (saving ||
        picking ||
        !formKey.currentState!.validate()) {
      return;
    }

    if (!pending &&
        accessStart != null &&
        accessEnd != null &&
        !accessEnd!.isAfter(accessStart!)) {
      setState(() {
        error = 'Access end must be after access start.';
      });
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      final updated = await ref
          .read(enrollmentManagementRepositoryProvider)
          .update(
        uuid: widget.enrollment.uuid,
        status: status,
        accessStartAt: pending ? null : accessStart,
        accessEndAt: pending ? null : accessEnd,
      );

      if (mounted) Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          error =
          'Could not update enrollment. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving && !picking,
    child: AdminFormDialog(
      icon: Icons.how_to_reg_outlined,
      title: 'Manage enrollment',
      subtitle:
      '${widget.enrollment.studentName} • ${widget.enrollment.courseName}',
      onClose: saving || picking
          ? null
          : () => Navigator.of(context).pop(),
      body: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: status,
              isExpanded: true,
              decoration: adminFieldDecoration(context).copyWith(
                labelText: 'Enrollment status',
              ),
              items: [
                for (final value in statuses)
                  DropdownMenuItem(
                    value: value,
                    child: Text(value),
                  ),
                if (!statuses.contains(status))
                  DropdownMenuItem(
                    value: status,
                    child: Text(status),
                  ),
              ],
              validator: (value) => statuses.contains(value)
                  ? null
                  : 'Select a valid status.',
              onChanged: saving || picking
                  ? null
                  : (value) {
                if (value == null) return;

                setState(() {
                  status = value;
                  error = null;
                });
              },
            ),
            const SizedBox(height: 16),
            if (pending)
              const Text(
                'Pending enrollment has no content access. '
                    'Saving clears its access dates.',
              )
            else ...[
              for (final start in [true, false])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DateField(
                    label: start
                        ? 'Access start (local time)'
                        : 'Access end (local time)',
                    value: _date(
                      start ? accessStart : accessEnd,
                    ),
                    onTap: saving || picking
                        ? null
                        : () => pick(start),
                    onClear: saving ||
                        picking ||
                        (start ? accessStart : accessEnd) == null
                        ? null
                        : () => clearDate(start),
                  ),
                ),
              Text(
                status == 'ACTIVE'
                    ? 'A blank start date begins access now. '
                    'A blank end date may be set automatically '
                    'using the course access duration.'
                    : 'Set access dates where needed. '
                    'You can clear a date.',
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        AdminOutlineButton(
          label: 'Cancel',
          onPressed: saving || picking
              ? null
              : () => Navigator.of(context).pop(),
        ),
        GradientButton(
          label: 'Save changes',
          loading: saving,
          onPressed: saving || picking ? null : save,
        ),
      ],
    ),
  );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: InputDecorator(
      decoration: adminFieldDecoration(context).copyWith(
        labelText: label,
        enabled: onTap != null,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onClear != null)
              IconButton(
                tooltip: 'Clear date',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.calendar_month_outlined),
            ),
          ],
        ),
      ),
      child: Text(value),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final heading = Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        );

        final text = value.trim().isEmpty ? '—' : value;

        if (constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: 4),
              SelectableText(text),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 170, child: heading),
            Expanded(child: SelectableText(text)),
          ],
        );
      },
    ),
  );
}

String _date(DateTime? value) {
  if (value == null) return '—';

  final local = value.toLocal();

  String two(int number) =>
      number.toString().padLeft(2, '0');

  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}