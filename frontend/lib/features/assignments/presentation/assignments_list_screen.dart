import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';

import '../../courses/data/course_repository.dart';
import '../../subjects/data/subject_repository.dart';
import '../../subjects/data/chapter_repository.dart';
import '../../subjects/data/lesson_repository.dart';

import '../data/assignment.dart';
import '../data/assignment_repository.dart';

class AssignmentsListScreen extends ConsumerStatefulWidget {
  const AssignmentsListScreen({super.key});

  @override
  ConsumerState<AssignmentsListScreen> createState() =>
      _AssignmentsListScreenState();
}

class _AssignmentsListScreenState
    extends ConsumerState<AssignmentsListScreen> {
  final searchController = TextEditingController();
  late Future<AssignmentPage> result;
  String search = '';
  int page = 1;
  bool creating = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    result = ref.read(assignmentRepositoryProvider).list(
      search: search,
      page: page,
    );
  }

  void refresh() {
    setState(reload);
  }

  void applySearch() {
    setState(() {
      search = searchController.text.trim();
      page = 1;
      reload();
    });
  }

  void changePage(int value) {
    setState(() {
      page = value;
      reload();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _openCreate() async {
    if (creating) return;
    setState(() => creating = true);

    try {
      final created = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _CreateAssignmentDialog(),
      );

      if (created == true && mounted) {
        setState(() {
          searchController.clear();
          search = '';
          page = 1;
          reload();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment created as a draft.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  Future<void> _openImport() async {
    await context.push('/assignments/import-pdf');
    if (mounted) refresh();
  }

  String _marks(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          eyebrow: const AdminEyebrow(
            section: 'Evaluation hub',
            detail: 'Assignments & submissions',
          ),
          title: 'Assignments',
          titleTrailing: [
            IconButton(
              onPressed: refresh,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
            ),
          ],
          actions: [
            AdminOutlineButton(
              label: 'Import PDF',
              icon: Icons.picture_as_pdf_outlined,
              onPressed: creating ? null : _openImport,
            ),
            GradientButton(
              label: 'Create assignment',
              icon: Icons.assignment_add,
              onPressed: creating ? null : _openCreate,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: FutureBuilder<AssignmentPage>(
            future: result,
            builder: (context, snapshot) {
              final state = adminFutureState(
                snapshot,
                noun: 'assignments',
                onRetry: refresh,
              );

              final data = state == null ? snapshot.data : null;
              final rows = data?.results ?? const <Assignment>[];
              final now = DateTime.now();

              final published =
                  rows.where((a) => a.isPublished).length;

              final open = rows.where((a) {
                return a.isActive &&
                    a.isPublished &&
                    (a.dueAt == null ||
                        a.dueAt!.isAfter(now) ||
                        a.allowLateSubmission);
              }).length;

              final dueSoon = rows.where((a) {
                final due = a.dueAt;
                return a.isActive &&
                    a.isPublished &&
                    due != null &&
                    !due.isBefore(now) &&
                    !due.isAfter(
                      now.add(const Duration(days: 7)),
                    );
              }).length;

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  AdminKpiGrid(
                    children: [
                      AdminKpiCard(
                        label: search.isEmpty
                            ? 'Total assignments'
                            : 'Matching assignments',
                        value: data == null ? '…' : '${data.count}',
                        icon: Icons.assignment_outlined,
                      ),
                      AdminKpiCard(
                        label: 'Published on this page',
                        value: data == null ? '…' : '$published',
                        icon: Icons.public_rounded,
                        iconBackground: const Color(0xFFECFDF5),
                        iconForeground: const Color(0xFF059669),
                        caption: data == null
                            ? null
                            : '${rows.length - published} drafts on this page',
                      ),
                      AdminKpiCard(
                        label: 'Accepting submissions',
                        value: data == null ? '…' : '$open',
                        icon: Icons.inbox_outlined,
                        iconBackground: const Color(0xFFF0F9FF),
                        iconForeground: const Color(0xFF0284C7),
                        caption: 'On this page',
                      ),
                      AdminKpiCard(
                        label: 'Due in 7 days',
                        value: data == null ? '…' : '$dueSoon',
                        icon: Icons.alarm_rounded,
                        iconBackground: const Color(0xFFFFFBEB),
                        iconForeground: const Color(0xFFD97706),
                        caption: 'On this page',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AdminToolbar(
                    controller: searchController,
                    hint: 'Search by title or description…',
                    onSearch: applySearch,
                  ),
                  const SizedBox(height: 18),
                  if (state != null)
                    state
                  else if (rows.isEmpty)
                    AdminStateMessage(
                      icon: Icons.assignment_add,
                      title: 'No assignments found',
                      message: search.isEmpty
                          ? 'Create an assignment or import one from a PDF.'
                          : 'Try a different search.',
                      actionLabel: search.isEmpty && !creating
                          ? 'Create assignment'
                          : null,
                      onAction: search.isEmpty && !creating
                          ? _openCreate
                          : null,
                    )
                  else ...[
                      for (final assignment in rows)
                        AdminListRow(
                          title: assignment.title,
                          icon: assignment.isPublished
                              ? Icons.assignment_turned_in_outlined
                              : Icons.assignment_outlined,
                          subtitle: assignment.description,
                          meta: [
                            MetaChip(
                              icon: Icons.auto_stories_outlined,
                              label: assignment.courseName,
                            ),
                            MetaChip(
                              icon: Icons.star_outline_rounded,
                              label:
                              '${_marks(assignment.maxMarks)} marks',
                            ),
                            MetaChip(
                              icon: Icons.event_outlined,
                              label:
                              'Due ${_formatDateTime(assignment.dueAt)}',
                            ),
                            if (assignment.allowLateSubmission)
                              const SoftBadge(
                                label: 'Late allowed',
                                background: Color(0xFFFFFBEB),
                                foreground: Color(0xFFD97706),
                              ),
                          ],
                          trailing: [
                            ActiveBadge(
                              active: assignment.isPublished,
                              activeLabel: 'Published',
                              inactiveLabel: 'Draft',
                            ),
                          ],
                          onTap: () async {
                            await context.push(
                              '/assignments/${assignment.uuid}',
                            );
                            if (mounted) refresh();
                          },
                        ),
                    ],
                  if (state == null && data != null)
                    AdminPager(
                      page: page,
                      pageSize: 20,
                      total: data.count,
                      noun: 'assignments',
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
}

class _Choice {
  const _Choice(this.uuid, this.label);

  final String uuid;
  final String label;
}

class _ChoicePage {
  const _ChoicePage(this.count, this.rows);

  final int count;
  final List<_Choice> rows;
}

class _CreateAssignmentDialog extends ConsumerStatefulWidget {
  const _CreateAssignmentDialog();

  @override
  ConsumerState<_CreateAssignmentDialog> createState() =>
      _CreateAssignmentDialogState();
}

class _CreateAssignmentDialogState
    extends ConsumerState<_CreateAssignmentDialog> {
  static const levels = [
    'course',
    'subject',
    'chapter',
    'lesson',
  ];

  static const labels = {
    'course': 'Course',
    'subject': 'Subject',
    'chapter': 'Chapter',
    'lesson': 'Lesson',
  };

  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final description = TextEditingController();
  final instructions = TextEditingController();
  final maxMarks = TextEditingController(text: '0');

  final choices = <String, List<_Choice>>{
    for (final k in levels) k: [],
  };

  final selected = <String, String?>{
    for (final k in levels) k: null,
  };

  final loading = <String, bool>{
    for (final k in levels) k: false,
  };

  final errors = <String, String?>{
    for (final k in levels) k: null,
  };

  final tickets = <String, int>{
    for (final k in levels) k: 0,
  };

  DateTime? dueAt;
  bool allowLateSubmission = false;
  bool saving = false;
  bool picking = false;
  String? error;

  bool get locked => saving || picking;
  bool get waiting => loading.values.any((v) => v);
  bool get lookupFailed => errors.values.any((v) => v != null);

  @override
  void initState() {
    super.initState();
    load('course');
  }

  @override
  void dispose() {
    for (final c in [
      title,
      description,
      instructions,
      maxMarks,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<_ChoicePage> fetchPage(
      String kind,
      String? parent,
      int page,
      ) async {
    switch (kind) {
      case 'course': {
        final data = await ref
            .read(courseRepositoryProvider)
            .list(page: page);

        return _ChoicePage(
          data.count,
          data.results
              .where((x) => x.isActive)
              .map(
                (x) => _Choice(
              x.uuid,
              '${x.name} (${x.code})',
            ),
          )
              .toList(),
        );
      }

      case 'subject': {
        final data = await ref
            .read(subjectRepositoryProvider)
            .list(courseUuid: parent!, page: page);

        return _ChoicePage(
          data.count,
          data.results
              .where((x) => x.isActive)
              .map((x) => _Choice(x.uuid, x.name))
              .toList(),
        );
      }

      case 'chapter': {
        final data = await ref
            .read(chapterRepositoryProvider)
            .list(subjectUuid: parent!, page: page);

        return _ChoicePage(
          data.count,
          data.results
              .where((x) => x.isActive)
              .map((x) => _Choice(x.uuid, x.title))
              .toList(),
        );
      }

      case 'lesson': {
        final data = await ref
            .read(lessonRepositoryProvider)
            .list(chapterUuid: parent!, page: page);

        return _ChoicePage(
          data.count,
          data.results
              .where((x) => x.isActive)
              .map((x) => _Choice(x.uuid, x.title))
              .toList(),
        );
      }

      default:
        throw StateError('Unknown mapping level');
    }
  }

  Future<void> load(String kind) async {
    if (locked || loading[kind]!) return;

    final index = levels.indexOf(kind);
    final parent =
    index == 0 ? null : selected[levels[index - 1]];

    if (index > 0 && parent == null) return;

    final ticket = tickets[kind]! + 1;

    setState(() {
      tickets[kind] = ticket;
      loading[kind] = true;
      errors[kind] = null;
    });

    try {
      final all = <String, _Choice>{};

      for (var page = 1; ; page++) {
        final data = await fetchPage(kind, parent, page);

        if (!mounted || tickets[kind] != ticket) return;

        for (final choice in data.rows) {
          all[choice.uuid] = choice;
        }

        if (page * 20 >= data.count) break;
      }

      if (!mounted || tickets[kind] != ticket) return;

      setState(() {
        choices[kind] = all.values.toList();
      });
    } on ApiException catch (e) {
      if (mounted && tickets[kind] == ticket) {
        setState(() => errors[kind] = e.message);
      }
    } catch (_) {
      if (mounted && tickets[kind] == ticket) {
        setState(() {
          errors[kind] =
          'Could not load ${labels[kind]!.toLowerCase()} '
              'options. Please retry.';
        });
      }
    } finally {
      if (mounted && tickets[kind] == ticket) {
        setState(() => loading[kind] = false);
      }
    }
  }

  void choose(String kind, String? value) {
    if (locked) return;

    final index = levels.indexOf(kind);

    setState(() {
      selected[kind] = value;
      error = null;

      for (var i = index + 1; i < levels.length; i++) {
        final child = levels[i];
        tickets[child] = tickets[child]! + 1;
        selected[child] = null;
        choices[child] = [];
        loading[child] = false;
        errors[child] = null;
      }
    });

    if (value != null && index + 1 < levels.length) {
      load(levels[index + 1]);
    }
  }

  String? marksError(String? value) {
    final text = value?.trim() ?? '';
    final number = double.tryParse(text);

    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text) ||
        number == null ||
        !number.isFinite ||
        number < 0 ||
        number > 999999.99) {
      return 'Use 0–999999.99, with at most 2 decimal places.';
    }

    final whole = text
        .split('.')
        .first
        .replaceFirst(RegExp(r'^0+'), '');

    if (whole.length > 6) {
      return 'Use at most 6 digits before the decimal.';
    }

    return null;
  }

  Future<void> pickDue() async {
    if (locked) return;

    setState(() => picking = true);

    try {
      final initial = dueAt ?? DateTime.now();
      final day = DateTime(
        initial.year,
        initial.month,
        initial.day,
      );

      final date = await showDatePicker(
        context: context,
        initialDate: day,
        firstDate: day.isBefore(DateTime(2000))
            ? day
            : DateTime(2000),
        lastDate: day.isAfter(DateTime(2100, 12, 31))
            ? day
            : DateTime(2100, 12, 31),
      );

      if (!mounted || date == null) return;

      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );

      if (!mounted || time == null) return;

      setState(() {
        dueAt = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        error = null;
      });
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> save() async {
    if (locked ||
        waiting ||
        lookupFailed ||
        !form.currentState!.validate()) {
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await ref.read(assignmentRepositoryProvider).create(
        courseUuid: selected['course']!,
        subjectUuid: selected['subject'],
        chapterUuid: selected['chapter'],
        lessonUuid: selected['lesson'],
        title: title.text.trim(),
        description: description.text.trim(),
        instructions: instructions.text.trim(),
        maxMarks: double.parse(maxMarks.text.trim()),
        dueAt: dueAt,
        allowLateSubmission: allowLateSubmission,
      );

      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Could not create assignment. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget mappingField(String kind) {
    final index = levels.indexOf(kind);

    final enabled = !locked &&
        !loading[kind]! &&
        errors[kind] == null &&
        (index == 0 ||
            selected[levels[index - 1]] != null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldLabel(
            label: labels[kind]!,
            required: index == 0,
            child: DropdownButtonFormField<String>(
              key: ValueKey(
                '${kind}_${selected[kind]}_${tickets[kind]}',
              ),
              value: selected[kind],
              isExpanded: true,
              decoration: adminFieldDecoration(
                context,
                hint: index == 0
                    ? 'Choose an active course'
                    : 'Optional mapping',
                helper: index > 0 &&
                    selected[levels[index - 1]] == null
                    ? 'Select ${levels[index - 1]} first'
                    : !loading[kind]! &&
                    errors[kind] == null &&
                    choices[kind]!.isEmpty
                    ? 'No active options available'
                    : null,
              ),
              items: [
                if (index > 0)
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('No mapping'),
                  ),
                for (final c in choices[kind]!)
                  DropdownMenuItem<String>(
                    value: c.uuid,
                    child: Text(
                      c.label,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: enabled
                  ? (v) => choose(kind, v)
                  : null,
              validator: (v) => index == 0 && v == null
                  ? 'Please select a course.'
                  : null,
            ),
          ),
          if (loading[kind]!) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          if (errors[kind] != null) ...[
            const SizedBox(height: 8),
            AdminErrorBanner(message: errors[kind]!),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: locked
                    ? null
                    : () => load(kind),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !locked,
    child: AdminFormDialog(
      icon: Icons.assignment_outlined,
      title: 'Create assignment',
      subtitle:
      'Create a draft, then add questions and publish it.',
      onClose: locked
          ? null
          : () => Navigator.of(context).pop(),
      body: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final kind in levels) mappingField(kind),
            FieldLabel(
              label: 'Title',
              required: true,
              child: TextFormField(
                controller: title,
                enabled: !locked,
                maxLength: 255,
                decoration: adminFieldDecoration(
                  context,
                  hint: 'Assignment title',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Title is required.';
                  }
                  if (v.trim().length > 255) {
                    return 'Use at most 255 characters.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            FieldLabel(
              label: 'Description',
              child: TextFormField(
                controller: description,
                enabled: !locked,
                minLines: 2,
                maxLines: 4,
                decoration: adminFieldDecoration(
                  context,
                  hint: 'Optional description',
                ),
              ),
            ),
            const SizedBox(height: 16),
            FieldLabel(
              label: 'Instructions',
              child: TextFormField(
                controller: instructions,
                enabled: !locked,
                minLines: 3,
                maxLines: 6,
                decoration: adminFieldDecoration(
                  context,
                  hint: 'Instructions for students',
                ),
              ),
            ),
            const SizedBox(height: 16),
            FieldLabel(
              label: 'Maximum marks',
              required: true,
              child: TextFormField(
                controller: maxMarks,
                enabled: !locked,
                keyboardType:
                const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: adminFieldDecoration(
                  context,
                  hint: '0.00',
                ),
                validator: marksError,
              ),
            ),
            const SizedBox(height: 16),
            FieldLabel(
              label: 'Due date (local time)',
              child: InputDecorator(
                decoration: adminFieldDecoration(context),
                child: Wrap(
                  spacing: 8,
                  crossAxisAlignment:
                  WrapCrossAlignment.center,
                  children: [
                    Text(_formatDateTime(dueAt)),
                    IconButton(
                      tooltip: 'Choose due date',
                      onPressed: locked ? null : pickDue,
                      icon: const Icon(
                        Icons.calendar_month_outlined,
                      ),
                    ),
                    if (dueAt != null)
                      IconButton(
                        tooltip: 'Clear due date',
                        onPressed: locked
                            ? null
                            : () => setState(
                              () => dueAt = null,
                        ),
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow late submission'),
              value: allowLateSubmission,
              onChanged: locked
                  ? null
                  : (v) => setState(
                    () => allowLateSubmission = v,
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
          onPressed: locked
              ? null
              : () => Navigator.of(context).pop(),
        ),
        GradientButton(
          label: 'Create Draft',
          icon: Icons.add,
          loading: saving,
          onPressed: locked || waiting || lookupFailed
              ? null
              : save,
        ),
      ],
    ),
  );
}

String _formatDateTime(DateTime? value) {
  if (value == null) return 'No deadline';

  final d = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');

  return '${two(d.day)}/${two(d.month)}/${d.year} '
      '${two(d.hour)}:${two(d.minute)}';
}