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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
              style: FilledButton.styleFrom(
                backgroundColor: _PremiumPalette.brand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
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
    return FutureBuilder<Map<String, dynamic>>(
      future: _assignment,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(
              color: _PremiumPalette.brand,
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(
            message: '${snapshot.error}',
            onRetry: () {
              setState(() {
                _assignment = ref
                    .read(studentPortalRepositoryProvider)
                    .assignment(widget.assignmentUuid);
              });
            },
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: _PremiumPalette.brand,
            ),
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

        final title = assignment['title']?.toString() ?? 'Assignment';

        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: _PremiumPalette.brand,
                onRefresh: () async {
                  setState(() {
                    _assignment = ref
                        .read(studentPortalRepositoryProvider)
                        .assignment(widget.assignmentUuid);
                  });
                  try {
                    await _assignment;
                  } catch (_) {}
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    // Hero
                    _buildHeroCard(
                      title: title,
                      dueAt: dueAt,
                      deadlinePassed: deadlinePassed,
                      maxMarks: maxMarks,
                      questionsCount: questions.length,
                    ),
                    const SizedBox(height: 20),

                    // Instructions banner
                    if (instructions.isNotEmpty || lateAllowed)
                      _buildInstructionsBanner(
                        instructions: instructions,
                        lateAllowed: lateAllowed,
                        alreadySubmitted: alreadySubmitted,
                      ),

                    // Submitted or questions
                    if (alreadySubmitted) ...[
                      _buildSubmittedState(),
                    ] else ...[
                      _buildYourWorkHeader(questions.length),
                      const SizedBox(height: 12),
                      if (questions.isEmpty)
                        _buildEmptyQuestions()
                      else
                        for (var index = 0;
                        index < questions.length;
                        index++)
                          _buildQuestionCard(
                            Map<String, dynamic>.from(
                              questions[index] as Map,
                            ),
                            index + 1,
                            disabled:
                            alreadySubmitted || deadlinePassed,
                          ),
                      if (deadlinePassed) ...[
                        const SizedBox(height: 12),
                        _buildDeadlineAlert(),
                      ],
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Submit bar
            if (!alreadySubmitted)
              _buildSubmitBar(
                questions: questions,
                disabled: deadlinePassed,
              ),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ERROR STATE
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildErrorState({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _PremiumPalette.dangerSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 32,
                color: _PremiumPalette.danger,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Assignment could not load',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _PremiumPalette.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: _PremiumPalette.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _PremiumPalette.brand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HERO CARD
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildHeroCard({
    required String title,
    required DateTime? dueAt,
    required bool deadlinePassed,
    required String maxMarks,
    required int questionsCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _PremiumPalette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _PremiumPalette.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: _PremiumPalette.brand.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dueAt != null)
            _buildDuePill(
              label: _dueLabel(dueAt),
              isOverdue: deadlinePassed,
            )
          else
            _buildPill(
              icon: Icons.all_inclusive_rounded,
              label: 'No due date',
              bg: _PremiumPalette.surfaceMuted,
              fg: _PremiumPalette.textSecondary,
              border: _PremiumPalette.border,
            ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.25,
              color: _PremiumPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: _PremiumPalette.borderSubtle),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.star_outline_rounded,
                size: 18,
                color: _PremiumPalette.brand,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Total: '),
                      TextSpan(
                        text: maxMarks.isEmpty ? '—' : '$maxMarks marks',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _PremiumPalette.textPrimary,
                        ),
                      ),
                      TextSpan(
                        text: ' · $questionsCount '
                            '${questionsCount == 1 ? 'question' : 'questions'}',
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    color: _PremiumPalette.textSecondary,
                  ),
                ),
              ),
              _buildActivePill(deadlinePassed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDuePill({
    required String label,
    required bool isOverdue,
  }) {
    final bg = isOverdue
        ? _PremiumPalette.dangerSoft
        : _PremiumPalette.warningSoft;
    final fg = isOverdue
        ? _PremiumPalette.danger
        : _PremiumPalette.warning;
    final border = isOverdue
        ? _PremiumPalette.dangerBorder
        : _PremiumPalette.warningBorder;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_rounded, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePill(bool deadlinePassed) {
    if (deadlinePassed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _PremiumPalette.dangerSoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _PremiumPalette.dangerBorder),
        ),
        child: const Text(
          'Closed',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: _PremiumPalette.danger,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _PremiumPalette.successSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _PremiumPalette.successBorder),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded,
              size: 12, color: _PremiumPalette.success),
          SizedBox(width: 5),
          Text(
            'Active',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: _PremiumPalette.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // INSTRUCTIONS BANNER
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildInstructionsBanner({
    required String instructions,
    required bool lateAllowed,
    required bool alreadySubmitted,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _PremiumPalette.brandSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _PremiumPalette.brand.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  size: 18,
                  color: _PremiumPalette.brand,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  alreadySubmitted ? 'Instructions' : 'Pending submission',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _PremiumPalette.textPrimary,
                  ),
                ),
              ),
              if (!alreadySubmitted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _PremiumPalette.warningSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Not turned in',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _PremiumPalette.warning,
                    ),
                  ),
                ),
            ],
          ),
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              instructions,
              style: const TextStyle(
                fontSize: 13,
                height: 1.55,
                color: _PremiumPalette.textSecondary,
              ),
            ),
          ],
          if (lateAllowed) ...[
            const SizedBox(height: 10),
            const Text(
              'The due date has passed, but late submissions are allowed.',
              style: TextStyle(
                fontSize: 12,
                color: _PremiumPalette.warning,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // YOUR WORK HEADER
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildYourWorkHeader(int count) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _PremiumPalette.brandSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.edit_note_rounded,
            size: 18,
            color: _PremiumPalette.brand,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'Your work',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: _PremiumPalette.textPrimary,
          ),
        ),
        const Spacer(),
        Text(
          '$count ${count == 1 ? 'question' : 'questions'}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _PremiumPalette.textMuted,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SUBMITTED STATE
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildSubmittedState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _PremiumPalette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _PremiumPalette.borderSubtle),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _PremiumPalette.successSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              size: 32,
              color: _PremiumPalette.success,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Work turned in',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _PremiumPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your answers were submitted. Check your marks and feedback.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _PremiumPalette.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _PremiumPalette.brand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => context.go(
                '/student/assignments/${widget.assignmentUuid}/result',
              ),
              child: const Text(
                'View result',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // EMPTY QUESTIONS
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildEmptyQuestions() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _PremiumPalette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _PremiumPalette.borderSubtle),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _PremiumPalette.brandSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.help_outline_rounded,
              size: 28,
              color: _PremiumPalette.brand,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No questions yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _PremiumPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'This assignment has no questions to answer.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _PremiumPalette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DEADLINE ALERT
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildDeadlineAlert() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _PremiumPalette.dangerSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _PremiumPalette.dangerBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_clock_outlined,
            size: 20,
            color: _PremiumPalette.danger,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'The submission deadline has passed.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _PremiumPalette.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // QUESTION CARD
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildQuestionCard(
      Map<String, dynamic> question,
      int number, {
        bool disabled = false,
      }) {
    final uuid = question['uuid']?.toString() ?? '';
    final type =
        question['answer_type']?.toString().toUpperCase() ?? '';
    final required = question['is_required'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _PremiumPalette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _PremiumPalette.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _PremiumPalette.brand,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: _PremiumPalette.brand.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                    color: _PremiumPalette.textSecondary,
                  ),
                ),
              ),
              if (required)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _PremiumPalette.dangerSoft,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _PremiumPalette.dangerBorder,
                    ),
                  ),
                  child: const Text(
                    'Required',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: _PremiumPalette.danger,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            question['question_text']?.toString() ?? '',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: _PremiumPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
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
                    if (_submitting || _uploading || disabled) return;
                    setState(() => _mcqAnswers[uuid] = option);
                  },
                ),
          ] else if (type == 'TEXT') ...[
            TextField(
              enabled: !_submitting && !_uploading && !disabled,
              controller: _textControllers.putIfAbsent(
                uuid,
                TextEditingController.new,
              ),
              maxLines: 4,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: _PremiumPalette.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Write your answer here…',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: _PremiumPalette.textMuted,
                ),
                filled: true,
                fillColor: _PremiumPalette.surfaceMuted,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: _PremiumPalette.border,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: _PremiumPalette.border,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: _PremiumPalette.brand,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ] else if (type == 'FILE') ...[
            const Text(
              'PDF, DOC, DOCX, JPG, JPEG or PNG. Maximum 25 MB.',
              style: TextStyle(
                fontSize: 12,
                color: _PremiumPalette.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            if (_fileNames[uuid] != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _PremiumPalette.successSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: _PremiumPalette.success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Uploaded: ${_fileNames[uuid]}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _PremiumPalette.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_uploadQuestion == uuid) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: _uploadProgress,
                  minHeight: 6,
                  backgroundColor: _PremiumPalette.brandSoft,
                  color: _PremiumPalette.brand,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Selecting or uploading file...',
                style: TextStyle(
                  fontSize: 12,
                  color: _PremiumPalette.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _PremiumPalette.brand,
                  side: const BorderSide(color: _PremiumPalette.brand),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _submitting || _uploading || disabled
                    ? null
                    : () => _uploadFile(uuid),
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: Text(
                  _fileAnswers[uuid] == null
                      ? 'Choose and upload'
                      : 'Replace file',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (_fileAnswers[uuid] != null)
              TextButton(
                onPressed: _submitting || _uploading || disabled
                    ? null
                    : () => setState(() {
                  _fileAnswers.remove(uuid);
                  _fileNames.remove(uuid);
                }),
                child: const Text(
                  'Remove from answer',
                  style: TextStyle(fontSize: 12),
                ),
              ),
          ] else ...[
            const Text(
              'Unsupported question type.',
              style: TextStyle(
                fontSize: 12,
                color: _PremiumPalette.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SUBMIT BAR
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildSubmitBar({
    required List<dynamic> questions,
    required bool disabled,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _PremiumPalette.surface,
        border: Border(
          top: BorderSide(color: _PremiumPalette.borderSubtle),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: disabled
                    ? _PremiumPalette.textMuted
                    : _PremiumPalette.brand,
                disabledBackgroundColor:
                _PremiumPalette.textMuted.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
                shadowColor: _PremiumPalette.brand.withValues(alpha: 0.3),
              ),
              onPressed: _submitting || _uploading || disabled
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
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _submitting ? 'Submitting...' : 'Submit assignment',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// OPTION TILE
// ═══════════════════════════════════════════════════════════════════════════
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? _PremiumPalette.brandSoft
            : _PremiumPalette.surfaceMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected
                ? _PremiumPalette.brand
                : _PremiumPalette.border,
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
                        ? _PremiumPalette.brand
                        : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? _PremiumPalette.brand
                          : _PremiumPalette.border,
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
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _PremiumPalette.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: selected
                          ? _PremiumPalette.brandDeep
                          : _PremiumPalette.textPrimary,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
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

// ═══════════════════════════════════════════════════════════════════════════
// RESULT SCREEN (unchanged)
// ═══════════════════════════════════════════════════════════════════════════
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
    } catch (_) {}
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
      color: _PremiumPalette.brand,
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
                  child: CircularProgressIndicator(
                    color: _PremiumPalette.brand,
                  ),
                ),
              ],
            );
          }

          if (snapshot.hasError) {
            return ListView(
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

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              if (!graded) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _PremiumPalette.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _PremiumPalette.borderSubtle,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: _PremiumPalette.warningSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.hourglass_top_rounded,
                          size: 32,
                          color: _PremiumPalette.warning,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Submission received',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _PremiumPalette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Your result is not available yet. '
                            'Check again after the academy completes grading.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: _PremiumPalette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _PremiumPalette.brandSoft,
                          foregroundColor: _PremiumPalette.brandDeep,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text(
                          'Check result again',
                          style: TextStyle(fontWeight: FontWeight.w700),
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
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
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
                      child: _buildResultStatCard(
                        icon: Icons.check_circle_outline_rounded,
                        value: '${result['correct_answers'] ?? 0}',
                        label: 'Correct MCQ answers',
                        color: _PremiumPalette.success,
                        bgColor: _PremiumPalette.successSoft,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildResultStatCard(
                        icon: Icons.cancel_outlined,
                        value: '${result['wrong_answers'] ?? 0}',
                        label: 'Wrong MCQ answers',
                        color: _PremiumPalette.danger,
                        bgColor: _PremiumPalette.dangerSoft,
                      ),
                    ),
                  ],
                ),
                if (feedback.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Teacher feedback',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _PremiumPalette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _PremiumPalette.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _PremiumPalette.borderSubtle,
                      ),
                    ),
                    child: Text(
                      feedback,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.55,
                        color: _PremiumPalette.textPrimary,
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

  Widget _buildResultStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _PremiumPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _PremiumPalette.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: _PremiumPalette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}