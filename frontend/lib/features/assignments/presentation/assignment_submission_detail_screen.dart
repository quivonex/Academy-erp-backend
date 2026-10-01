import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../data/assignment_submission.dart';
import '../data/assignment_repository.dart';

class AssignmentSubmissionDetailScreen
    extends ConsumerStatefulWidget {
  const AssignmentSubmissionDetailScreen({
    super.key,
    required this.submissionUuid,
  });

  final String submissionUuid;

  @override
  ConsumerState<AssignmentSubmissionDetailScreen>
      createState() =>
          _AssignmentSubmissionDetailScreenState();
}

class _AssignmentSubmissionDetailScreenState
    extends ConsumerState<
        AssignmentSubmissionDetailScreen> {
  late Future<AssignmentSubmissionReview> result;

  @override
  void initState() {
    super.initState();

    reload();
  }

  void reload() {
    result = ref
        .read(assignmentRepositoryProvider)
        .submissionDetail(
          widget.submissionUuid,
        );
  }

  void refresh() {
    setState(reload);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        AssignmentSubmissionReview>(
      future: result,
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.connectionState !=
            ConnectionState.done) {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Text(
                  'Could not load submission:\n'
                  '${snapshot.error}',
                ),

                const SizedBox(height: 8),

                TextButton(
                  onPressed: refresh,
                  child:
                      const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final submission =
            snapshot.data!;

        final manualAnswers =
            submission.answers.where(
          (answer) =>
              answer.answerType ==
                  'TEXT' ||
              answer.answerType ==
                  'FILE',
        );

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed:
                    () => context.pop(),
                icon: const Icon(
                  Icons.arrow_back,
                ),
                label: const Text(
                  'Submissions',
                ),
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    child: Icon(
                      Icons.person_outline,
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          submission.studentName,
                          style:
                              Theme.of(context)
                                  .textTheme
                                  .headlineSmall,
                        ),

                        const SizedBox(
                          height: 4,
                        ),

                        Text(
                          submission
                              .admissionNumber,
                        ),
                      ],
                    ),
                  ),

                  Chip(
                    label: Text(
                      submission.status,
                    ),
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
                        'Submission Information',
                        style:
                            Theme.of(context)
                                .textTheme
                                .titleLarge,
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      _InfoRow(
                        label:
                            'Assignment',
                        value: submission
                            .assignmentTitle,
                      ),

                      _InfoRow(
                        label:
                            'Maximum Marks',
                        value: submission
                            .assignmentMaxMarks
                            .toString(),
                      ),

                      _InfoRow(
                        label:
                            'Status',
                        value:
                            submission.status,
                      ),

                      _InfoRow(
                        label:
                            'Submitted At',
                        value:
                            _formatDateTime(
                          submission.submittedAt,
                        ),
                      ),

                      _InfoRow(
                        label:
                            'Marks Obtained',
                        value: submission
                                    .totalMarksObtained ==
                                null
                            ? '—'
                            : submission
                                .totalMarksObtained
                                .toString(),
                      ),

                      _InfoRow(
                        label:
                            'Graded At',
                        value:
                            _formatDateTime(
                          submission.gradedAt,
                        ),
                      ),

                      _InfoRow(
                        label:
                            'Graded By',
                        value: submission
                                    .gradedByName
                                    ?.isNotEmpty ==
                                true
                            ? submission
                                .gradedByName!
                            : '—',
                      ),

                      _InfoRow(
                        label:
                            'Feedback',
                        value: submission
                                .feedback
                                .isEmpty
                            ? '—'
                            : submission
                                .feedback,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Student Answers',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge,
              ),

              const SizedBox(height: 10),

              ...submission.answers.map(
                (answer) => _AnswerCard(
                  answer: answer,
                ),
              ),

              const SizedBox(height: 20),

              if (manualAnswers.isNotEmpty)
                FilledButton.icon(
                  onPressed: () async {
                    final graded =
                        await showDialog<
                            bool>(
                      context: context,
                      builder: (_) =>
                          _GradeSubmissionDialog(
                        submission:
                            submission,
                      ),
                    );

                    if (graded == true &&
                        mounted) {
                      refresh();
                    }
                  },
                  icon: const Icon(
                    Icons.fact_check,
                  ),
                  label: Text(
                    submission.status ==
                            'GRADED'
                        ? 'Update Grade'
                        : 'Grade Submission',
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      16,
                    ),
                    child: Text(
                      submission.status ==
                              'GRADED'
                          ? 'This submission contains only auto-graded answers.'
                          : 'No manual-grade TEXT or FILE answers found.',
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AnswerCard
    extends StatelessWidget {
  const _AnswerCard({
    required this.answer,
  });

  final SubmissionAnswer answer;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    answer.questionText,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),

                Chip(
                  label: Text(
                    answer.answerType,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              'Maximum Marks: ${answer.maxMarks}',
            ),

            const SizedBox(height: 10),

            if (answer.answerType ==
                'TEXT') ...[
              const Text(
                'Student Answer',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(height: 4),

              SelectableText(
                answer.textAnswer.isEmpty
                    ? 'No answer provided'
                    : answer.textAnswer,
              ),
            ],

            if (answer.answerType ==
                'FILE') ...[
              const Text(
                'Submitted File',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(height: 4),

              SelectableText(
                answer.fileKey.isEmpty
                    ? 'No file submitted'
                    : answer.fileKey,
              ),
            ],

            if (answer.answerType ==
                'MCQ') ...[
              const Text(
                'Selected Option',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                answer.selectedOption.isEmpty
                    ? 'No option selected'
                    : answer.selectedOption,
              ),
            ],

            if (answer.marksObtained !=
                null) ...[
              const Divider(
                height: 24,
              ),

              Text(
                'Marks Obtained: '
                '${answer.marksObtained} / '
                '${answer.maxMarks}',
              ),
            ],

            if (answer.feedback
                .isNotEmpty) ...[
              const SizedBox(height: 8),

              Text(
                'Feedback: ${answer.feedback}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GradeSubmissionDialog
    extends ConsumerStatefulWidget {
  const _GradeSubmissionDialog({
    required this.submission,
  });

  final AssignmentSubmissionReview
      submission;

  @override
  ConsumerState<_GradeSubmissionDialog>
      createState() =>
          _GradeSubmissionDialogState();
}

class _GradeSubmissionDialogState
    extends ConsumerState<
        _GradeSubmissionDialog> {
  final finalFeedback =
      TextEditingController();

  late List<_GradeAnswerInput>
      manualAnswers;

  bool saving = false;

  String? error;

  @override
  void initState() {
    super.initState();

    finalFeedback.text =
        widget.submission.feedback;

    manualAnswers =
        widget.submission.answers
            .where(
              (answer) =>
                  answer.answerType ==
                      'TEXT' ||
                  answer.answerType ==
                      'FILE',
            )
            .map(
              (answer) =>
                  _GradeAnswerInput(
                answer: answer,
              ),
            )
            .toList();
  }

  @override
  void dispose() {
    finalFeedback.dispose();

    for (final item
        in manualAnswers) {
      item.dispose();
    }

    super.dispose();
  }

  Future<void> save() async {
    if (manualAnswers.isEmpty) {
      setState(() {
        error =
            'No manual answers available for grading.';
      });

      return;
    }

    for (final item
        in manualAnswers) {
      final marks =
          double.tryParse(
        item.marksController.text,
      );

      if (marks == null) {
        setState(() {
          error =
              'Please enter marks for every manual answer.';
        });

        return;
      }

      if (marks < 0) {
        setState(() {
          error =
              'Marks cannot be negative.';
        });

        return;
      }

      if (marks >
          item.answer.maxMarks) {
        setState(() {
          error =
              'Marks for "${item.answer.questionText}" '
              'cannot exceed ${item.answer.maxMarks}.';
        });

        return;
      }
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      final answers =
          manualAnswers
              .map(
                (item) => {
                  'answer_uuid':
                      item.answer.uuid,
                  'marks_obtained':
                      double.parse(
                    item.marksController
                        .text,
                  ),
                  'feedback':
                      item
                          .feedbackController
                          .text
                          .trim(),
                },
              )
              .toList();

      await ref
          .read(
            assignmentRepositoryProvider,
          )
          .gradeSubmission(
            submissionUuid:
                widget.submission.uuid,
            feedback:
                finalFeedback.text,
            answers:
                answers,
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
          error =
              e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error =
              e.toString();
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
          const Text(
        'Grade Submission',
      ),
      content: SizedBox(
        width: 650,
        child:
            SingleChildScrollView(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                widget.submission
                    .studentName,
                style:
                    Theme.of(context)
                        .textTheme
                        .titleMedium,
              ),

              Text(
                widget.submission
                    .assignmentTitle,
              ),

              const SizedBox(
                height: 20,
              ),

              ...manualAnswers.map(
                (item) =>
                    _GradeAnswerCard(
                  item: item,
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              TextField(
                controller:
                    finalFeedback,
                maxLines: 3,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Overall Feedback',
                ),
              ),

              if (error != null)
                Padding(
                  padding:
                      const EdgeInsets.only(
                    top: 12,
                  ),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color:
                          Theme.of(context)
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
                  Navigator.pop(
                    context,
                  ),
          child:
              const Text('Cancel'),
        ),

        FilledButton(
          onPressed:
              saving ? null : save,
          child: Text(
            saving
                ? 'Saving...'
                : 'Save Grade',
          ),
        ),
      ],
    );
  }
}

class _GradeAnswerCard
    extends StatelessWidget {
  const _GradeAnswerCard({
    required this.item,
  });

  final _GradeAnswerInput item;

  @override
  Widget build(BuildContext context) {
    final answer =
        item.answer;

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              answer.questionText,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              'Type: ${answer.answerType}',
            ),

            Text(
              'Maximum Marks: ${answer.maxMarks}',
            ),

            const SizedBox(
              height: 10,
            ),

            if (answer.answerType ==
                'TEXT')
              SelectableText(
                answer.textAnswer.isEmpty
                    ? 'No answer provided'
                    : answer.textAnswer,
              ),

            if (answer.answerType ==
                'FILE')
              SelectableText(
                answer.fileKey.isEmpty
                    ? 'No file submitted'
                    : answer.fileKey,
              ),

            const SizedBox(
              height: 14,
            ),

            TextField(
              controller:
                  item.marksController,
              keyboardType:
                  const TextInputType
                      .numberWithOptions(
                decimal: true,
              ),
              decoration:
                  InputDecoration(
                labelText:
                    'Marks Obtained',
                helperText:
                    'Maximum ${answer.maxMarks}',
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            TextField(
              controller:
                  item.feedbackController,
              maxLines: 2,
              decoration:
                  const InputDecoration(
                labelText:
                    'Answer Feedback',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradeAnswerInput {
  _GradeAnswerInput({
    required this.answer,
  })  : marksController =
            TextEditingController(
          text:
              answer.marksObtained
                  ?.toString() ??
              '',
        ),
        feedbackController =
            TextEditingController(
          text:
              answer.feedback,
        );

  final SubmissionAnswer answer;

  final TextEditingController
      marksController;

  final TextEditingController
      feedbackController;

  void dispose() {
    marksController.dispose();
    feedbackController.dispose();
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
        vertical: 6,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          Expanded(
            child:
                SelectableText(
              value,
            ),
          ),
        ],
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

  final local =
      value.toLocal();

  String two(
    int value,
  ) =>
      value
          .toString()
          .padLeft(2, '0');

  return '${two(local.day)}/'
      '${two(local.month)}/'
      '${local.year} '
      '${two(local.hour)}:'
      '${two(local.minute)}';
}
