import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';
import '../data/assignment_submission.dart';
import '../data/assignment_repository.dart';

class AssignmentSubmissionDetailScreen extends ConsumerStatefulWidget {
  const AssignmentSubmissionDetailScreen({
    super.key,
    required this.submissionUuid,
  });

  final String submissionUuid;

  @override
  ConsumerState<AssignmentSubmissionDetailScreen> createState() =>
      _AssignmentSubmissionDetailScreenState();
}

class _AssignmentSubmissionDetailScreenState
    extends ConsumerState<AssignmentSubmissionDetailScreen> {
  late Future<AssignmentSubmissionReview> result;
  bool grading = false;
  int revision = 0;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(
      covariant AssignmentSubmissionDetailScreen oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.submissionUuid != widget.submissionUuid) {
      revision++;
      grading = false;
      reload();
    }
  }

  void reload() {
    result = ref
        .read(assignmentRepositoryProvider)
        .submissionDetail(widget.submissionUuid);
  }

  void refresh() {
    if (!grading) setState(reload);
  }

  void back() {
    if (grading) return;

    if (context.canPop()) {
      context.pop();
    } else {
      final uuid =
      GoRouterState.of(context).pathParameters['assignmentUuid'];

      context.go(
        uuid == null
            ? '/assignments'
            : '/assignments/$uuid/submissions',
      );
    }
  }

  Future<void> grade(
      AssignmentSubmissionReview submission,
      ) async {
    if (grading || !_canGrade(submission)) return;

    final ticket = revision;
    setState(() => grading = true);

    try {
      final updated = await showDialog<AssignmentSubmissionReview>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _GradeDialog(submission: submission),
      );

      if (!mounted || ticket != revision || updated == null) return;

      setState(() => result = Future.value(updated));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Submission graded successfully.'),
        ),
      );
    } finally {
      if (mounted && ticket == revision) {
        setState(() => grading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !grading,
    child: ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: grading ? null : back,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Submissions'),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<AssignmentSubmissionReview>(
          future: result,
          builder: (context, snapshot) {
            final state = adminFutureState(
              snapshot,
              noun: 'submission',
              onRetry: refresh,
            );

            if (state != null) return state;

            final s = snapshot.data!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminPageHeader(
                  title: s.studentName,
                  subtitle: s.assignmentTitle,
                  titleTrailing: [
                    SoftBadge(label: s.status),
                  ],
                  actions: [
                    AdminOutlineButton(
                      label: 'Refresh',
                      icon: Icons.refresh,
                      onPressed: grading ? null : refresh,
                    ),
                    if (_canGrade(s))
                      GradientButton(
                        label: s.status == 'GRADED'
                            ? 'Update Grade'
                            : 'Grade Submission',
                        icon: Icons.fact_check_outlined,
                        onPressed: grading ? null : () => grade(s),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Submission information',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _InfoRow(
                        label: 'Admission number',
                        value: s.admissionNumber,
                      ),
                      _InfoRow(
                        label: 'Assignment',
                        value: s.assignmentTitle,
                      ),
                      _InfoRow(
                        label: 'Maximum marks',
                        value: _marks(s.assignmentMaxMarks),
                      ),
                      _InfoRow(
                        label: 'Marks obtained',
                        value: s.totalMarksObtained == null
                            ? null
                            : _marks(s.totalMarksObtained!),
                      ),
                      _InfoRow(
                        label: 'Submitted at',
                        value: _date(s.submittedAt),
                      ),
                      _InfoRow(
                        label: 'Graded at',
                        value: _date(s.gradedAt),
                      ),
                      _InfoRow(
                        label: 'Graded by',
                        value: s.gradedByName,
                      ),
                      _InfoRow(
                        label: 'Overall feedback',
                        value: s.feedback,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (!['SUBMITTED', 'GRADED'].contains(s.status))
                  const Text(
                    'Only submitted or graded work can be graded.',
                  ),
                if (!s.answers.any(_manual))
                  const Text(
                    'No text or file answers require manual grading. '
                        'MCQ marks are automatic.',
                  ),
                const SizedBox(height: 24),
                Text(
                  'Student answers (${s.answers.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (s.answers.isEmpty)
                  const AdminStateMessage(
                    icon: Icons.inbox_outlined,
                    title: 'No answers',
                    message:
                    'No answers are available for this submission.',
                  ),
                for (final answer in s.answers) ...[
                  _AnswerCard(answer: answer),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.answer});

  final SubmissionAnswer answer;

  @override
  Widget build(BuildContext context) => AdminCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          answer.questionText,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SoftBadge(label: answer.answerType),
            SoftBadge(
              label: 'Maximum ${_marks(answer.maxMarks)} marks',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _StudentAnswer(answer: answer),
        const SizedBox(height: 16),
        _InfoRow(
          label: 'Marks obtained',
          value: answer.marksObtained == null
              ? 'Not graded'
              : '${_marks(answer.marksObtained!)} / '
              '${_marks(answer.maxMarks)}',
        ),
        if (answer.feedback.isNotEmpty)
          _InfoRow(
            label: 'Feedback',
            value: answer.feedback,
          ),
      ],
    ),
  );
}

class _StudentAnswer extends StatelessWidget {
  const _StudentAnswer({required this.answer});

  final SubmissionAnswer answer;

  @override
  Widget build(BuildContext context) {
    switch (answer.answerType) {
      case 'TEXT':
        return SelectableText(
          answer.textAnswer.trim().isEmpty
              ? 'No text answer provided.'
              : answer.textAnswer,
        );

      case 'FILE':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Submitted file'),
            const SizedBox(height: 6),
            SelectableText(
              answer.fileKey.isEmpty
                  ? 'No file submitted.'
                  : answer.fileKey,
            ),
          ],
        );

      case 'MCQ':
        return Text(
          answer.selectedOption.isEmpty
              ? 'No option selected.'
              : 'Selected option: ${answer.selectedOption}',
        );

      default:
        return const Text(
          'Answer type is not supported by this screen.',
        );
    }
  }
}

class _GradeInput {
  _GradeInput(this.answer)
      : marks = TextEditingController(
    text: answer.marksObtained?.toStringAsFixed(2) ?? '',
  ),
        feedback = TextEditingController(
          text: answer.feedback,
        );

  final SubmissionAnswer answer;
  final TextEditingController marks;
  final TextEditingController feedback;

  void dispose() {
    marks.dispose();
    feedback.dispose();
  }
}

class _GradeDialog extends ConsumerStatefulWidget {
  const _GradeDialog({required this.submission});

  final AssignmentSubmissionReview submission;

  @override
  ConsumerState<_GradeDialog> createState() => _GradeDialogState();
}

class _GradeDialogState extends ConsumerState<_GradeDialog> {
  final form = GlobalKey<FormState>();

  late final TextEditingController overallFeedback;
  late final List<_GradeInput> inputs;

  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();

    overallFeedback = TextEditingController(
      text: widget.submission.feedback,
    );

    inputs = widget.submission.answers
        .where(_manual)
        .map(_GradeInput.new)
        .toList();
  }

  @override
  void dispose() {
    overallFeedback.dispose();

    for (final input in inputs) {
      input.dispose();
    }

    super.dispose();
  }

  String? validateMarks(
      String? value,
      SubmissionAnswer answer,
      ) {
    final cents = _parseCents(value?.trim() ?? '');

    if (cents == null) {
      return 'Enter 0–999999.99 with at most 2 decimal places.';
    }

    if (cents > (answer.maxMarks * 100).round()) {
      return 'Maximum allowed: ${_marks(answer.maxMarks)}.';
    }

    return null;
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    if (!_canGrade(widget.submission)) return;

    final ids = inputs.map((i) => i.answer.uuid).toList();

    if (ids.any((id) => id.isEmpty) ||
        ids.toSet().length != ids.length) {
      setState(() {
        error = 'Could not prepare answers for grading. '
            'Reload the submission and try again.';
      });
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      final updated =
      await ref.read(assignmentRepositoryProvider).gradeSubmission(
        submissionUuid: widget.submission.uuid,
        feedback: overallFeedback.text.trim(),
        answers: inputs
            .map(
              (input) => <String, dynamic>{
            'answer_uuid': input.answer.uuid,
            'marks_obtained': _decimal(
              _parseCents(input.marks.text.trim())!,
            ),
            'feedback': input.feedback.text.trim(),
          },
        )
            .toList(),
      );

      if (mounted) Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Could not save grade. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AdminFormDialog(
      icon: Icons.fact_check_outlined,
      title: widget.submission.status == 'GRADED'
          ? 'Update grade'
          : 'Grade submission',
      subtitle: widget.submission.studentName,
      maxWidth: 700,
      onClose: saving
          ? null
          : () => Navigator.of(context).pop(),
      body: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.submission.assignmentTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter marks for every text and file answer. '
                  'MCQ marks remain automatic.',
            ),
            const SizedBox(height: 16),
            for (final input in inputs) ...[
              AdminCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SelectableText(
                      input.answer.questionText,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${input.answer.answerType} • '
                          'Maximum ${_marks(input.answer.maxMarks)} marks',
                    ),
                    const SizedBox(height: 12),
                    _StudentAnswer(answer: input.answer),
                    const SizedBox(height: 16),
                    FieldLabel(
                      label: 'Marks obtained',
                      required: true,
                      child: TextFormField(
                        controller: input.marks,
                        enabled: !saving,
                        keyboardType:
                        const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: adminFieldDecoration(
                          context,
                          hint: '0.00',
                        ),
                        validator: (v) =>
                            validateMarks(v, input.answer),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FieldLabel(
                      label: 'Answer feedback',
                      child: TextFormField(
                        controller: input.feedback,
                        enabled: !saving,
                        minLines: 2,
                        maxLines: 4,
                        decoration: adminFieldDecoration(
                          context,
                          hint: 'Optional feedback',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            FieldLabel(
              label: 'Overall feedback',
              child: TextFormField(
                controller: overallFeedback,
                enabled: !saving,
                minLines: 3,
                maxLines: 5,
                decoration: adminFieldDecoration(
                  context,
                  hint: 'Optional overall feedback',
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              AdminErrorBanner(message: error!),
            ],
          ],
        ),
      ),
      actions: [
        AdminOutlineButton(
          label: 'Cancel',
          onPressed: saving
              ? null
              : () => Navigator.of(context).pop(),
        ),
        GradientButton(
          label: 'Save Grade',
          icon: Icons.check,
          loading: saving,
          onPressed: saving ? null : save,
        ),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: FormRow(
      left: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      right: SelectableText(
        value?.trim().isNotEmpty == true ? value! : '—',
      ),
    ),
  );
}

bool _manual(SubmissionAnswer answer) =>
    ['TEXT', 'FILE'].contains(answer.answerType);

bool _canGrade(AssignmentSubmissionReview submission) =>
    ['SUBMITTED', 'GRADED'].contains(submission.status) &&
        submission.answers.any(_manual);

int? _parseCents(String text) {
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) return null;

  final parts = text.split('.');
  final whole = int.tryParse(parts[0]);

  if (whole == null || whole < 0 || whole > 999999) return null;

  final fraction = parts.length == 1
      ? 0
      : int.parse(parts[1].padRight(2, '0'));

  return whole * 100 + fraction;
}

String _decimal(int cents) =>
    '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

String _marks(double value) => value.toStringAsFixed(2);

String _date(DateTime? value) {
  if (value == null) return '—';

  final d = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');

  return '${two(d.day)}/${two(d.month)}/${d.year} '
      '${two(d.hour)}:${two(d.minute)}';
}