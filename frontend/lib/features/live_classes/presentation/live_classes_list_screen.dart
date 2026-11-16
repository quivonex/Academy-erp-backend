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
      page: page,
      search: search,
      status: statusFilter,
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
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top header matching reference screens ("Live classes" + refresh + "+ Schedule class")
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Live classes',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: refresh,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: Color(0xFF334155),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                FilledButton.icon(
                  onPressed: creating ? null : createLiveClass,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Schedule class'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF3730A3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    textStyle: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: FutureBuilder<LiveClassPage>(
              future: result,
              builder: (context, snapshot) {
                final state = adminFutureState(
                  snapshot,
                  noun: 'live classes',
                  onRetry: refresh,
                );
                final data = state == null ? snapshot.data : null;
                final rows = data?.results ?? const <LiveClass>[];
                int countOf(String status) =>
                    rows.where((c) => c.status.toUpperCase() == status).length;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  children: [
                    // 2x2 / Responsive KPI grid matching screenshot
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final columns = width < 600
                            ? 2
                            : width < 1000
                            ? 2
                            : 4;
                        const gap = 12.0;
                        final cardWidth =
                            (width - gap * (columns - 1)) / columns;

                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: _LiveClassStatCard(
                                label: 'Matching classes',
                                value: data == null ? '…' : '${data.count}',
                                caption: search.isEmpty
                                    ? 'All sessions'
                                    : 'Current search',
                                icon: Icons.folder_outlined,
                                iconColor: const Color(0xFF4F46E5),
                                iconBg: const Color(0xFFEEF2FF),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _LiveClassStatCard(
                                label: 'Live',
                                value: data == null ? '…' : '${countOf('LIVE')}',
                                caption: 'On page',
                                icon: Icons.videocam_outlined,
                                iconColor: const Color(0xFFE11D48),
                                iconBg: const Color(0xFFFFF1F2),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _LiveClassStatCard(
                                label: 'Scheduled',
                                value: data == null
                                    ? '…'
                                    : '${countOf('SCHEDULED')}',
                                caption: 'On page',
                                icon: Icons.event_available_outlined,
                                iconColor: const Color(0xFF1D4ED8),
                                iconBg: const Color(0xFFEFF6FF),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _LiveClassStatCard(
                                label: 'Completed',
                                value: data == null
                                    ? '…'
                                    : '${countOf('COMPLETED')}',
                                caption: 'On page',
                                icon: Icons.check_circle_outline_rounded,
                                iconColor: const Color(0xFF059669),
                                iconBg: const Color(0xFFECFDF5),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Search bar with "Search" button matching screenshot
                    _LiveClassSearchBar(
                      controller: searchController,
                      onSearch: applySearch,
                      onClear: search.isEmpty && searchController.text.isEmpty
                          ? null
                          : () {
                        searchController.clear();
                        applySearch();
                      },
                    ),

                    const SizedBox(height: 14),

                    // Filter pill strip matching screenshot ("ALL", "LIVE", "SCHEDULED", "COMPLETED", "CANCELLED")
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final status in const [
                            null,
                            'LIVE',
                            'SCHEDULED',
                            'COMPLETED',
                            'CANCELLED',
                          ]) ...[
                            if (status != null) const SizedBox(width: 8),
                            _LiveClassFilterPill(
                              label: status ?? 'ALL',
                              selected: statusFilter == status,
                              onTap: () => setStatus(status),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

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
                      for (final liveClass in rows) ...[
                        _LiveClassCard(
                          liveClass: liveClass,
                          onTap: () async {
                            await context.push('/live-classes/${liveClass.uuid}');
                            if (mounted) refresh();
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (data!.count > 0 || page > 1)
                        AdminPager(
                          page: page,
                          pageSize: 20,
                          total: data.count,
                          noun: 'classes',
                          onPage: (next) => setState(() {
                            page = next;
                            reload();
                          }),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveClassStatCard extends StatelessWidget {
  const _LiveClassStatCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF334155),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: jakarta(
              textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                fontSize: 28,
                letterSpacing: -0.6,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveClassSearchBar extends StatelessWidget {
  const _LiveClassSearchBar({
    required this.controller,
    required this.onSearch,
    this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onSearch;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            size: 20,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSearch(),
              decoration: const InputDecoration(
                hintText: 'Search by title or course name...',
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (onClear != null)
            IconButton(
              onPressed: onClear,
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: Color(0xFF94A3B8),
              ),
              visualDensity: VisualDensity.compact,
            ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: onSearch,
            icon: const Icon(Icons.search_rounded, size: 17),
            label: const Text(
              'Search',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3730A3),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveClassFilterPill extends StatelessWidget {
  const _LiveClassFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF3730A3) : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
              selected ? const Color(0xFF3730A3) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? Colors.white : const Color(0xFF334155),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveClassCard extends StatelessWidget {
  const _LiveClassCard({
    required this.liveClass,
    required this.onTap,
  });

  final LiveClass liveClass;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.videocam_outlined,
                      size: 20,
                      color: Color(0xFF3730A3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          liveClass.title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        if (liveClass.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            liveClass.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF64748B),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaPill(
                    icon: Icons.menu_book_outlined,
                    label: liveClass.courseName,
                  ),
                  if ((liveClass.teacherName ?? '').isNotEmpty)
                    _MetaPill(
                      icon: Icons.person_outline_rounded,
                      label: liveClass.teacherName!,
                    ),
                  _MetaPill(
                    icon: Icons.schedule_rounded,
                    label: _formatDateTime(liveClass.scheduledAt),
                  ),
                  if ((liveClass.subjectName ?? '').isNotEmpty)
                    _MetaPill(
                      icon: Icons.local_offer_outlined,
                      label: liveClass.subjectName!,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _LiveStatusChip(status: liveClass.status),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF475569)),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF334155),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
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

class _ScheduleLiveClassDialogState
    extends ConsumerState<_ScheduleLiveClassDialog> {
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
      case 'course':
        {
          final data =
          await ref.read(courseRepositoryProvider).list(page: page);
          return _ChoicePage(data.count, [
            for (final c in data.results)
              _Choice(c.uuid, '${c.name} (${c.code})'),
          ]);
        }
      case 'teacher':
        {
          final data = await ref
              .read(teacherRepositoryProvider)
              .list(isActive: true, page: page);
          return _ChoicePage(data.count, [
            for (final t in data.results)
              _Choice(t.uuid, '${t.fullName} (${t.employeeId})'),
          ]);
        }
      case 'subject':
        {
          final data = await ref
              .read(subjectRepositoryProvider)
              .list(courseUuid: parent!, page: page);
          return _ChoicePage(data.count, [
            for (final s in data.results) _Choice(s.uuid, s.name),
          ]);
        }
      case 'chapter':
        {
          final data = await ref
              .read(chapterRepositoryProvider)
              .list(subjectUuid: parent!, page: page);
          return _ChoicePage(data.count, [
            for (final c in data.results) _Choice(c.uuid, c.title),
          ]);
        }
      case 'lesson':
        {
          final data = await ref
              .read(lessonRepositoryProvider)
              .list(chapterUuid: parent!, page: page);
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
    setState(() {
      loading[kind] = true;
      errors[kind] = null;
    });
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
        setState(
                () => errors[kind] = 'Could not load $kind options. Please retry.');
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
          (start
              ? DateTime.now()
              : (startAt ?? DateTime.now()).add(const Duration(hours: 1)));
      final date = await showDatePicker(
        context: context,
        initialDate: initial.toLocal(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100, 12, 31),
      );
      if (!mounted || date == null) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial.toLocal()),
      );
      if (!mounted || time == null) return;
      final value =
      DateTime(date.year, date.month, date.day, time.hour, time.minute);
      setState(() {
        if (start) {
          startAt = value;
        } else {
          endAt = value;
        }
        error = null;
      });
    } finally {
      if (mounted) setState(() => pickingDate = false);
    }
  }

  Future<void> save() async {
    if (saving || waiting || pickingDate || !formKey.currentState!.validate()) {
      return;
    }
    if (startAt == null || endAt == null || !endAt!.isAfter(startAt!)) {
      setState(() => error = 'Select start/end times. End must be after start.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
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
      if (mounted) {
        setState(() => error = 'Could not schedule class. Please try again.');
      }
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
            context,
            hint: label,
            suffix: !required && selected[kind] != null
                ? IconButton(
              tooltip: 'Clear $label',
              onPressed: saving ? null : () => select(kind, null),
              icon: const Icon(Icons.clear),
            )
                : null,
          ).copyWith(labelText: label),
          items: [
            for (final item in items)
              DropdownMenuItem(
                value: item.uuid,
                child: Text(item.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: busy || errors[kind] != null || items.isEmpty
              ? null
              : (value) => select(kind, value),
          validator: (value) =>
          required && value == null ? 'Please select $kind.' : null,
        ),
        if (loading[kind] == true) const LinearProgressIndicator(),
        if (errors[kind] != null) ...[
          Text(
            errors[kind]!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: saving ? null : () => loadOptions(kind),
              child: Text('Retry $kind'),
            ),
          ),
        ] else if (loading[kind] != true && items.isEmpty)
          Text('No $kind options available.'),
      ]),
    );
  }

  Widget field(
      TextEditingController controller,
      String label, {
        int? maxLength,
        int lines = 1,
        bool obscure = false,
        String? Function(String?)? validator,
      }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          enabled: !saving,
          maxLength: maxLength,
          maxLines: lines,
          obscureText: obscure,
          decoration:
          adminFieldDecoration(context, hint: label).copyWith(labelText: label),
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
      onClose:
      saving || pickingDate ? null : () => Navigator.of(context).pop(),
      body: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            field(
              title,
              'Class title',
              maxLength: 255,
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Title is required.'
                  : null,
            ),
            field(description, 'Description', lines: 3),
            dropdown('course', 'Course', required: true),
            if (selected['course'] != null)
              dropdown('subject', 'Subject (optional)'),
            if (selected['subject'] != null)
              dropdown('chapter', 'Chapter (optional)'),
            if (selected['chapter'] != null)
              dropdown('lesson', 'Lesson (optional)'),
            dropdown('teacher', 'Teacher', required: true),
            for (final start in [true, false])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  start
                      ? 'Scheduled start (local time)'
                      : 'Scheduled end (local time)',
                ),
                subtitle: Text(_formatDateTime(start ? startAt : endAt)),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: saving || pickingDate ? null : () => pickDate(start),
              ),
            const SizedBox(height: 12),
            field(
              meetingUrl,
              'Meeting URL',
              maxLength: 1000,
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return null;
                final uri = Uri.tryParse(text);
                if (uri == null ||
                    !['http', 'https'].contains(uri.scheme) ||
                    uri.host.isEmpty) {
                  return 'Enter a valid http/https meeting URL.';
                }
                return null;
              },
            ),
            field(meetingId, 'Meeting ID', maxLength: 255),
            field(
              meetingPassword,
              'Meeting password',
              maxLength: 255,
              obscure: true,
            ),
            if (error != null)
              Text(
                error!,
                style:
                TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        AdminOutlineButton(
          label: 'Cancel',
          onPressed: saving || pickingDate
              ? null
              : () => Navigator.of(context).pop(),
        ),
        GradientButton(
          label: 'Schedule class',
          loading: saving,
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
    label: status.toUpperCase(),
    compact: true,
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