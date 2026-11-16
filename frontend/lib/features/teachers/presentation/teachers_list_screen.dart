import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';
import '../data/teacher.dart';
import '../data/teacher_repository.dart';

class TeachersListScreen extends ConsumerStatefulWidget {
  const TeachersListScreen({
    super.key,
  });

  @override
  ConsumerState<TeachersListScreen> createState() =>
      _TeachersListScreenState();
}

class _TeachersListScreenState extends ConsumerState<TeachersListScreen> {
  final searchController = TextEditingController();

  late Future<TeacherPage> result;

  String search = '';

  bool? activeFilter;

  String selectedDepartment = 'ALL';

  int page = 1;

  bool creating = false;

  @override
  void initState() {
    super.initState();

    reload();
  }

  void reload() {
    result = ref.read(teacherRepositoryProvider).list(
      search: search,
      isActive: activeFilter,
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
    final repository = ref.read(teacherRepositoryProvider);
    setState(() => creating = true);
    try {
      final created = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CreateTeacherDialog(repository),
      );
      if (!mounted || created != true) return;
      setState(() {
        searchController.clear();
        search = '';
        activeFilter = null;
        selectedDepartment = 'ALL';
        page = 1;
        reload();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teacher created successfully.')),
      );
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  void _setFilter(bool? value) {
    setState(() {
      activeFilter = value;
      page = 1;
      reload();
    });
  }

  void _resetFilters() {
    setState(() {
      searchController.clear();
      search = '';
      activeFilter = null;
      selectedDepartment = 'ALL';
      page = 1;
      reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top header matching screenshot ("Teachers" + refresh + "Add teacher")[cite: 6, 8]
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Text(
                  'Teachers',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: Color(0xFF334155),
                  ),
                  onPressed: refresh,
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: creating ? null : _openCreate,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Add teacher'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF3730A3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
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
            child: FutureBuilder<TeacherPage>(
              future: result,
              builder: (context, snapshot) {
                final state = adminFutureState(
                  snapshot,
                  noun: 'teachers',
                  onRetry: refresh,
                );
                final data = snapshot.connectionState == ConnectionState.done &&
                    !snapshot.hasError
                    ? snapshot.data
                    : null;
                final rows = data?.results ?? const <Teacher>[];
                final activeHere = rows.where((t) => t.isActive).length;
                final subjectsSet = rows
                    .map((t) => t.specialization.trim())
                    .where((v) => v.isNotEmpty)
                    .toSet();
                final subjects = subjectsSet.length;
                final avgExp = rows.isEmpty
                    ? 0
                    : (rows.fold<int>(0, (a, t) => a + t.experienceYears) /
                    rows.length)
                    .round();

                final departments = <String>[
                  'ALL',
                  ...subjectsSet.toList()..sort(),
                ];
                final activeDept = departments.contains(selectedDepartment)
                    ? selectedDepartment
                    : 'ALL';

                final filteredRows = activeDept == 'ALL'
                    ? rows
                    : rows
                    .where((t) => t.specialization.trim() == activeDept)
                    .toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  children: [
                    // 2x2 / Responsive KPI grid matching screenshot[cite: 6]
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
                              child: _TeacherStatCard(
                                label: search.isEmpty && activeFilter == null
                                    ? 'Total teachers'
                                    : 'Matching',
                                value: data == null ? '…' : '${data.count}',
                                caption: activeFilter == null
                                    ? 'All statuses'
                                    : activeFilter!
                                    ? 'Active filter'
                                    : 'Inactive filter',
                                icon: Icons.assignment_ind_outlined,
                                iconColor: const Color(0xFF4F46E5),
                                iconBg: const Color(0xFFEEF2FF),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _TeacherStatCard(
                                label: 'Active on page',
                                value: data == null ? '…' : '$activeHere',
                                caption: 'Live filter',
                                showLiveDot: true,
                                icon: Icons.verified_user_outlined,
                                iconColor: const Color(0xFF059669),
                                iconBg: const Color(0xFFECFDF5),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _TeacherStatCard(
                                label: 'Specializations',
                                value: data == null ? '…' : '$subjects',
                                caption: 'On this page',
                                icon: Icons.menu_book_outlined,
                                iconColor: const Color(0xFF4F46E5),
                                iconBg: const Color(0xFFEEF2FF),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _TeacherStatCard(
                                label: 'Avg. experience',
                                value: data == null ? '…' : '$avgExp',
                                valueSuffix: 'yrs',
                                caption: 'Campus average',
                                icon: Icons.workspace_premium_outlined,
                                iconColor: const Color(0xFF1D4ED8),
                                iconBg: const Color(0xFFEFF6FF),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Search bar with blue "Search" button matching screenshot[cite: 6]
                    _TeacherSearchBar(
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

                    // Status filter pills (ALL | ACTIVE | INACTIVE)[cite: 6, 8]
                    Row(
                      children: [
                        _StatusPill(
                          label: 'ALL',
                          selected: activeFilter == null,
                          onTap: () => _setFilter(null),
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(
                          label: 'ACTIVE',
                          selected: activeFilter == true,
                          onTap: () => _setFilter(true),
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(
                          label: 'INACTIVE',
                          selected: activeFilter == false,
                          onTap: () => _setFilter(false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Department / Specialization chip strip matching screenshot[cite: 6]
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final dept in departments) ...[
                            _DepartmentPill(
                              label: dept == 'ALL' ? 'All Departments' : dept,
                              selected: activeDept == dept,
                              onTap: () =>
                                  setState(() => selectedDepartment = dept),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (state != null)
                      state
                    else if (filteredRows.isEmpty)
                      _EmptyTeachersCard(
                        creating: creating,
                        onOnboard: _openCreate,
                        onReset: _resetFilters,
                      )
                    else ...[
                        for (final teacher in filteredRows) ...[
                          _TeacherDirectoryCard(
                            teacher: teacher,
                            onTap: () async {
                              await context.push('/teachers/${teacher.uuid}');
                              if (mounted) refresh();
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        AdminPager(
                          page: page,
                          pageSize: 20,
                          total: data!.count,
                          noun: 'teachers',
                          onPage: changePage,
                        ),
                      ],

                    const SizedBox(height: 16),

                    // Bottom Scheduling Tip card matching screenshot[cite: 6]
                    const _SchedulingTipCard(),
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

class _TeacherStatCard extends StatelessWidget {
  const _TeacherStatCard({
    required this.label,
    required this.value,
    this.valueSuffix,
    required this.caption,
    this.showLiveDot = false,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });

  final String label;
  final String value;
  final String? valueSuffix;
  final String caption;
  final bool showLiveDot;
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
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
              if (valueSuffix != null) ...[
                const SizedBox(width: 4),
                Text(
                  valueSuffix!,
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (showLiveDot) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF059669),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeacherSearchBar extends StatelessWidget {
  const _TeacherSearchBar({
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
                hintText: 'Search by name, employee ID or phone…',
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
          FilledButton(
            onPressed: onSearch,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Search',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
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
      color: selected ? const Color(0xFF3730A3) : const Color(0xFFEEF2FF),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: selected ? Colors.white : const Color(0xFF475569),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _DepartmentPill extends StatelessWidget {
  const _DepartmentPill({
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
      color: selected ? const Color(0xFFEEF2FF) : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
              selected ? const Color(0xFFC7D2FE) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3730A3),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected
                      ? const Color(0xFF3730A3)
                      : const Color(0xFF475569),
                  fontWeight:
                  selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTeachersCard extends StatelessWidget {
  const _EmptyTeachersCard({
    required this.creating,
    required this.onOnboard,
    required this.onReset,
  });

  final bool creating;
  final VoidCallback onOnboard;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF2FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 36,
                  color: Color(0xFF4338CA),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D4ED8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'No teachers found',
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              'Try another search or status filter, or onboard your first teacher to assign courses and timetables.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: const Color(0xFF64748B),
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: creating ? null : onOnboard,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text('Onboard New Faculty'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3730A3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reset active filters'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF475569),
              textStyle: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SchedulingTipCard extends StatelessWidget {
  const _SchedulingTipCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              size: 17,
              color: Color(0xFF3730A3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scheduling Tip',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    text: 'Assign teachers to courses in the ',
                    style: textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF64748B),
                      height: 1.4,
                    ),
                    children: const [
                      TextSpan(
                        text: 'Courses',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      TextSpan(
                        text:
                        ' tab to automate attendance sheets and timetable synchronization.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherDirectoryCard extends StatelessWidget {
  const _TeacherDirectoryCard({
    required this.teacher,
    required this.onTap,
  });

  final Teacher teacher;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final displayName =
    teacher.fullName.trim().isEmpty ? teacher.employeeId : teacher.fullName;
    final initials = adminInitials(displayName);

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
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3730A3),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              displayName,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                teacher.employeeId,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF3730A3),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          teacher.specialization.isEmpty
                              ? 'No specialization'
                              : teacher.specialization,
                          style: textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: teacher.isActive
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: teacher.isActive
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFDC2626),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          teacher.isActive ? 'Active' : 'Inactive',
                          style: textTheme.labelSmall?.copyWith(
                            color: teacher.isActive
                                ? const Color(0xFF15803D)
                                : const Color(0xFFB91C1C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.workspace_premium_outlined,
                      size: 14,
                      color: Color(0xFF3730A3),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${teacher.experienceYears} yrs',
                      style: textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF1E293B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (teacher.phone.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '•',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ),
                      const Icon(
                        Icons.call_outlined,
                        size: 14,
                        color: Color(0xFF1D4ED8),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          teacher.phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF475569),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEEF2FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Color(0xFF3730A3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateTeacherDialog extends StatefulWidget {
  const _CreateTeacherDialog(
      this.repository,
      );

  final TeacherRepository repository;

  @override
  State<_CreateTeacherDialog> createState() => _CreateTeacherDialogState();
}

class _CreateTeacherDialogState extends State<_CreateTeacherDialog> {
  final formKey = GlobalKey<FormState>();
  final employeeId = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final qualification = TextEditingController();
  final specialization = TextEditingController();
  final experience = TextEditingController(text: '0');
  final address = TextEditingController();

  bool saving = false;
  String? error;

  @override
  void dispose() {
    employeeId.dispose();
    firstName.dispose();
    lastName.dispose();
    email.dispose();
    phone.dispose();
    qualification.dispose();
    specialization.dispose();
    experience.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    if (!(formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final years = int.parse(experience.text.trim());
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.repository.create(
        employeeId: employeeId.text,
        firstName: firstName.text,
        lastName: lastName.text,
        email: email.text,
        phone: phone.text,
        qualification: qualification.text,
        specialization: specialization.text,
        experienceYears: years,
        address: address.text,
      );
      if (!mounted) return;
      setState(() => saving = false);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not create teacher. Please try again.');
      }
    } finally {
      if (mounted && saving) setState(() => saving = false);
    }
  }

  Widget field({
    required String label,
    required TextEditingController controller,
    bool mandatory = false,
    int? maxLength,
    int maxLines = 1,
    TextInputType? keyboardType,
    FormFieldValidator<String>? validator,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return FieldLabel(
      label: label,
      required: mandatory,
      child: TextFormField(
        controller: controller,
        enabled: !saving,
        maxLength: maxLength,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autocorrect: keyboardType != TextInputType.emailAddress,
        decoration: adminFieldDecoration(
          context,
          hint: mandatory ? 'Enter ${label.toLowerCase()}' : 'Optional',
        ),
        validator: validator ?? (mandatory ? requiredField : null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AdminFormDialog(
      icon: Icons.person_add_alt_1_rounded,
      title: 'Add teacher',
      subtitle: 'Create a teacher record for your academy.',
      onClose: saving ? null : () => Navigator.of(context).pop(),
      body: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            field(
              label: 'Employee ID',
              controller: employeeId,
              mandatory: true,
              maxLength: 50,
            ),
            const SizedBox(height: 16),
            FormRow(
              left: field(
                label: 'First name',
                controller: firstName,
                mandatory: true,
                maxLength: 100,
              ),
              right: field(
                label: 'Last name',
                controller: lastName,
                maxLength: 100,
              ),
            ),
            const SizedBox(height: 16),
            field(
              label: 'Email',
              controller: email,
              maxLength: 254,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return null;
                return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                    .hasMatch(text)
                    ? null
                    : 'Enter a valid email';
              },
            ),
            const SizedBox(height: 16),
            field(
              label: 'Phone',
              controller: phone,
              maxLength: 20,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            field(
              label: 'Qualification',
              controller: qualification,
              maxLength: 255,
            ),
            const SizedBox(height: 16),
            field(
              label: 'Specialization',
              controller: specialization,
              maxLength: 255,
            ),
            const SizedBox(height: 16),
            field(
              label: 'Experience years',
              controller: experience,
              mandatory: true,
              keyboardType: TextInputType.number,
              validator: (value) {
                final years = int.tryParse((value ?? '').trim());
                return years == null || years < 0
                    ? 'Enter a whole number, 0 or greater'
                    : null;
              },
            ),
            const SizedBox(height: 16),
            field(
              label: 'Address',
              controller: address,
              maxLines: 3,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              AdminErrorBanner(message: error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        GradientButton(
          label: 'Save teacher',
          icon: Icons.check_rounded,
          loading: saving,
          onPressed: saving ? null : save,
        ),
      ],
    ),
  );
}

String? requiredField(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;