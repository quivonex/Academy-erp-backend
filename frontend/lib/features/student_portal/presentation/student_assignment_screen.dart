import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/student_portal_repository.dart';
import 'widgets/student_ui.dart';

const _dueDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _dueMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _dueLabel(DateTime due) {
  final local = due.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return 'Due ${_dueDays[local.weekday - 1]}, '
      '${_dueMonths[local.month - 1]} ${local.day} · '
      '$hour:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
}

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

    if (_submitting) return;

    setState(() => _submitting = true);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Submit assignment?'),
          content: Text(
            'You have answered ${answers.length} of '
            '${questions.length} questions. '
            'You cannot change your answers after submission.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(false),
              child: const Text('Review answers'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(true),
              child: const Text('Submit'),
            ),
          ],
        ),
      );

      if (!mounted || confirmed != true) return;
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
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return FutureBuilder<Map<String, dynamic>>(
      future: _assignment,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return StudentPageFrame(
            child: ListView(
              padding: const EdgeInsets.all(kStudentPagePadding),
              children: [
                StudentStateMessage(
                  icon: Icons.wifi_off_rounded,
                  title: 'Assignment could not load',
                  message: '${snapshot.error}',
                  actionLabel: 'Try again',
                  onAction: () {
                    setState(() {
                      _assignment = ref
                          .read(studentPortalRepositoryProvider)
                          .assignment(widget.assignmentUuid);
                    });
                  },
                  isError: true,
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final assignment = snapshot.data!;
        final questions = assignment['questions'] is List
            ? assignment['questions'] as List
            : <dynamic>[];

        final alreadySubmitted =
            assignment['submission_status'] == 'SUBMITTED' ||
                assignment['submission_status'] == 'GRADED';

        final dueAt = DateTime.tryParse(
          assignment['due_at']?.toString() ?? '',
        );

        final deadlinePassed = dueAt != null &&
            DateTime.now().isAfter(dueAt) &&
            assignment['allow_late_submission'] != true;

        final lateAllowed = dueAt != null &&
            DateTime.now().isAfter(dueAt) &&
            assignment['allow_late_submission'] == true;

        final maxMarks = assignment['max_marks']?.toString() ?? '';
        final instructions =
            assignment['instructions']?.toString().trim() ?? '';
        final courseName = assignment['course_name']?.toString() ?? '';

        final statusPill = alreadySubmitted
            ? TonalPill(
                label: assignment['submission_status'] == 'GRADED'
                    ? 'Graded'
                    : 'Turned in',
                icon: Icons.check_circle_outline_rounded,
                background: colors.successBg,
                foreground: colors.success,
              )
            : deadlinePassed
                ? TonalPill(
                    label: 'Closed',
                    background: colors.dangerBg,
                    foreground: colors.danger,
                  )
                : TonalPill(
                    label: 'Active',
                    dot: true,
                    background: colors.successBg,
                    foreground: colors.success,
                  );

        final list = StudentPageFrame(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              kStudentPagePadding,
              4,
              kStudentPagePadding,
              24,
            ),
            children: [
              // Header card
              PremiumCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (dueAt != null)
                          TonalPill(
                            label: _dueLabel(dueAt),
                            icon: Icons.schedule_rounded,
                            background: deadlinePassed
                                ? colors.dangerBg
                                : colors.warningBg,
                            foreground: deadlinePassed
                                ? colors.danger
                                : colors.warning,
                          )
                        else
                          const TonalPill(
                            label: 'No due date',
                            icon: Icons.all_inclusive_rounded,
                          ),
                        if (courseName.isNotEmpty)
                          TonalPill(label: courseName),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      assignment['title']?.toString() ?? 'Assignment',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Divider(height: 1, color: colors.borderSubtle),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.star_outline_rounded,
                            size: 20, color: colors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: 'Total: '),
                                TextSpan(
                                  text: maxMarks.isEmpty
                                      ? '—'
                                      : '$maxMarks marks',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(
                                  text: ' · ${questions.length} '
                                      '${questions.length == 1 ? 'question' : 'questions'}',
                                ),
                              ],
                            ),
                            style: textTheme.bodyMedium,
                          ),
                        ),
                        statusPill,
                      ],
                    ),
                  ],
                ),
              ),

              // Instructions / status panel
              if (instructions.isNotEmpty || lateAllowed)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F3FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.primaryTonalBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.assignment_outlined,
                              size: 20, color: colors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              alreadySubmitted
                                  ? 'Instructions'
                                  : 'Pending submission',
                              style: textTheme.titleSmall,
                            ),
                          ),
                          if (!alreadySubmitted)
                            TonalPill(
                              label: 'Not turned in',
                              background: colors.warningBg,
                              foreground: colors.warning,
                            ),
                        ],
                      ),
                      if (instructions.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          instructions,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.textMuted,
                            height: 1.5,
                          ),
                        ),
                      ],
                      if (lateAllowed) ...[
                        const SizedBox(height: 10),
                        Text(
                          'The due date has passed, but late submissions '
                          'are allowed.',
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.warning,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              if (alreadySubmitted)
                StudentStateMessage(
                  icon: Icons.task_alt_rounded,
                  title: 'Work turned in',
                  message: 'Your answers were submitted. '
                      'Check your marks and feedback.',
                  actionLabel: 'View result',
                  onAction: () => context.go(
                    '/student/assignments/'
                    '${widget.assignmentUuid}/result',
                  ),
                )
              else ...[
                SectionHeader(
                  title: 'Your work',
                  icon: Icons.edit_note_rounded,
                  trailing: Text(
                    '${questions.length} '
                    '${questions.length == 1 ? 'question' : 'questions'}',
                    style: textTheme.labelLarge?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ),
                if (questions.isEmpty)
                  const StudentStateMessage(
                    icon: Icons.help_outline_rounded,
                    title: 'No questions yet',
                    message: 'This assignment has no questions to answer.',
                  ),
                for (var index = 0; index < questions.length; index++)
                  _questionCard(
                    Map<String, dynamic>.from(
                      questions[index] as Map,
                    ),
                    index + 1,
                  ),
                if (deadlinePassed)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.dangerBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_clock_outlined,
                            color: colors.danger, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'The submission deadline has passed.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        );

        if (alreadySubmitted) return list;

        return Column(
          children: [
            Expanded(child: list),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.borderSubtle)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: kStudentMaxWidth),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _submitting || deadlinePassed
                              ? null
                              : () => _submit(questions),
                          icon: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                          label: Text(
                            _submitting
                                ? 'Submitting...'
                                : 'Submit assignment',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _questionCard(Map<String, dynamic> question, int number) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    final uuid = question['uuid']?.toString() ?? '';
    final type = question['answer_type']?.toString().toUpperCase() ?? '';
    final required = question['is_required'] == true;

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primaryDeep,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$number',
                  style: textTheme.labelLarge?.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  type == 'MCQ'
                      ? 'Multiple choice'
                      : type == 'TEXT'
                          ? 'Written answer'
                          : 'Question',
                  style: textTheme.labelMedium,
                ),
              ),
              if (required)
                TonalPill(
                  label: 'Required',
                  background: colors.dangerBg,
                  foreground: colors.danger,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            question['question_text']?.toString() ?? '',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (type == 'MCQ') ...[
            for (final option in ['A', 'B', 'C', 'D'])
              if (question['option_${option.toLowerCase()}']
                      ?.toString()
                      .isNotEmpty ==
                  true)
                _OptionTile(
                  letter: option,
                  text: '${question['option_${option.toLowerCase()}']}',
                  selected: _mcqAnswers[uuid] == option,
                  onTap: () {
                    setState(() => _mcqAnswers[uuid] = option);
                  },
                ),
          ] else if (type == 'TEXT') ...[
            TextField(
              controller: _textControllers.putIfAbsent(
                uuid,
                TextEditingController.new,
              ),
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Write your answer here…',
                filled: true,
                fillColor: const Color(0xFFF7F7FE),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.borderSubtle),
                ),
              ),
            ),
          ] else ...[
            Text(
              'Unsupported question type.',
              style: textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? colors.primaryTonal : const Color(0xFFF7F7FE),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? colors.primary : colors.borderSubtle,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? colors.primary : colors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? colors.primary : colors.borderSubtle,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          size: 16, color: Colors.white)
                      : Text(
                          letter,
                          style: textTheme.labelLarge?.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: textTheme.bodyMedium?.copyWith(
                      color: selected ? colors.primaryDeep : colors.textPrimary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
    extends ConsumerState<StudentAssignmentResultScreen> {
  late Future<Map<String, dynamic>> _result;
  Timer? _pollTimer;
  bool _requestInFlight = false;
  bool _graded = false;

  @override
  void initState() {
    super.initState();
    _result = _fetchResult();

    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && !_graded) {
        _reload(silent: true);
      }
    });
  }

  Future<Map<String, dynamic>> _fetchResult() async {
    _requestInFlight = true;

    try {
      final data = await ref
          .read(studentPortalRepositoryProvider)
          .assignmentResult(widget.assignmentUuid);

      _graded = data['status']?.toString().toUpperCase() == 'GRADED';

      if (_graded) {
        _pollTimer?.cancel();
      }

      return data;
    } finally {
      _requestInFlight = false;
    }
  }

  Future<void> _reload({required bool silent}) async {
    if (!mounted || _requestInFlight) return;

    final next = _fetchResult();

    if (!silent) {
      setState(() => _result = next);
    }

    try {
      final data = await next;

      if (silent && mounted) {
        setState(() => _result = Future.value(data));
      }
    } catch (_) {
      // Manual refresh displays the error through FutureBuilder.
      // A background refresh keeps the current result visible.
    }
  }

  Future<void> _refresh() => _reload(silent: false);

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _result,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 100),
                Center(
                  child: CircularProgressIndicator(),
                ),
              ],
            );
          }

          if (snapshot.hasError) {
            return StudentPageFrame(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(kStudentPagePadding),
                children: [
                  StudentStateMessage(
                    icon: Icons.wifi_off_rounded,
                    title: 'Result could not load',
                    message: '${snapshot.error}',
                    actionLabel: 'Try again',
                    onAction: _refresh,
                    isError: true,
                  ),
                ],
              ),
            );
          }

          final result = snapshot.data!;

          final graded =
              result['status']?.toString().toUpperCase() == 'GRADED';

          final percentage = (num.tryParse(
                    result['percentage']?.toString() ?? '',
                  ) ??
                  0)
              .toDouble()
              .clamp(0.0, 100.0)
              .toDouble();

          final feedback = result['feedback']?.toString() ?? '';

          return StudentPageFrame(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                kStudentPagePadding,
                4,
                kStudentPagePadding,
                28,
              ),
              children: [
                if (!graded) ...[
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.borderSubtle),
                      boxShadow: colors.cardShadow,
                    ),
                    child: Column(
                      children: [
                        IconTile(
                          icon: Icons.hourglass_top_rounded,
                          size: 64,
                          radius: 32,
                          background: colors.warningBg,
                          foreground: colors.warning,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Submission received',
                          style: textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Your result is not available yet. '
                          'Check again after the academy '
                          'completes grading.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primaryTonal,
                            foregroundColor: colors.primaryDeep,
                          ),
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Check result again'),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: colors.heroGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: colors.heroShadow,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 96,
                          height: 96,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: percentage / 100,
                                strokeWidth: 9,
                                strokeCap: StrokeCap.round,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.2),
                                color: Colors.white,
                              ),
                              Center(
                                child: Text(
                                  '${percentage.toStringAsFixed(0)}%',
                                  style: textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your score',
                                style: textTheme.labelMedium?.copyWith(
                                  color: const Color(0xFFDAD7FF),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${result['marks_obtained'] ?? 0}'
                                ' / '
                                '${result['max_marks'] ?? 0}',
                                style: textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'marks obtained',
                                style: textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFFDAD7FF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: PremiumCard(
                          margin: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IconTile(
                                icon: Icons.check_circle_outline_rounded,
                                size: 38,
                                background: colors.successBg,
                                foreground: colors.success,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${result['correct_answers'] ?? 0}',
                                style: textTheme.headlineSmall?.copyWith(
                                  color: colors.success,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Correct MCQ answers',
                                style: textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PremiumCard(
                          margin: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IconTile(
                                icon: Icons.cancel_outlined,
                                size: 38,
                                background: colors.dangerBg,
                                foreground: colors.danger,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${result['wrong_answers'] ?? 0}',
                                style: textTheme.headlineSmall?.copyWith(
                                  color: colors.danger,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Wrong MCQ answers',
                                style: textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (feedback.isNotEmpty) ...[
                    const SectionHeader(
                      title: 'Teacher feedback',
                      icon: Icons.rate_review_outlined,
                    ),
                    PremiumCard(
                      child: Text(
                        feedback,
                        style: textTheme.bodyLarge?.copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
