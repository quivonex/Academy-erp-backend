import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/student_portal_repository.dart';

class StudentAssignmentScreen
    extends ConsumerStatefulWidget {
  const StudentAssignmentScreen({
    super.key,
    required this.assignmentUuid,
  });

  final String assignmentUuid;

  @override
  ConsumerState<StudentAssignmentScreen>
  createState() =>
      _StudentAssignmentScreenState();
}

class _StudentAssignmentScreenState
    extends ConsumerState<StudentAssignmentScreen> {
  late Future<Map<String, dynamic>> _assignment;

  final Map<String, String> _mcqAnswers = {};
  final Map<String, TextEditingController>
  _textControllers = {};

  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    _assignment = ref
        .read(studentPortalRepositoryProvider)
        .assignment(widget.assignmentUuid);
  }

  @override
  void dispose() {
    for (final controller
    in _textControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> _submit(
      List<dynamic> questions,
      ) async {
    final answers =
    <Map<String, dynamic>>[];

    for (final raw in questions) {
      final question =
      Map<String, dynamic>.from(
        raw as Map,
      );

      final uuid =
          question['uuid']?.toString() ?? '';

      if (uuid.isEmpty) continue;

      final type = question['answer_type']
          ?.toString()
          .toUpperCase() ??
          '';

      if (type == 'MCQ') {
        final selected =
        _mcqAnswers[uuid];

        if (selected != null) {
          answers.add({
            'question_uuid': uuid,
            'selected_option': selected,
          });
        }
      } else {
        final text = _textControllers[uuid]
            ?.text
            .trim() ??
            '';

        if (text.isNotEmpty) {
          answers.add({
            'question_uuid': uuid,
            'text_answer': text,
          });
        }
      }
    }

    if (answers.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Answer at least one question.',
          ),
        ),
      );

      return;
    }

    setState(() => _submitting = true);

    try {
      await ref
          .read(studentPortalRepositoryProvider)
          .submitAssignment(
        assignmentUuid:
        widget.assignmentUuid,
        answers: answers,
      );

      if (!mounted) return;

      context.go(
        '/student/assignments/'
            '${widget.assignmentUuid}/result',
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text('$error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(
              () => _submitting = false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _assignment,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load assignment: '
                  '${snapshot.error}',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final assignment = snapshot.data!;
        final questions =
        assignment['questions'] is List
            ? assignment['questions'] as List
            : <dynamic>[];

        final alreadySubmitted =
            assignment['submission_status'] ==
                'SUBMITTED' ||
                assignment[
                'submission_status'] ==
                    'GRADED';

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              assignment['title']
                  ?.toString() ??
                  'Assignment',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              assignment['instructions']
                  ?.toString() ??
                  '',
            ),
            const SizedBox(height: 16),
            if (alreadySubmitted)
              FilledButton(
                onPressed: () => context.go(
                  '/student/assignments/'
                      '${widget.assignmentUuid}/result',
                ),
                child: const Text(
                  'View result',
                ),
              )
            else ...[
              for (final raw in questions)
                _questionCard(
                  Map<String, dynamic>.from(
                    raw as Map,
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitting
                    ? null
                    : () => _submit(questions),
                child: Text(
                  _submitting
                      ? 'Submitting...'
                      : 'Submit assignment',
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _questionCard(
      Map<String, dynamic> question,
      ) {
    final uuid =
        question['uuid']?.toString() ?? '';

    final type = question['answer_type']
        ?.toString()
        .toUpperCase() ??
        '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              question['question_text']
                  ?.toString() ??
                  '',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),
            const SizedBox(height: 10),
            if (type == 'MCQ')
              for (final option in [
                'A',
                'B',
                'C',
                'D',
              ])
                if (question[
                'option_${option.toLowerCase()}']
                    ?.toString()
                    .isNotEmpty ==
                    true)
                  RadioListTile<String>(
                    value: option,
                    groupValue:
                    _mcqAnswers[uuid],
                    title: Text(
                      '$option. '
                          '${question['option_${option.toLowerCase()}']}',
                    ),
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        _mcqAnswers[uuid] =
                            value;
                      });
                    },
                  )
                else
                  TextField(
                    controller:
                    _textControllers.putIfAbsent(
                      uuid,
                          () =>
                          TextEditingController(),
                    ),
                    maxLines: 4,
                    decoration:
                    const InputDecoration(
                      labelText:
                      'Your answer',
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class StudentAssignmentResultScreen
    extends ConsumerWidget {
  const StudentAssignmentResultScreen({
    super.key,
    required this.assignmentUuid,
  });

  final String assignmentUuid;

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ref
          .read(studentPortalRepositoryProvider)
          .assignmentResult(
        assignmentUuid,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load result: '
                  '${snapshot.error}',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final result = snapshot.data!;
        final graded =
            result['status'] == 'GRADED';

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Assignment result',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall,
            ),
            const SizedBox(height: 20),
            if (!graded)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Result is not available yet.',
                  ),
                ),
              )
            else ...[
              Text(
                'Marks: '
                    '${result['marks_obtained']}'
                    ' / ${result['max_marks']}',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Percentage: '
                    '${result['percentage']}%',
              ),
              Text(
                'Correct answers: '
                    '${result['correct_answers']}',
              ),
              Text(
                'Wrong answers: '
                    '${result['wrong_answers']}',
              ),
              if (result['feedback'] != null)
                Text(
                  'Feedback: '
                      '${result['feedback']}',
                ),
            ],
          ],
        );
      },
    );
  }
}