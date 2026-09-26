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

  Future<void> _submit(List<dynamic> questions) async {
    final answers = <Map<String, dynamic>>[];

    for (final raw in questions) {
      final question = Map<String, dynamic>.from(
        raw as Map,
      );

      final uuid =
          question['uuid']?.toString() ?? '';

      if (uuid.isEmpty) continue;

      final type = question['answer_type']
              ?.toString()
              .toUpperCase() ??
          '';

      final required =
          question['is_required'] == true;

      if (type == 'MCQ') {
        final selected = _mcqAnswers[uuid];

        if (selected == null && required) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please answer all required MCQ questions.',
              ),
            ),
          );
          return;
        }

        if (selected != null) {
          answers.add({
            'question_uuid': uuid,
            'selected_option': selected,
          });
        }
      } else if (type == 'TEXT') {
        final text = _textControllers[uuid]
                ?.text
                .trim() ??
            '';

        if (text.isEmpty && required) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please answer all required text questions.',
              ),
            ),
          );
          return;
        }

        if (text.isNotEmpty) {
          answers.add({
            'question_uuid': uuid,
            'text_answer': text,
          });
        }
      }
    }

    if (answers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
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

  Widget _questionCard(Map<String, dynamic> question) {
    final uuid = question['uuid']?.toString() ?? '';
    final type = question['answer_type']
            ?.toString()
            .toUpperCase() ??
        '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question['question_text']?.toString() ?? '',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),

            if (type == 'MCQ') ...[
              for (final option in ['A', 'B', 'C', 'D'])
                if (question['option_${option.toLowerCase()}']
                        ?.toString()
                        .isNotEmpty ==
                    true)
                  RadioListTile<String>(
                    value: option,
                    groupValue: _mcqAnswers[uuid],
                    title: Text(
                      '$option. '
                      '${question['option_${option.toLowerCase()}']}',
                    ),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _mcqAnswers[uuid] = value);
                    },
                  ),
            ] else if (type == 'TEXT') ...[
              TextField(
                controller: _textControllers.putIfAbsent(
                  uuid,
                  TextEditingController.new,
                ),
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Your answer',
                  alignLabelWithHint: true,
                ),
              ),
            ] else ...[
              const Text('Unsupported question type.'),
            ],
          ],
        ),
      ),
    );
  }
}

class StudentAssignmentResultScreen
    extends ConsumerStatefulWidget {
  const StudentAssignmentResultScreen({
    super.key,
    required this.assignmentUuid,
  });

  final String assignmentUuid;

  @override
  ConsumerState<StudentAssignmentResultScreen>
      createState() =>
          _StudentAssignmentResultScreenState();
}

class _StudentAssignmentResultScreenState
    extends ConsumerState<
        StudentAssignmentResultScreen> {
  late Future<Map<String, dynamic>> _result;

  @override
  void initState() {
    super.initState();
    _result = _fetchResult();
  }

  Future<Map<String, dynamic>> _fetchResult() {
    return ref
        .read(studentPortalRepositoryProvider)
        .assignmentResult(
          widget.assignmentUuid,
        );
  }

  Future<void> _refresh() async {
    final next = _fetchResult();

    setState(() => _result = next);

    try {
      await next;
    } catch (_) {
      // FutureBuilder error दाखवेल.
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _result,
        builder: (context, snapshot) {
          if (snapshot.connectionState !=
              ConnectionState.done) {
            return ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 100),
                Center(
                  child: CircularProgressIndicator(),
                ),
              ],
            );
          }

          if (snapshot.hasError) {
            return ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Could not load result: '
                  '${snapshot.error}',
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _refresh,
                  child: const Text('Retry'),
                ),
              ],
            );
          }

          final result = snapshot.data!;

          final graded = result['status']
                  ?.toString()
                  .toUpperCase() ==
              'GRADED';

          return ListView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Assignment Result',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall,
              ),
              const SizedBox(height: 20),

              if (!graded) ...[
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Submission received',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Your result is not available yet. '
                          'Check again after the academy '
                          'completes grading.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label:
                      const Text('Check result again'),
                ),
              ] else ...[
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Marks',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${result['marks_obtained'] ?? 0}'
                          ' / '
                          '${result['max_marks'] ?? 0}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Percentage: '
                          '${result['percentage'] ?? 0}%',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.check_circle_outline,
                        ),
                        title: const Text(
                          'Correct MCQ answers',
                        ),
                        trailing: Text(
                          '${result['correct_answers'] ?? 0}',
                        ),
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.cancel_outlined,
                        ),
                        title: const Text(
                          'Wrong MCQ answers',
                        ),
                        trailing: Text(
                          '${result['wrong_answers'] ?? 0}',
                        ),
                      ),
                    ],
                  ),
                ),
                if (result['feedback']
                        ?.toString()
                        .isNotEmpty ==
                    true) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(16),
                      child: Text(
                        'Feedback: '
                        '${result['feedback']}',
                      ),
                    ),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}