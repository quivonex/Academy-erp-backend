import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/status_pill.dart';
import '../../courses/data/course_repository.dart';
import '../../teachers/data/teacher_repository.dart';
import '../../subjects/data/subject_repository.dart';
import '../../subjects/data/chapter_repository.dart';
import '../../subjects/data/lesson_repository.dart';
import '../data/live_class.dart';
import '../data/live_class_repository.dart';

class LiveClassesListScreen extends ConsumerStatefulWidget {
  const LiveClassesListScreen({super.key});

  @override
  ConsumerState<LiveClassesListScreen> createState() =>
      _LiveClassesListScreenState();
}

class _LiveClassesListScreenState extends ConsumerState<LiveClassesListScreen> {
  final searchController = TextEditingController();
  late Future<LiveClassPage> result;
  String search = '';
  String? statusFilter;
  int page = 1;
  bool creating = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void reload() {
    result = ref.read(liveClassRepositoryProvider).list(
      page: page, search: search, status: statusFilter,
    );
  }

  void refresh() => setState(reload);

  void applySearch() => setState(() {
    search = searchController.text.trim();
    page = 1;
    reload();
  });

  void setStatus(String? value) => setState(() {
    statusFilter = value;
    page = 1;
    reload();
  });

  Future<void> createLiveClass() async {
    if (creating) return;
    setState(() => creating = true);
    try {
      final created = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _ScheduleLiveClassDialog(),
      );
      if (!mounted || created != true) return;
      setState(() {
        searchController.clear();
        search = '';
        statusFilter = null;
        page = 1;
        reload();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Live class scheduled successfully.')),
      );
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AdminPageHeader(
        eyebrow: const AdminEyebrow(
          section: 'Virtual campus', detail: 'Live classes & lectures',
        ),
        title: 'Live classes',
        titleTrailing: [
          IconButton(
            tooltip: 'Refresh', onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        actions: [
          GradientButton(
            label: 'Schedule class', icon: Icons.video_call_outlined,
            onPressed: creating ? null : createLiveClass,
          ),
        ],
      ),
      const SizedBox(height: 20),
      Expanded(
        child: FutureBuilder<LiveClassPage>(
          future: result,
          builder: (context, snapshot) {
            final state = adminFutureState(
              snapshot, noun: 'live classes', onRetry: refresh,
            );
            final data = state == null ? snapshot.data : null;
            final rows = data?.results ?? const <LiveClass>[];
            int countOf(String status) =>
                rows.where((c) => c.status.toUpperCase() == status).length;
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                AdminKpiGrid(children: [
                  AdminKpiCard(
                    label: 'Matching classes', value: data == null ? '…' : '${data.count}',
                    icon: Icons.video_library_outlined,
                  ),
                  for (final status in ['LIVE', 'SCHEDULED', 'COMPLETED'])
                    AdminKpiCard(
                      label: status, value: data == null ? '…' : '${countOf(status)}',
                      icon: Icons.videocam_outlined, caption: 'On this page',
                    ),
                ]),
                const SizedBox(height: 18),
                AdminToolbar(
                  controller: searchController,
                  hint: 'Search by title or course name…',
                  onSearch: applySearch,
                  filters: [
                    for (final status in [null, 'LIVE', 'SCHEDULED', 'COMPLETED', 'CANCELLED'])
                      CountFilterPill(
                        label: status ?? 'ALL', selected: statusFilter == status,
                        onTap: () => setStatus(status),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                if (state != null)
                  state
                else ...[
                  if (rows.isEmpty)
                    AdminStateMessage(
                      icon: Icons.video_call_outlined,
                      title: 'No live classes found',
                      message: 'Schedule a class or change the filters/page.',
                      actionLabel: 'Schedule class',
                      onAction: creating ? null : createLiveClass,
                    ),
                  for (final liveClass in rows)
                    AdminListRow(
                      title: liveClass.title,
                      icon: Icons.videocam_outlined,
                      subtitle: liveClass.description,
                      meta: [
                        MetaChip(icon: Icons.auto_stories_outlined, label: liveClass.courseName),
                        MetaChip(icon: Icons.person_outline_rounded, label: liveClass.teacherName),
                        MetaChip(icon: Icons.schedule_rounded, label: _formatDateTime(liveClass.scheduledStartAt)),
                        if ((liveClass.subjectName ?? '').isNotEmpty)
                          MetaChip(icon: Icons.menu_book_outlined, label: liveClass.subjectName!),
                      ],
                      trailing: [_LiveStatusChip(status: liveClass.status)],
                      onTap: () async {
                        await context.push('/live-classes/${liveClass.uuid}');
                        if (mounted) refresh();
                      },
                    ),
                  if (data!.count > 0 || page > 1)
                    AdminPager(
                      page: page, pageSize: 20, total: data.count, noun: 'classes',
                      onPage: (next) => setState(() { page = next; reload(); }),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    ],
  );
}

class _Choice {
  const _Choice(this.uuid, this.label);
  final String uuid;
  final String label;
}

class _ChoicePage {
  const _ChoicePage(this.count, this.items);
  final int count;
  final List<_Choice> items;
}

class _ScheduleLiveClassDialog extends ConsumerStatefulWidget {
  const _ScheduleLiveClassDialog();

  @override
  ConsumerState<_ScheduleLiveClassDialog> createState() =>
      _ScheduleLiveClassDialogState();
}

class _ScheduleLiveClassDialogState extends ConsumerState<_ScheduleLiveClassDialog> {
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final description = TextEditingController();
  final meetingUrl = TextEditingController();
  final meetingId = TextEditingController();
  final meetingPassword = TextEditingController();
  final selected = <String, String?>{};
  final options = <String, List<_Choice>>{};
  final loading = <String, bool>{};
  final errors = <String, String?>{};
  final tickets = <String, int>{};
  static const hierarchy = ['course', 'subject', 'chapter', 'lesson'];
  DateTime? startAt;
  DateTime? endAt;
  bool saving = false;
  bool pickingDate = false;
  String? error;

  bool get waiting => loading.values.any((value) => value);

  @override
  void initState() {
    super.initState();
    loadOptions('course');
    loadOptions('teacher');
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    meetingUrl.dispose();
    meetingId.dispose();
    meetingPassword.dispose();
    super.dispose();
  }

  String? parentOf(String kind) => switch (kind) {
    'subject' => selected['course'],
    'chapter' => selected['subject'],
    'lesson' => selected['chapter'],
    _ => null,
  };

  Future<_ChoicePage> fetchOptions(String kind, String? parent, int page) async {
    switch (kind) {
      case 'course': {
        final data = await ref.read(courseRepositoryProvider).list(page: page);
        return _ChoicePage(data.count, [
          for (final c in data.results) _Choice(c.uuid, '${c.name} (${c.code})'),
        ]);
      }
      case 'teacher': {
        final data = await ref.read(teacherRepositoryProvider).list(isActive: true, page: page);
        return _ChoicePage(data.count, [
          for (final t in data.results) _Choice(t.uuid, '${t.fullName} (${t.employeeId})'),
        ]);
      }
      case 'subject': {
        final data = await ref.read(subjectRepositoryProvider).list(courseUuid: parent!, page: page);
        return _ChoicePage(data.count, [
          for (final s in data.results) _Choice(s.uuid, s.name),
        ]);
      }
      case 'chapter': {
        final data = await ref.read(chapterRepositoryProvider).list(subjectUuid: parent!, page: page);
        return _ChoicePage(data.count, [
          for (final c in data.results) _Choice(c.uuid, c.title),
        ]);
      }
      case 'lesson': {
        final data = await ref.read(lessonRepositoryProvider).list(chapterUuid: parent!, page: page);
        return _ChoicePage(data.count, [
          for (final l in data.results) _Choice(l.uuid, l.title),
        ]);
      }
      default:
        throw StateError('Unknown dropdown');
    }
  }

  Future<void> loadOptions(String kind) async {
    if (saving) return;
    final parent = parentOf(kind);
    if (hierarchy.indexOf(kind) > 0 && parent == null) return;
    final ticket = (tickets[kind] ?? 0) + 1;
    tickets[kind] = ticket;
    setState(() { loading[kind] = true; errors[kind] = null; });
    try {
      final all = <String, _Choice>{};
      var page = 1;
      while (true) {
        final data = await fetchOptions(kind, parent, page);
        if (!mounted || tickets[kind] != ticket) return;
        for (final item in data.items) {
          all[item.uuid] = item;
        }
        if (data.items.isEmpty || page * 20 >= data.count) break;
        page++;
      }
      setState(() => options[kind] = all.values.toList());
    } on ApiException catch (e) {
      if (mounted && tickets[kind] == ticket) {
        setState(() => errors[kind] = e.message);
      }
    } catch (_) {
      if (mounted && tickets[kind] == ticket) {
        setState(() => errors[kind] = 'Could not load $kind options. Please retry.');
      }
    } finally {
      if (mounted && tickets[kind] == ticket) {
        setState(() => loading[kind] = false);
      }
    }
  }

  void select(String kind, String? value) {
    if (saving) return;
    final index = hierarchy.indexOf(kind);
    setState(() {
      selected[kind] = value;
      error = null;
      if (index >= 0) {
        for (final child in hierarchy.skip(index + 1)) {
          tickets[child] = (tickets[child] ?? 0) + 1;
          selected[child] = null;
          options[child] = [];
          errors[child] = null;
          loading[child] = false;
        }
      }
    });
    if (value != null && index >= 0 && index < hierarchy.length - 1) {
      loadOptions(hierarchy[index + 1]);
    }
  }

  Future<void> pickDate(bool start) async {
    if (saving || pickingDate) return;
    setState(() => pickingDate = true);
    try {
      final initial = (start ? startAt : endAt) ??
          (start ? DateTime.now() : (startAt ?? DateTime.now()).add(const Duration(hours: 1)));
      final date = await showDatePicker(
        context: context, initialDate: initial.toLocal(),
        firstDate: DateTime(2000), lastDate: DateTime(2100, 12, 31),
      );
      if (!mounted || date == null) return;
      final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(initial.toLocal()),
      );
      if (!mounted || time == null) return;
      final value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      setState(() {
        if (start) { startAt = value; } else { endAt = value; }
        error = null;
      });
    } finally {
      if (mounted) setState(() => pickingDate = false);
    }
  }

  Future<void> save() async {
    if (saving || waiting || pickingDate || !formKey.currentState!.validate()) return;
    if (startAt == null || endAt == null || !endAt!.isAfter(startAt!)) {
      setState(() => error = 'Select start/end times. End must be after start.');
      return;
    }
    setState(() { saving = true; error = null; });
    try {
      await ref.read(liveClassRepositoryProvider).create(
        courseUuid: selected['course']!,
        teacherUuid: selected['teacher']!,
        subjectUuid: selected['subject'],
        chapterUuid: selected['chapter'],
        lessonUuid: selected['lesson'],
        title: title.text,
        description: description.text,
        scheduledStartAt: startAt!,
        scheduledEndAt: endAt!,
        meetingUrl: meetingUrl.text,
        meetingId: meetingId.text,
        meetingPassword: meetingPassword.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not schedule class. Please try again.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget dropdown(String kind, String label, {bool required = false}) {
    final items = options[kind] ?? const <_Choice>[];
    final busy = saving || loading[kind] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DropdownButtonFormField<String>(
          key: ValueKey('$kind-${parentOf(kind)}-${selected[kind]}'),
          value: selected[kind],
          isExpanded: true,
          decoration: adminFieldDecoration(
            context, hint: label,
            suffix: !required && selected[kind] != null
                ? IconButton(
              tooltip: 'Clear $label', onPressed: saving ? null : () => select(kind, null),
              icon: const Icon(Icons.clear),
            )
                : null,
          ).copyWith(labelText: label),
          items: [
            for (final item in items)
              DropdownMenuItem(value: item.uuid, child: Text(item.label, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: busy || errors[kind] != null || items.isEmpty ? null : (value) => select(kind, value),
          validator: (value) => required && value == null ? 'Please select $kind.' : null,
        ),
        if (loading[kind] == true) const LinearProgressIndicator(),
        if (errors[kind] != null) ...[
          Text(errors[kind]!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: saving ? null : () => loadOptions(kind), child: Text('Retry $kind')),
          ),
        ] else if (loading[kind] != true && items.isEmpty)
          Text('No $kind options available.'),
      ]),
    );
  }

  Widget field(TextEditingController controller, String label, {
    int? maxLength, int lines = 1, bool obscure = false, String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller, enabled: !saving,
      maxLength: maxLength, maxLines: lines, obscureText: obscure,
      decoration: adminFieldDecoration(context, hint: label).copyWith(labelText: label),
      validator: validator,
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving && !pickingDate,
    child: AdminFormDialog(
      icon: Icons.video_call_outlined,
      title: 'Schedule live class',
      subtitle: 'Select course, teacher and optional curriculum mapping.',
      onClose: saving || pickingDate ? null : () => Navigator.of(context).pop(),
      body: Form(
        key: formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          field(title, 'Class title', maxLength: 255,
              validator: (value) => (value ?? '').trim().isEmpty ? 'Title is required.' : null),
          field(description, 'Description', lines: 3),
          dropdown('course', 'Course', required: true),
          if (selected['course'] != null) dropdown('subject', 'Subject (optional)'),
          if (selected['subject'] != null) dropdown('chapter', 'Chapter (optional)'),
          if (selected['chapter'] != null) dropdown('lesson', 'Lesson (optional)'),
          dropdown('teacher', 'Teacher', required: true),
          for (final start in [true, false])
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(start ? 'Scheduled start (local time)' : 'Scheduled end (local time)'),
              subtitle: Text(_formatDateTime(start ? startAt : endAt)),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: saving || pickingDate ? null : () => pickDate(start),
            ),
          const SizedBox(height: 12),
          field(meetingUrl, 'Meeting URL', maxLength: 1000, validator: (value) {
            final text = (value ?? '').trim();
            if (text.isEmpty) return null;
            final uri = Uri.tryParse(text);
            if (uri == null || !['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
              return 'Enter a valid http/https meeting URL.';
            }
            return null;
          }),
          field(meetingId, 'Meeting ID', maxLength: 255),
          field(meetingPassword, 'Meeting password', maxLength: 255, obscure: true),
          if (error != null)
            Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ]),
      ),
      actions: [
        AdminOutlineButton(
          label: 'Cancel', onPressed: saving || pickingDate ? null : () => Navigator.of(context).pop(),
        ),
        GradientButton(
          label: 'Schedule class', loading: saving,
          onPressed: saving || waiting || pickingDate ? null : save,
        ),
      ],
    ),
  );
}

class _LiveStatusChip extends StatelessWidget {
  const _LiveStatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) => StatusPill(
    label: status.toUpperCase(), compact: true,
    tone: switch (status.toUpperCase()) {
      'LIVE' => PillTone.danger,
      'SCHEDULED' => PillTone.info,
      'COMPLETED' => PillTone.success,
      _ => PillTone.neutral,
    },
  );
}

String _formatDateTime(DateTime? value) {
  if (value == null) return 'Not selected';
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}