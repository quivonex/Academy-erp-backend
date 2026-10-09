import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../data/assignment_file_upload_repository.dart';
import '../data/student_portal_repository.dart';
import 'widgets/student_ui.dart';

const _dueDays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const _dueMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _dueLabel(DateTime due) {
  final local = due.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');

  return 'Due ${_dueDays[local.weekday - 1]}, '
      '${_dueMonths[local.month - 1]} ${local.day} · '
      '$hour:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
}

<<<<<<< HEAD
// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM COLORS
// ═══════════════════════════════════════════════════════════════════════════
class _PremiumPalette {
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const borderSubtle = Color(0xFFF1F5F9);

  static const brand = Color(0xFF4338CA);
  static const brandDeep = Color(0xFF3730A3);
  static const brandSoft = Color(0xFFEEF2FF);

  static const warning = Color(0xFFD97706);
  static const warningSoft = Color(0xFFFFFBEB);
  static const warningBorder = Color(0xFFFDE68A);

  static const success = Color(0xFF059669);
  static const successSoft = Color(0xFFECFDF5);
  static const successBorder = Color(0xFFA7F3D0);

  static const danger = Color(0xFFDC2626);
  static const dangerSoft = Color(0xFFFEF2F2);
  static const dangerBorder = Color(0xFFFECACA);

  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textMuted = Color(0xFF94A3B8);
}

=======
>>>>>>> b38ee07af57210a3a2703edb3ef4d9ebe37879b1
class StudentAssignmentScreen extends ConsumerStatefulWidget {
  const StudentAssignmentScreen({
    super.key,
    required this.assignmentUuid,
  });

  final String assignmentUuid;

  @override
  ConsumerState<StudentAssignmentScreen> createState() =>
      _StudentAssignmentScreenState();
}

class _StudentAssignmentScreenState
    extends ConsumerState<StudentAssignmentScreen> {
  late Future<Map<String, dynamic>> _assignment;

  final Map<String, String> _mcqAnswers = {};
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, String> _fileAnswers = {};
  final Map<String, String> _fileNames = {};

  bool _submitting = false;
  bool _uploading = false;
  String? _uploadQuestion;
  double? _uploadProgress;

  @override
  void initState() {
    super.initState();

    _assignment = ref
        .read(studentPortalRepositoryProvider)
        .assignment(widget.assignmentUuid);
  }

  @override
  void didUpdateWidget(covariant StudentAssignmentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.assignmentUuid == widget.assignmentUuid) return;

    for (final controller in _textControllers.values) {
      controller.dispose();
    }

    _textControllers.clear();
    _mcqAnswers.clear();
    _fileAnswers.clear();
    _fileNames.clear();

    _uploading = false;
    _submitting = false;
    _uploadQuestion = null;
    _uploadProgress = null;

    _assignment = ref
        .read(studentPortalRepositoryProvider)
        .assignment(widget.assignmentUuid);
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> _uploadFile(String questionUuid) async {
    if (_submitting || _uploading) return;

    final assignmentUuid = widget.assignmentUuid;

    setState(() {
      _uploading = true;
      _uploadQuestion = questionUuid;
      _uploadProgress = null;
    });

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'jpg',
          'jpeg',
          'png',
        ],
        allowMultiple: false,
        withData: true,
      );

      if (!mounted || widget.assignmentUuid != assignmentUuid) {
        return;
      }

      if (picked == null) return;

      final file = picked.files.single;
      final bytes = file.bytes;

      if (bytes == null ||
          bytes.isEmpty ||
          file.size > 25 * 1024 * 1024) {
        throw const ApiException(
          'Choose a non-empty file up to 25 MB.',
        );
      }

      final key = await ref
          .read(assignmentFileUploadRepositoryProvider)
          .upload(
            assignmentUuid: assignmentUuid,
            questionUuid: questionUuid,
            fileName: file.name,
            bytes: bytes,
            onProgress: (sent, total) {
              if (mounted &&
                  widget.assignmentUuid == assignmentUuid) {
                setState(() {
                  _uploadProgress = total > 0 ? sent / total : null;
                });
              }
            },
          );

      if (!mounted || widget.assignmentUuid != assignmentUuid) {
        return;
      }

      setState(() {
        _fileAnswers[questionUuid] = key;
        _fileNames[questionUuid] = file.name;
      });
    } on ApiException catch (e) {
      if (mounted && widget.assignmentUuid == assignmentUuid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted && widget.assignmentUuid == assignmentUuid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not upload file. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted && widget.assignmentUuid == assignmentUuid) {
        setState(() {
          _uploading = false;
          _uploadQuestion = null;
          _uploadProgress = null;
        });
      }
    }
  }

  Future<void> _submit(List<dynamic> questions) async {
    if (_submitting || _uploading) return;

    final assignmentUuid = widget.assignmentUuid;
    final answers = <Map<String, dynamic>>[];

    for (final raw in questions) {
      final question = Map<String, dynamic>.from(raw as Map);

      final uuid = question['uuid']?.toString() ?? '';
      if (uuid.isEmpty) continue;

      final type =
          question['answer_type']?.toString().toUpperCase() ?? '';

      final required = question['is_required'] == true;

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
        final text = _textControllers[uuid]?.text.trim() ?? '';

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
      } else if (type == 'FILE') {
        final key = _fileAnswers[uuid];

        if ((key == null || key.isEmpty) && required) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upload all required file answers.'),
            ),
          );
          return;
        }

        if (key != null && key.isNotEmpty) {
          answers.add({
            'question_uuid': uuid,
            'file_key': key,
          });
        }
      }
    }

    if (answers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Answer at least one question.'),
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

      if (!mounted ||
          widget.assignmentUuid != assignmentUuid ||
          confirmed != true) {
        return;
      }

      await ref
          .read(studentPortalRepositoryProvider)
          .submitAssignment(
            assignmentUuid: assignmentUuid,
            answers: answers,
          );

      if (!mounted || widget.assignmentUuid != assignmentUuid) {
        return;
      }

      context.go(
        '/student/assignments/$assignmentUuid/result',
      );
    } catch (error) {
      if (!mounted || widget.assignmentUuid != assignmentUuid) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted && widget.assignmentUuid == assignmentUuid) {
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
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

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

        final maxMarks =
            assignment['max_marks']?.toString() ?? '';

        final instructions =
            assignment['instructions']?.toString().trim() ?? '';

        final courseName =
            assignment['course_name']?.toString() ?? '';

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
                      assignment['title']?.toString() ??
                          'Assignment',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Divider(
                      height: 1,
                      color: colors.borderSubtle,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.star_outline_rounded,
                          size: 20,
                          color: colors.primary,
                        ),
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
              if (instructions.isNotEmpty || lateAllowed)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F3FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.primaryTonalBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 20,
                            color: colors.primary,
                          ),
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
                    message:
                        'This assignment has no questions to answer.',
                  ),
                for (var index = 0;
                    index < questions.length;
                    index++)
                  _questionCard(
                    Map<String, dynamic>.from(
                      questions[index] as Map,
                    ),
                    index + 1,
                    disabled:
                        alreadySubmitted || deadlinePassed,
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
                        Icon(
                          Icons.lock_clock_outlined,
                          color: colors.danger,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'The submission deadline has passed.',
                            style:
                                textTheme.bodyMedium?.copyWith(
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
                border: Border(
                  top: BorderSide(
                    color: colors.borderSubtle,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: kStudentMaxWidth,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _submitting ||
                                  _uploading ||
                                  deadlinePassed
                              ? null
                              : () => _submit(questions),
                          icon: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                ),
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

  Widget _questionCard(
    Map<String, dynamic> question,
    int number, {
    bool disabled = false,
  }) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    final uuid = question['uuid']?.toString() ?? '';

    final type =
        question['answer_type']?.toString().toUpperCase() ?? '';

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
                  style: textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                  ),
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
                  text:
                      '${question['option_${option.toLowerCase()}']}',
                  selected: _mcqAnswers[uuid] == option,
                  onTap: () {
                    if (_submitting ||
                        _uploading ||
                        disabled) {
                      return;
                    }
                    setState(() {
                      _mcqAnswers[uuid] = option;
                    });
                  },
                ),
          ] else if (type == 'TEXT') ...[
            TextField(
              enabled:
                  !_submitting && !_uploading && !disabled,
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
                  borderSide: BorderSide(
                    color: colors.borderSubtle,
                  ),
                ),
              ),
            ),
          ] else if (type == 'FILE') ...[
            const Text(
              'PDF, DOC, DOCX, JPG, JPEG or PNG. Maximum 25 MB.',
            ),
            const SizedBox(height: 8),
            if (_fileNames[uuid] != null) ...[
              Text('Uploaded: ${_fileNames[uuid]}'),
              const Text(
                'Ready to include when you submit the assignment.',
              ),
              const SizedBox(height: 8),
            ],
            if (_uploadQuestion == uuid) ...[
              LinearProgressIndicator(
                value: _uploadProgress,
              ),
              const SizedBox(height: 8),
              const Text('Selecting or uploading file...'),
            ],
            OutlinedButton.icon(
              onPressed:
                  _submitting || _uploading || disabled
                      ? null
                      : () => _uploadFile(uuid),
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(
                _fileAnswers[uuid] == null
                    ? 'Choose and upload'
                    : 'Replace file',
              ),
            ),
            if (_fileAnswers[uuid] != null)
              TextButton(
                onPressed:
                    _submitting || _uploading || disabled
                        ? null
                        : () => setState(() {
                              _fileAnswers.remove(uuid);
                              _fileNames.remove(uuid);
                            }),
                child: const Text('Remove from answer'),
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
        color: selected
            ? colors.primaryTonal
            : const Color(0xFFF7F7FE),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected
                ? colors.primary
                : colors.borderSubtle,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? colors.primary
                        : colors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? colors.primary
                          : colors.borderSubtle,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
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
                      color: selected
                          ? colors.primaryDeep
                          : colors.textPrimary,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.w400,
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
  ConsumerState<StudentAssignmentResultScreen> createState() =>
      _StudentAssignmentResultScreenState();
}

class _StudentAssignmentResultScreenState
    extends ConsumerState<StudentAssignmentResultScreen> {
  late Future<Map<String, dynamic>> _result;

  Timer? _pollTimer;

  bool _requestInFlight = false;
  bool _graded = false;

  int _resultRevision = 0;

  @override
  void initState() {
    super.initState();
    _resetResult();
  }

  @override
  void didUpdateWidget(
    covariant StudentAssignmentResultScreen oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.assignmentUuid != widget.assignmentUuid) {
      _resetResult();
    }
  }

  void _resetResult() {
    _pollTimer?.cancel();

    _resultRevision++;
    _requestInFlight = false;
    _graded = false;

    _result = _fetchResult();

    _pollTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) {
        if (mounted && !_graded && !_requestInFlight) {
          _reload(silent: true);
        }
      },
    );
  }

  Future<Map<String, dynamic>> _fetchResult() async {
    final revision = _resultRevision;
    final assignmentUuid = widget.assignmentUuid;

    bool current() =>
        mounted &&
        revision == _resultRevision &&
        assignmentUuid == widget.assignmentUuid;

    _requestInFlight = true;

    try {
      final data = await ref
          .read(studentPortalRepositoryProvider)
          .assignmentResult(assignmentUuid);

      if (current()) {
        _graded =
            data['status']?.toString().toUpperCase() == 'GRADED';

        if (_graded) {
          _pollTimer?.cancel();
        }
      }

      return data;
    } finally {
      if (current()) {
        _requestInFlight = false;
      }
    }
  }

  Future<void> _reload({
    required bool silent,
  }) async {
    if (!mounted || _requestInFlight) return;

    final revision = _resultRevision;
    final assignmentUuid = widget.assignmentUuid;

    bool current() =>
        mounted &&
        revision == _resultRevision &&
        assignmentUuid == widget.assignmentUuid;

    final next = _fetchResult();

    if (!silent) {
      setState(() => _result = next);
    }

    try {
      final data = await next;

      if (silent && current()) {
        setState(() {
          _result = Future.value(data);
        });
      }
    } catch (_) {
      // Manual refresh errors appear in FutureBuilder.
      // Background refresh keeps the current result visible.
    }
  }

  Future<void> _refresh() => _reload(silent: false);

  @override
  void dispose() {
    _resultRevision++;
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
        key: ValueKey(widget.assignmentUuid),
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
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.all(kStudentPagePadding),
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
              result['status']?.toString().toUpperCase() ==
                  'GRADED';

          final percentage = (num.tryParse(
                    result['percentage']?.toString() ?? '',
                  ) ??
                  0)
              .toDouble()
              .clamp(0.0, 100.0)
              .toDouble();

          final feedback =
              result['feedback']?.toString() ?? '';

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
                      border: Border.all(
                        color: colors.borderSubtle,
                      ),
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
                            backgroundColor:
                                colors.primaryTonal,
                            foregroundColor:
                                colors.primaryDeep,
                          ),
                          onPressed: _refresh,
                          icon: const Icon(
                            Icons.refresh_rounded,
                          ),
                          label: const Text(
                            'Check result again',
                          ),
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
                                    Colors.white.withValues(
                                  alpha: 0.2,
                                ),
                                color: Colors.white,
                              ),
                              Center(
                                child: Text(
                                  '${percentage.toStringAsFixed(0)}%',
                                  style:
                                      textTheme.titleLarge?.copyWith(
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
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your score',
                                style:
                                    textTheme.labelMedium?.copyWith(
                                  color: const Color(0xFFDAD7FF),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${result['marks_obtained'] ?? 0}'
                                ' / '
                                '${result['max_marks'] ?? 0}',
                                style: textTheme.headlineMedium
                                    ?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'marks obtained',
                                style:
                                    textTheme.bodySmall?.copyWith(
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
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              IconTile(
                                icon:
                                    Icons.check_circle_outline_rounded,
                                size: 38,
                                background: colors.successBg,
                                foreground: colors.success,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${result['correct_answers'] ?? 0}',
                                style: textTheme.headlineSmall
                                    ?.copyWith(
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
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
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
                                style: textTheme.headlineSmall
                                    ?.copyWith(
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
                        style: textTheme.bodyLarge?.copyWith(
                          height: 1.5,
                        ),
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
