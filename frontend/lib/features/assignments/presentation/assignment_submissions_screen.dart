import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/admin_ui.dart';
import '../data/assignment_submission.dart';
import '../data/assignment_repository.dart';

class AssignmentSubmissionsScreen extends ConsumerStatefulWidget {
  const AssignmentSubmissionsScreen({
    super.key,
    required this.assignmentUuid,
  });

  final String assignmentUuid;

  @override
  ConsumerState<AssignmentSubmissionsScreen> createState() =>
      _AssignmentSubmissionsScreenState();
}

class _AssignmentSubmissionsScreenState
    extends ConsumerState<AssignmentSubmissionsScreen> {
  late Future<AssignmentSubmissionPage> result;
  String? statusFilter;
  int page = 1;
  int revision = 0;
  bool opening = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(covariant AssignmentSubmissionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.assignmentUuid != widget.assignmentUuid) {
      revision++;
      opening = false;
      statusFilter = null;
      page = 1;
      reload();
    }
  }

  void reload() {
    result = ref.read(assignmentRepositoryProvider).submissions(
      assignmentUuid: widget.assignmentUuid,
      status: statusFilter,
      page: page,
    );
  }

  void refresh() {
    if (!opening) setState(reload);
  }

  void filter(String? value) {
    if (opening || value == statusFilter) return;

    setState(() {
      statusFilter = value;
      page = 1;
      reload();
    });
  }

  void changePage(int value) {
    if (opening || value < 1 || value == page) return;

    setState(() {
      page = value;
      reload();
    });
  }

  void back() {
    if (opening) return;

    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/assignments/${widget.assignmentUuid}');
    }
  }

  Future<void> openSubmission(
      AssignmentSubmission submission,
      ) async {
    if (opening || submission.uuid.isEmpty) return;

    final ticket = revision;
    final assignmentUuid = widget.assignmentUuid;

    setState(() => opening = true);

    try {
      await context.push(
        '/assignments/$assignmentUuid/submissions/${submission.uuid}',
      );

      if (mounted && ticket == revision) {
        setState(reload);
      }
    } catch (_) {
      if (mounted && ticket == revision) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open submission. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted && ticket == revision) {
        setState(() => opening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: opening ? null : back,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Assignment'),
        ),
      ),
      const SizedBox(height: 12),
      AdminPageHeader(
        eyebrow: const AdminEyebrow(
          section: 'Evaluation hub',
          detail: 'Submission review',
        ),
        title: 'Student Submissions',
        subtitle:
        'Review submitted work and open a submission to grade it.',
        actions: [
          AdminOutlineButton(
            label: 'Refresh',
            icon: Icons.refresh_rounded,
            onPressed: opening ? null : refresh,
          ),
        ],
      ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          CountFilterPill(
            label: 'All',
            selected: statusFilter == null,
            onTap: () => filter(null),
          ),
          CountFilterPill(
            label: 'Submitted',
            selected: statusFilter == 'SUBMITTED',
            onTap: () => filter('SUBMITTED'),
          ),
          CountFilterPill(
            label: 'Graded',
            selected: statusFilter == 'GRADED',
            onTap: () => filter('GRADED'),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Expanded(
        child: FutureBuilder<AssignmentSubmissionPage>(
          future: result,
          builder: (context, snapshot) {
            final state = adminFutureState(
              snapshot,
              noun: 'submissions',
              onRetry: refresh,
            );

            final data = state == null ? snapshot.data : null;
            final rows =
                data?.results ?? const <AssignmentSubmission>[];

            final submitted = rows
                .where((s) => s.status == 'SUBMITTED')
                .length;

            final graded =
                rows.where((s) => s.status == 'GRADED').length;

            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                AdminKpiGrid(
                  children: [
                    AdminKpiCard(
                      label: statusFilter == null
                          ? 'Total submissions'
                          : 'Matching submissions',
                      value: data == null ? '…' : '${data.count}',
                      icon: Icons.assignment_turned_in_outlined,
                      caption: statusFilter == null
                          ? 'Submitted and graded work'
                          : 'Current status filter',
                    ),
                    AdminKpiCard(
                      label: 'Submitted',
                      value: data == null ? '…' : '$submitted',
                      icon: Icons.pending_actions_outlined,
                      caption: 'On this page',
                      iconBackground: const Color(0xFFFFFBEB),
                      iconForeground: const Color(0xFFD97706),
                    ),
                    AdminKpiCard(
                      label: 'Graded',
                      value: data == null ? '…' : '$graded',
                      icon: Icons.fact_check_outlined,
                      caption: 'On this page',
                      iconBackground: const Color(0xFFECFDF5),
                      iconForeground: const Color(0xFF059669),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (state != null)
                  state
                else if (rows.isEmpty)
                  AdminStateMessage(
                    icon: Icons.inbox_outlined,
                    title: 'No submissions found',
                    message: page > 1
                        ? 'No records on this page. Use the pager '
                        'to go back or refresh the list.'
                        : statusFilter == null
                        ? 'Student work will appear here '
                        'after submission.'
                        : 'No work matches this status filter.',
                    actionLabel:
                    statusFilter != null && !opening
                        ? 'Show all'
                        : null,
                    onAction: statusFilter != null && !opening
                        ? () => filter(null)
                        : null,
                  )
                else
                  for (final submission in rows)
                    AdminListRow(
                      title: submission.studentName,
                      icon: Icons.person_outline,
                      subtitle: submission.admissionNumber.isEmpty
                          ? 'Admission number unavailable'
                          : 'Admission: ${submission.admissionNumber}',
                      meta: [
                        MetaChip(
                          icon: Icons.event_outlined,
                          label:
                          'Submitted: ${_date(submission.submittedAt)}',
                        ),
                        if (submission.gradedAt != null)
                          MetaChip(
                            icon: Icons.task_alt,
                            label:
                            'Graded: ${_date(submission.gradedAt)}',
                          ),
                        if (submission.totalMarksObtained != null)
                          MetaChip(
                            icon: Icons.star_outline,
                            label:
                            '${submission.totalMarksObtained!.toStringAsFixed(2)} marks',
                          ),
                      ],
                      trailing: [
                        SoftBadge(
                          label: _statusLabel(submission.status),
                          background:
                          submission.status == 'GRADED'
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFFFBEB),
                          foreground:
                          submission.status == 'GRADED'
                              ? const Color(0xFF059669)
                              : const Color(0xFFD97706),
                        ),
                      ],
                      onTap: opening || submission.uuid.isEmpty
                          ? null
                          : () => openSubmission(submission),
                    ),
                if (state == null && data != null)
                  AdminPager(
                    page: page,
                    pageSize: 20,
                    total: data.count,
                    noun: 'submissions',
                    onPage: changePage,
                  ),
              ],
            );
          },
        ),
      ),
    ],
  );
}

String _statusLabel(String value) {
  switch (value) {
    case 'SUBMITTED':
      return 'Submitted';
    case 'GRADED':
      return 'Graded';
    default:
      return value.isEmpty ? 'Unknown' : value;
  }
}

String _date(DateTime? value) {
  if (value == null) return '—';

  final d = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');

  return '${two(d.day)}/${two(d.month)}/${d.year} '
      '${two(d.hour)}:${two(d.minute)}';
}