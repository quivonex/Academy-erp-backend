import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';

import '../data/assignment.dart';
import '../data/assignment_question.dart';
import '../data/assignment_repository.dart';

class AssignmentDetailScreen extends ConsumerStatefulWidget {
  const AssignmentDetailScreen({
    super.key,
    required this.assignmentUuid,
  });

  final String assignmentUuid;

  @override
  ConsumerState<AssignmentDetailScreen> createState() =>
      _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState
    extends ConsumerState<AssignmentDetailScreen> {
  late Future<Assignment> assignmentFuture;

  late Future<List<AssignmentQuestion>> questionsFuture;

  bool processing = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    assignmentFuture = ref
        .read(assignmentRepositoryProvider)
        .detail(widget.assignmentUuid);

    questionsFuture = ref
        .read(assignmentRepositoryProvider)
        .questions(widget.assignmentUuid);
  }

  void refresh() {
    setState(reload);
  }

  Future<void> togglePublish(
    Assignment assignment,
  ) async {
    setState(() {
      processing = true;
    });

    try {
      if (assignment.isPublished) {
        await ref
            .read(
              assignmentRepositoryProvider,
            )
            .unpublish(
              assignment.uuid,
            );
      } else {
        await ref
            .read(
              assignmentRepositoryProvider,
            )
            .publish(
              assignment.uuid,
            );
      }

      if (mounted) {
        refresh();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              assignment.isPublished
                  ? 'Assignment unpublished successfully.'
                  : 'Assignment published successfully.',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          processing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Assignment>(
      future: assignmentFuture,
      builder: (
        context,
        assignmentSnapshot,
      ) {
        if (assignmentSnapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (assignmentSnapshot.hasError) {
          return Center(
            child: Text(
              'Could not load assignment:\n'
              '${assignmentSnapshot.error}',
            ),
          );
        }

        final assignment = assignmentSnapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(
                Icons.arrow_back,
              ),
              label: const Text('Assignments'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        assignment.courseName,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    assignment.isPublished ? 'Published' : 'Draft',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                      label: 'Course',
                      value: assignment.courseName,
                    ),
                    _InfoRow(
                      label: 'Subject',
                      value: assignment.subjectName ?? '—',
                    ),
                    _InfoRow(
                      label: 'Chapter',
                      value: assignment.chapterTitle ?? '—',
                    ),
                    _InfoRow(
                      label: 'Lesson',
                      value: assignment.lessonTitle ?? '—',
                    ),
                    _InfoRow(
                      label: 'Max Marks',
                      value: assignment.maxMarks.toString(),
                    ),
                    _InfoRow(
                      label: 'Due At',
                      value: _formatDateTime(
                        assignment.dueAt,
                      ),
                    ),
                    _InfoRow(
                      label: 'Late Submission',
                      value: assignment.allowLateSubmission
                          ? 'Allowed'
                          : 'Not Allowed',
                    ),
                    _InfoRow(
                      label: 'Instructions',
                      value: assignment.instructions.isEmpty
                          ? '—'
                          : assignment.instructions,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                if (!assignment.isPublished)
                  FilledButton.icon(
                    onPressed: () async {
                      final created = await showDialog<bool>(
                        context: context,
                        builder: (_) => _QuestionDialog(
                          assignmentUuid: assignment.uuid,
                        ),
                      );

                      if (created == true && mounted) {
                        refresh();
                      }
                    },
                    icon: const Icon(
                      Icons.add,
                    ),
                    label: const Text(
                      'Add Question',
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: processing
                      ? null
                      : () => togglePublish(
                            assignment,
                          ),
                  icon: Icon(
                    assignment.isPublished
                        ? Icons.visibility_off_outlined
                        : Icons.publish_outlined,
                  ),
                  label: Text(
                    processing
                        ? 'Processing...'
                        : assignment.isPublished
                            ? 'Unpublish'
                            : 'Publish',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    context.push(
                      '/assignments/${assignment.uuid}/submissions',
                    );
                  },
                  icon: const Icon(
                    Icons.fact_check_outlined,
                  ),
                  label: const Text(
                    'View Submissions',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Questions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<List<AssignmentQuestion>>(
                future: questionsFuture,
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
                      child: Text(
                        'Could not load questions:\n'
                        '${snapshot.error}',
                      ),
                    );
                  }

                  final questions = snapshot.data!;

                  if (questions.isEmpty) {
                    return const Center(
                      child: Text(
                        'No questions added.',
                      ),
                    );
                  }

                  final totalMarks = questions.fold<double>(
                    0,
                    (
                      total,
                      question,
                    ) =>
                        total + question.marks,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question Marks: $totalMarks / ${assignment.maxMarks}',
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: questions.length,
                          itemBuilder: (
                            context,
                            index,
                          ) {
                            final question = questions[index];

                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${question.sequence}. ${question.questionText}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Chip(
                                          label: Text(
                                            question.answerType,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                      height: 8,
                                    ),
                                    Text(
                                      'Marks: ${question.marks}',
                                    ),
                                    if (question.answerType == 'MCQ') ...[
                                      const SizedBox(
                                        height: 8,
                                      ),
                                      Text(
                                        'A. ${question.optionA}',
                                      ),
                                      Text(
                                        'B. ${question.optionB}',
                                      ),
                                      Text(
                                        'C. ${question.optionC}',
                                      ),
                                      Text(
                                        'D. ${question.optionD}',
                                      ),
                                      const SizedBox(
                                        height: 6,
                                      ),
                                      Text(
                                        'Correct: ${question.correctOption}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                    if (question.answerType == 'TEXT' &&
                                        question.answerText.isNotEmpty) ...[
                                      const SizedBox(
                                        height: 8,
                                      ),
                                      Text(
                                        'Answer: ${question.answerText}',
                                      ),
                                    ],
                                    if (!assignment.isPublished)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Wrap(
                                          spacing: 8,
                                          children: [
                                            TextButton.icon(
                                              onPressed: () async {
                                                final updated =
                                                    await showDialog<bool>(
                                                  context: context,
                                                  builder: (_) =>
                                                      _QuestionDialog(
                                                    assignmentUuid:
                                                        assignment.uuid,
                                                    question: question,
                                                  ),
                                                );

                                                if (updated == true &&
                                                    mounted) {
                                                  refresh();
                                                }
                                              },
                                              icon: const Icon(
                                                Icons.edit,
                                              ),
                                              label: const Text(
                                                'Edit',
                                              ),
                                            ),
                                            TextButton.icon(
                                              onPressed: () => _deleteQuestion(
                                                assignment,
                                                question,
                                              ),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                              label: const Text(
                                                'Delete',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteQuestion(
    Assignment assignment,
    AssignmentQuestion question,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text(
              'Delete Question',
            ),
            content: const Text(
              'Are you sure you want to delete this question?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(
                  context,
                  false,
                ),
                child: const Text(
                  'Cancel',
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  true,
                ),
                child: const Text(
                  'Delete',
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    try {
      await ref
          .read(
            assignmentRepositoryProvider,
          )
          .deleteQuestion(
            assignmentUuid: assignment.uuid,
            questionUuid: question.uuid,
          );

      if (mounted) {
        refresh();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message,
            ),
          ),
        );
      }
    }
  }
}

class _QuestionDialog extends ConsumerStatefulWidget {
  const _QuestionDialog({
    required this.assignmentUuid,
    this.question,
  });

  final String assignmentUuid;

  final AssignmentQuestion? question;

  @override
  ConsumerState<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends ConsumerState<_QuestionDialog> {
  late final TextEditingController questionText;

  late final TextEditingController marks;

  late final TextEditingController sequence;

  late final TextEditingController answerText;

  late final TextEditingController optionA;

  late final TextEditingController optionB;

  late final TextEditingController optionC;

  late final TextEditingController optionD;

  String answerType = 'TEXT';

  String correctOption = 'A';

  bool isRequired = true;

  bool saving = false;

  String? error;

  @override
  void initState() {
    super.initState();

    final q = widget.question;

    questionText = TextEditingController(
      text: q?.questionText ?? '',
    );

    marks = TextEditingController(
      text: q?.marks.toString() ?? '1',
    );

    sequence = TextEditingController(
      text: q?.sequence.toString() ?? '1',
    );

    answerText = TextEditingController(
      text: q?.answerText ?? '',
    );

    optionA = TextEditingController(
      text: q?.optionA ?? '',
    );

    optionB = TextEditingController(
      text: q?.optionB ?? '',
    );

    optionC = TextEditingController(
      text: q?.optionC ?? '',
    );

    optionD = TextEditingController(
      text: q?.optionD ?? '',
    );

    answerType = q?.answerType ?? 'TEXT';

    correctOption =
        q?.correctOption.isNotEmpty == true ? q!.correctOption : 'A';

    isRequired = q?.isRequired ?? true;
  }

  @override
  void dispose() {
    questionText.dispose();
    marks.dispose();
    sequence.dispose();
    answerText.dispose();
    optionA.dispose();
    optionB.dispose();
    optionC.dispose();
    optionD.dispose();

    super.dispose();
  }

  Future<void> save() async {
    if (questionText.text.trim().isEmpty) {
      setState(() {
        error = 'Question is required.';
      });

      return;
    }

    if (answerType == 'MCQ') {
      if (optionA.text.trim().isEmpty ||
          optionB.text.trim().isEmpty ||
          optionC.text.trim().isEmpty ||
          optionD.text.trim().isEmpty) {
        setState(() {
          error = 'All four MCQ options are required.';
        });

        return;
      }
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      final repository = ref.read(
        assignmentRepositoryProvider,
      );

      final q = widget.question;

      if (q == null) {
        await repository.createQuestion(
          assignmentUuid: widget.assignmentUuid,
          questionText: questionText.text,
          answerType: answerType,
          marks: double.tryParse(
                marks.text,
              ) ??
              0,
          sequence: int.tryParse(
                sequence.text,
              ) ??
              1,
          isRequired: isRequired,
          answerText: answerText.text,
          optionA: optionA.text,
          optionB: optionB.text,
          optionC: optionC.text,
          optionD: optionD.text,
          correctOption: correctOption,
        );
      } else {
        await repository.updateQuestion(
          assignmentUuid: widget.assignmentUuid,
          questionUuid: q.uuid,
          questionText: questionText.text,
          answerType: answerType,
          marks: double.tryParse(
                marks.text,
              ) ??
              0,
          sequence: int.tryParse(
                sequence.text,
              ) ??
              1,
          isRequired: isRequired,
          answerText: answerText.text,
          optionA: optionA.text,
          optionB: optionB.text,
          optionC: optionC.text,
          optionD: optionD.text,
          correctOption: correctOption,
        );
      }

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
      title: Text(
        widget.question == null ? 'Add Question' : 'Edit Question',
      ),
      content: SizedBox(
        width: 550,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: questionText,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Question',
                ),
              ),
              const SizedBox(
                height: 12,
              ),
              DropdownButtonFormField<String>(
                value: answerType,
                decoration: const InputDecoration(
                  labelText: 'Answer Type',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'TEXT',
                    child: Text('Text'),
                  ),
                  DropdownMenuItem(
                    value: 'FILE',
                    child: Text('File'),
                  ),
                  DropdownMenuItem(
                    value: 'MCQ',
                    child: Text('MCQ'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    answerType = value ?? 'TEXT';
                  });
                },
              ),
              const SizedBox(
                height: 12,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: marks,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Marks',
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child: TextField(
                      controller: sequence,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Sequence',
                      ),
                    ),
                  ),
                ],
              ),
              if (answerType == 'TEXT') ...[
                const SizedBox(
                  height: 12,
                ),
                TextField(
                  controller: answerText,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Expected Answer',
                  ),
                ),
              ],
              if (answerType == 'MCQ') ...[
                const SizedBox(
                  height: 12,
                ),
                TextField(
                  controller: optionA,
                  decoration: const InputDecoration(
                    labelText: 'Option A',
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                TextField(
                  controller: optionB,
                  decoration: const InputDecoration(
                    labelText: 'Option B',
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                TextField(
                  controller: optionC,
                  decoration: const InputDecoration(
                    labelText: 'Option C',
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                TextField(
                  controller: optionD,
                  decoration: const InputDecoration(
                    labelText: 'Option D',
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                DropdownButtonFormField<String>(
                  value: correctOption,
                  decoration: const InputDecoration(
                    labelText: 'Correct Option',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'A',
                      child: Text('A'),
                    ),
                    DropdownMenuItem(
                      value: 'B',
                      child: Text('B'),
                    ),
                    DropdownMenuItem(
                      value: 'C',
                      child: Text('C'),
                    ),
                    DropdownMenuItem(
                      value: 'D',
                      child: Text('D'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      correctOption = value ?? 'A';
                    });
                  },
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Required Question',
                ),
                value: isRequired,
                onChanged: (value) {
                  setState(() {
                    isRequired = value;
                  });
                },
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(
                    top: 10,
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
          onPressed: saving
              ? null
              : () => Navigator.pop(
                    context,
                  ),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(
            saving ? 'Saving...' : 'Save Question',
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
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

  final local = value.toLocal();

  String two(int value) => value.toString().padLeft(
        2,
        '0',
      );

  return '${two(local.day)}/'
      '${two(local.month)}/'
      '${local.year} '
      '${two(local.hour)}:'
      '${two(local.minute)}';
}
