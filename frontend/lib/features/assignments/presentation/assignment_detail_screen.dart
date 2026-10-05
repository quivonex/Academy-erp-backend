import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';
import '../data/assignment.dart';
import '../data/assignment_question.dart';
import '../data/assignment_repository.dart';
import 'assignment_edit_screen.dart';

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

class _Detail {
  const _Detail(this.assignment, this.questions);

  final Assignment assignment;
  final List<AssignmentQuestion> questions;

  int get totalCents => questions.fold(
    0,
        (sum, q) => sum + (q.marks * 100).round(),
  );

  bool get marksMatch =>
      totalCents == (assignment.maxMarks * 100).round();
}

class _AssignmentDetailScreenState
    extends ConsumerState<AssignmentDetailScreen> {
  late Future<_Detail> result;
  bool busy = false;
  int revision = 0;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(covariant AssignmentDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.assignmentUuid != widget.assignmentUuid) {
      revision++;
      busy = false;
      reload();
    }
  }

  Future<_Detail> fetch(String uuid) async {
    final repository = ref.read(assignmentRepositoryProvider);

    final values = await Future.wait<dynamic>([
      repository.detail(uuid),
      repository.questions(uuid),
    ]);

    return _Detail(
      values[0] as Assignment,
      values[1] as List<AssignmentQuestion>,
    );
  }

  void reload() => result = fetch(widget.assignmentUuid);

  void refresh() {
    if (!busy) setState(reload);
  }

  void back() {
    if (busy) return;

    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/assignments');
    }
  }

  void notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> editAssignment(_Detail data) async {
    if (busy) return;

    final ticket = revision;

    await run(
      () async {
        final updated = await showDialog<Assignment>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AssignmentEditScreen(
            assignment: data.assignment,
          ),
        );

        return mounted &&
            ticket == revision &&
            updated != null;
      },
      'Assignment updated successfully.',
    );
  }

  Future<void> deleteAssignment(_Detail data) async {
    if (busy) return;

    final ticket = revision;
    final uuid = data.assignment.uuid;
    final router = GoRouter.of(context);

    bool current() =>
        mounted &&
        ticket == revision &&
        widget.assignmentUuid == uuid;

    setState(() => busy = true);

    try {
      var resolved = false;

      void closeDialog(
        BuildContext dialogContext,
        bool value,
      ) {
        if (resolved) return;
        resolved = true;
        Navigator.of(dialogContext).pop(value);
      }

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            Icons.delete_outline_rounded,
            size: 40,
            color: Theme.of(dialogContext).colorScheme.error,
          ),
          title: const Text('Delete assignment?'),
          content: Text(
            'Delete "${data.assignment.title}" '
            'and all its questions?\n\n'
            'This cannot be undone. Assignments with '
            'student submissions cannot be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                closeDialog(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    Theme.of(dialogContext).colorScheme.error,
                foregroundColor:
                    Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () {
                closeDialog(dialogContext, true);
              },
              child: const Text('Delete assignment'),
            ),
          ],
        ),
      );

      if (!current() || confirmed != true) return;

      await ref
          .read(assignmentRepositoryProvider)
          .deleteAssignment(uuid);

      if (!current()) return;

      setState(() => busy = false);

      notify('Assignment deleted successfully.');
      router.go('/assignments');
    } on ApiException catch (error) {
      if (current()) {
        notify(error.message);
      }
    } catch (_) {
      if (current()) {
        notify(
          'Could not confirm deletion. '
          'Refresh the assignment list to check its status.',
        );
      }
    } finally {
      if (current()) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> run(
      Future<bool> Function() action,
      String message, {
        bool reloadAfter = true,
      }) async {
    if (busy) return;

    final ticket = revision;
    setState(() => busy = true);

    try {
      final changed = await action();

      if (!mounted || ticket != revision) return;

      if (changed) {
        if (reloadAfter) setState(reload);
        if (message.isNotEmpty) notify(message);
      }
    } on ApiException catch (e) {
      if (mounted && ticket == revision) {
        notify(e.message);
        setState(reload);
      }
    } catch (_) {
      if (mounted && ticket == revision) {
        notify('Could not complete this action. Please retry.');
        setState(reload);
      }
    } finally {
      if (mounted && ticket == revision) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> questionDialog(
      _Detail data, [
        AssignmentQuestion? question,
      ]) async {
    if (busy || data.assignment.isPublished) return;

    final lastSequence = data.questions.fold<int>(
      0,
          (value, q) => q.sequence > value ? q.sequence : value,
    );

    await run(
          () async {
        return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _QuestionDialog(
            assignmentUuid: data.assignment.uuid,
            question: question,
            initialSequence: lastSequence < 2147483647
                ? lastSequence + 1
                : lastSequence,
          ),
        ) ==
            true;
      },
      question == null
          ? 'Question added successfully.'
          : 'Question updated successfully.',
    );
  }

  Future<void> deleteQuestion(
      _Detail data,
      AssignmentQuestion question,
      ) async {
    if (busy || data.assignment.isPublished) return;

    final ticket = revision;

    await run(
          () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete question?'),
            content: const Text(
              'This permanently removes the question. '
                  'This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );

        if (!mounted ||
            ticket != revision ||
            confirmed != true) {
          return false;
        }

        await ref.read(assignmentRepositoryProvider).deleteQuestion(
          assignmentUuid: data.assignment.uuid,
          questionUuid: question.uuid,
        );

        return true;
      },
      'Question deleted successfully.',
    );
  }

  Future<void> togglePublish(_Detail data) async {
    if (busy) return;

    final a = data.assignment;

    if (!a.isPublished &&
        (!a.isActive ||
            data.questions.isEmpty ||
            !data.marksMatch)) {
      return;
    }

    final ticket = revision;

    await run(
          () async {
        if (a.isPublished) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Unpublish assignment?'),
              content: const Text(
                'The assignment will return to draft. '
                    'Assignments with student submissions '
                    'cannot be unpublished.',
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(true),
                  child: const Text('Unpublish'),
                ),
              ],
            ),
          );

          if (!mounted ||
              ticket != revision ||
              confirmed != true) {
            return false;
          }
        }

        final repository = ref.read(assignmentRepositoryProvider);

        final updated = a.isPublished
            ? await repository.unpublish(a.uuid)
            : await repository.publish(a.uuid);

        if (mounted && ticket == revision) {
          setState(() {
            result = Future.value(
              _Detail(updated, data.questions),
            );
          });
        }

        return true;
      },
      a.isPublished
          ? 'Assignment unpublished successfully.'
          : 'Assignment published successfully.',
      reloadAfter: false,
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: busy ? null : back,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Assignments'),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<_Detail>(
          future: result,
          builder: (context, snapshot) {
            final state = adminFutureState(
              snapshot,
              noun: 'assignment',
              onRetry: refresh,
            );

            if (state != null) return state;

            final data = snapshot.data!;
            final a = data.assignment;

            final canPublish = a.isPublished ||
                (a.isActive &&
                    data.questions.isNotEmpty &&
                    data.marksMatch);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminPageHeader(
                  title: a.title,
                  subtitle: a.courseName,
                  titleTrailing: [
                    ActiveBadge(
                      active: a.isPublished,
                      activeLabel: 'Published',
                      inactiveLabel: 'Draft',
                    ),
                    ActiveBadge(active: a.isActive),
                    IconButton(
                      onPressed: busy ? null : refresh,
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                  actions: [
                    AdminOutlineButton(
                      label: 'Edit Assignment',
                      icon: Icons.edit_outlined,
                      onPressed: busy
                          ? null
                          : () => editAssignment(data),
                    ),
                    AdminOutlineButton(
                      label: 'Delete Assignment',
                      icon: Icons.delete_outline_rounded,
                      danger: true,
                      onPressed: busy
                          ? null
                          : () => deleteAssignment(data),
                    ),
                    if (!a.isPublished)
                      GradientButton(
                        label: 'Add Question',
                        icon: Icons.add,
                        onPressed: busy
                            ? null
                            : () => questionDialog(data),
                      ),
                    AdminOutlineButton(
                      label: a.isPublished
                          ? 'Unpublish'
                          : 'Publish',
                      icon: a.isPublished
                          ? Icons.visibility_off_outlined
                          : Icons.publish_outlined,
                      onPressed: busy || !canPublish
                          ? null
                          : () => togglePublish(data),
                    ),
                    AdminOutlineButton(
                      label: 'View Submissions',
                      icon: Icons.fact_check_outlined,
                      onPressed: busy
                          ? null
                          : () => run(
                            () async {
                          await context.push(
                            '/assignments/${a.uuid}/submissions',
                          );
                          return true;
                        },
                        '',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assignment information',
                        style:
                        Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _InfoRow(
                        label: 'Course',
                        value: a.courseName,
                      ),
                      _InfoRow(
                        label: 'Subject',
                        value: a.subjectName,
                      ),
                      _InfoRow(
                        label: 'Chapter',
                        value: a.chapterTitle,
                      ),
                      _InfoRow(
                        label: 'Lesson',
                        value: a.lessonTitle,
                      ),
                      _InfoRow(
                        label: 'Maximum marks',
                        value: _marks(a.maxMarks),
                      ),
                      _InfoRow(
                        label: 'Question marks',
                        value: _marks(data.totalCents / 100),
                      ),
                      _InfoRow(
                        label: 'Due date',
                        value: _date(a.dueAt),
                      ),
                      _InfoRow(
                        label: 'Late submissions',
                        value: a.allowLateSubmission
                            ? 'Allowed'
                            : 'Not allowed',
                      ),
                      _InfoRow(
                        label: 'Created by',
                        value: a.createdByName,
                      ),
                      _InfoRow(
                        label: 'Description',
                        value: a.description,
                      ),
                      _InfoRow(
                        label: 'Instructions',
                        value: a.instructions,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (!a.isPublished && !a.isActive)
                  const AdminErrorBanner(
                    message:
                    'Inactive assignments cannot be published.',
                  ),
                if (!a.isPublished && data.questions.isEmpty)
                  const AdminErrorBanner(
                    message:
                    'Add at least one question before publishing.',
                  ),
                if (!data.marksMatch)
                  AdminErrorBanner(
                    message:
                    'Question marks total ${_marks(data.totalCents / 100)}; '
                        'assignment maximum is ${_marks(a.maxMarks)}. '
                        'These must match before publishing.',
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Questions can be changed while the assignment '
                      'is a draft. The server blocks changes after '
                      'any student submission.',
                ),
                const SizedBox(height: 24),
                Text(
                  'Questions (${data.questions.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (data.questions.isEmpty)
                  AdminStateMessage(
                    icon: Icons.quiz_outlined,
                    title: 'No questions yet',
                    message:
                    'Add text, file or MCQ questions to this assignment.',
                    actionLabel: !a.isPublished && !busy
                        ? 'Add Question'
                        : null,
                    onAction: !a.isPublished && !busy
                        ? () => questionDialog(data)
                        : null,
                  ),
                for (final q in data.questions) ...[
                  AdminCard(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          '${q.sequence}. ${q.questionText}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            SoftBadge(label: q.answerType),
                            SoftBadge(
                              label: '${_marks(q.marks)} marks',
                            ),
                            SoftBadge(
                              label: q.isRequired
                                  ? 'Required'
                                  : 'Optional',
                            ),
                          ],
                        ),
                        if (q.answerType == 'MCQ') ...[
                          const SizedBox(height: 12),
                          SelectableText(
                            'A. ${q.optionA}\n'
                                'B. ${q.optionB}\n'
                                'C. ${q.optionC}\n'
                                'D. ${q.optionD}',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Correct option: ${q.correctOption}',
                          ),
                        ],
                        if (q.answerType == 'TEXT' &&
                            q.answerText.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SelectableText(
                            'Expected answer: ${q.answerText}',
                          ),
                        ],
                        if (!a.isPublished) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              AdminOutlineButton(
                                label: 'Edit',
                                icon: Icons.edit_outlined,
                                onPressed: busy
                                    ? null
                                    : () => questionDialog(data, q),
                              ),
                              AdminOutlineButton(
                                label: 'Delete',
                                icon: Icons.delete_outline,
                                danger: true,
                                onPressed: busy
                                    ? null
                                    : () => deleteQuestion(data, q),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
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

class _QuestionDialog extends ConsumerStatefulWidget {
  const _QuestionDialog({
    required this.assignmentUuid,
    this.question,
    this.initialSequence = 1,
  });

  final String assignmentUuid;
  final AssignmentQuestion? question;
  final int initialSequence;

  @override
  ConsumerState<_QuestionDialog> createState() =>
      _QuestionDialogState();
}

class _QuestionDialogState extends ConsumerState<_QuestionDialog> {
  final form = GlobalKey<FormState>();

  late final TextEditingController questionText;
  late final TextEditingController marks;
  late final TextEditingController sequence;
  late final TextEditingController answerText;
  late final List<TextEditingController> options;

  late String answerType;
  String? correctOption;
  late bool isRequired;

  bool saving = false;
  String? error;

  static const types = ['TEXT', 'FILE', 'MCQ'];
  static const keys = ['A', 'B', 'C', 'D'];

  @override
  void initState() {
    super.initState();

    final q = widget.question;

    questionText = TextEditingController(
      text: q?.questionText ?? '',
    );

    marks = TextEditingController(
      text: q == null ? '1.00' : q.marks.toStringAsFixed(2),
    );

    sequence = TextEditingController(
      text: '${q?.sequence ?? widget.initialSequence}',
    );

    answerText = TextEditingController(
      text: q?.answerText ?? '',
    );

    options = [
      q?.optionA,
      q?.optionB,
      q?.optionC,
      q?.optionD,
    ]
        .map((text) => TextEditingController(text: text ?? ''))
        .toList();

    answerType = q?.answerType.toUpperCase() ?? 'TEXT';

    final correct = q?.correctOption.trim().toUpperCase() ?? '';
    correctOption = correct.isEmpty ? null : correct;

    isRequired = q?.isRequired ?? true;
  }

  @override
  void dispose() {
    for (final c in [
      questionText,
      marks,
      sequence,
      answerText,
      ...options,
    ]) {
      c.dispose();
    }

    super.dispose();
  }

  String? marksError(String? value) {
    final text = value?.trim() ?? '';
    final number = double.tryParse(text);

    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text) ||
        number == null ||
        !number.isFinite ||
        number < 0 ||
        number > 999999.99) {
      return 'Use 0–999999.99 with at most 2 decimal places.';
    }

    return null;
  }

  String? sequenceError(String? value) {
    final text = value?.trim() ?? '';
    final number = int.tryParse(text);

    if (!RegExp(r'^\d+$').hasMatch(text) ||
        number == null ||
        number < 0 ||
        number > 2147483647) {
      return 'Enter a whole number from 0 to 2147483647.';
    }

    return null;
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;

    setState(() {
      saving = true;
      error = null;
    });

    try {
      final repo = ref.read(assignmentRepositoryProvider);
      final q = widget.question;
      final mcq = answerType == 'MCQ';

      if (q == null) {
        await repo.createQuestion(
          assignmentUuid: widget.assignmentUuid,
          questionText: questionText.text.trim(),
          answerType: answerType,
          marks: double.parse(marks.text.trim()),
          sequence: int.parse(sequence.text.trim()),
          isRequired: isRequired,
          answerText: answerType == 'TEXT'
              ? answerText.text.trim()
              : '',
          optionA: mcq ? options[0].text.trim() : '',
          optionB: mcq ? options[1].text.trim() : '',
          optionC: mcq ? options[2].text.trim() : '',
          optionD: mcq ? options[3].text.trim() : '',
          correctOption: mcq ? correctOption! : '',
        );
      } else {
        await repo.updateQuestion(
          assignmentUuid: widget.assignmentUuid,
          questionUuid: q.uuid,
          questionText: questionText.text.trim(),
          answerType: answerType,
          marks: double.parse(marks.text.trim()),
          sequence: int.parse(sequence.text.trim()),
          isRequired: isRequired,
          answerText: answerType == 'TEXT'
              ? answerText.text.trim()
              : '',
          optionA: mcq ? options[0].text.trim() : '',
          optionB: mcq ? options[1].text.trim() : '',
          optionC: mcq ? options[2].text.trim() : '',
          optionD: mcq ? options[3].text.trim() : '',
          correctOption: mcq ? correctOption! : '',
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Could not save question. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget textField(
      String label,
      TextEditingController controller, {
        bool required = false,
        int lines = 1,
      }) =>
      FieldLabel(
        label: label,
        required: required,
        child: TextFormField(
          controller: controller,
          enabled: !saving,
          minLines: lines,
          maxLines: lines + 2,
          decoration: adminFieldDecoration(context),
          validator: (v) =>
          required && (v == null || v.trim().isEmpty)
              ? '$label is required.'
              : null,
        ),
      );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AdminFormDialog(
      icon: Icons.quiz_outlined,
      title: widget.question == null
          ? 'Add question'
          : 'Edit question',
      subtitle: 'Choose the answer type, marks and sequence.',
      onClose: saving
          ? null
          : () => Navigator.of(context).pop(),
      body: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            textField(
              'Question',
              questionText,
              required: true,
              lines: 3,
            ),
            const SizedBox(height: 16),
            FieldLabel(
              label: 'Answer type',
              required: true,
              child: DropdownButtonFormField<String>(
                value: answerType,
                decoration: adminFieldDecoration(context),
                items: [
                  for (final type in types)
                    DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    ),
                  if (!types.contains(answerType))
                    DropdownMenuItem(
                      value: answerType,
                      child: Text(answerType),
                    ),
                ],
                validator: (v) => types.contains(v)
                    ? null
                    : 'Choose TEXT, FILE or MCQ.',
                onChanged: saving
                    ? null
                    : (v) {
                  if (v != null) {
                    setState(() {
                      answerType = v;
                      error = null;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            FormRow(
              left: FieldLabel(
                label: 'Marks',
                required: true,
                child: TextFormField(
                  controller: marks,
                  enabled: !saving,
                  validator: marksError,
                  keyboardType:
                  const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: adminFieldDecoration(
                    context,
                    hint: '1.00',
                  ),
                ),
              ),
              right: FieldLabel(
                label: 'Sequence',
                required: true,
                child: TextFormField(
                  controller: sequence,
                  enabled: !saving,
                  validator: sequenceError,
                  keyboardType: TextInputType.number,
                  decoration: adminFieldDecoration(
                    context,
                    hint: '1',
                  ),
                ),
              ),
            ),
            if (answerType == 'TEXT') ...[
              const SizedBox(height: 16),
              textField(
                'Expected answer',
                answerText,
                lines: 3,
              ),
            ],
            if (answerType == 'FILE') ...[
              const SizedBox(height: 16),
              const Text(
                'Students will upload a file as their answer.',
              ),
            ],
            if (answerType == 'MCQ') ...[
              for (var i = 0; i < options.length; i++) ...[
                const SizedBox(height: 16),
                textField(
                  'Option ${keys[i]}',
                  options[i],
                  required: true,
                ),
              ],
              const SizedBox(height: 16),
              FieldLabel(
                label: 'Correct option',
                required: true,
                child: DropdownButtonFormField<String>(
                  value: correctOption,
                  decoration: adminFieldDecoration(
                    context,
                    hint: 'Choose A, B, C or D',
                  ),
                  items: [
                    for (final key in keys)
                      DropdownMenuItem(
                        value: key,
                        child: Text(key),
                      ),
                    if (correctOption != null &&
                        !keys.contains(correctOption))
                      DropdownMenuItem(
                        value: correctOption,
                        child: Text(correctOption!),
                      ),
                  ],
                  validator: (v) => keys.contains(v)
                      ? null
                      : 'Choose A, B, C or D.',
                  onChanged: saving
                      ? null
                      : (v) {
                    setState(() => correctOption = v);
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Required question'),
              value: isRequired,
              onChanged: saving
                  ? null
                  : (v) => setState(() => isRequired = v),
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
          label: 'Save Question',
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

String _marks(double value) => value.toStringAsFixed(2);

String _date(DateTime? value) {
  if (value == null) return 'No deadline';

  final d = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');

  return '${two(d.day)}/${two(d.month)}/${d.year} '
      '${two(d.hour)}:${two(d.minute)}';
}