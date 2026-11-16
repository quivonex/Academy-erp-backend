import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/status_pill.dart';
import '../../courses/data/course.dart';
import '../../courses/data/course_repository.dart';
import '../../students/data/student.dart';
import '../../students/data/student_repository.dart';
import '../data/enrollment.dart';
import '../data/enrollment_repository.dart';

class EnrollmentsListScreen extends ConsumerStatefulWidget {
  const EnrollmentsListScreen({
    super.key,
  });

  @override
  ConsumerState<EnrollmentsListScreen> createState() =>
      _EnrollmentsListScreenState();
}

class _EnrollmentsListScreenState
    extends ConsumerState<EnrollmentsListScreen> {
  final searchController = TextEditingController();
  late Future<EnrollmentPage> result;
  String search = '';
  String statusFilter = 'ALL'; // ALL | ACTIVE | EXPIRING
  int page = 1;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    result = ref
        .read(
      enrollmentManagementRepositoryProvider,
    )
        .list(
      page: page,
    );
  }

  void refresh() {
    setState(reload);
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

  Future<void> addEnrollment() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _CreateEnrollmentDialog(),
    );

    if (created == true && mounted) {
      setState(() {
        page = 1;
        reload();
      });
    }
  }

  Future<void> _openBulk() async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => const _BulkEnrollmentDialog(),
    );
    if (done == true && mounted) {
      setState(() {
        page = 1;
        reload();
      });
    }
  }

  String _date(DateTime? value) {
    if (value == null) return '';
    const months = [
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
    final d = value.toLocal();
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  bool _isExpiringSoon(Enrollment e, DateTime now) {
    final end = e.accessEndAt;
    return end != null &&
        end.isAfter(now) &&
        end.difference(now).inDays <= 30;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top header matching screenshot ("Enrollments" + refresh + "+ Enroll")
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Text(
                  'Enrollments',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: refresh,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: Color(0xFF334155),
                  ),
                  tooltip: 'Refresh',
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: addEnrollment,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Enroll'),
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

          const SizedBox(height: 12),

          // Quick action strip ("Bulk assign", "Chapter video access")
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _QuickActionChip(
                  icon: Icons.group_add_outlined,
                  label: 'Bulk assign',
                  onTap: _openBulk,
                ),
                const SizedBox(width: 10),
                _QuickActionChip(
                  icon: Icons.video_library_outlined,
                  label: 'Chapter video access',
                  onTap: () async {
                    final granted = await context.push<bool>(
                      '/enrollments/video-access',
                    );
                    if (granted == true && mounted) {
                      refresh();
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: FutureBuilder<EnrollmentPage>(
              future: result,
              builder: (context, snapshot) {
                final state = adminFutureState(
                  snapshot,
                  noun: 'enrollments',
                  onRetry: refresh,
                );
                final data = snapshot.data;
                final rows = data?.results ?? const <Enrollment>[];
                final active =
                    rows.where((e) => e.status.toUpperCase() == 'ACTIVE').length;
                final now = DateTime.now();
                final endingSoon =
                    rows.where((e) => _isExpiringSoon(e, now)).length;
                final coursesSet = rows
                    .map((e) => e.courseName.trim().isNotEmpty
                    ? e.courseName.trim()
                    : e.courseCode.trim())
                    .where((v) => v.isNotEmpty)
                    .toSet();
                final coursesCount = rows.map((e) => e.courseCode).toSet().length;
                final coursesCaption = coursesSet.isEmpty
                    ? 'On this page'
                    : coursesSet.take(2).join(', ');
                final activePct = data == null || rows.isEmpty
                    ? null
                    : '${(active * 100 / rows.length).round()}% active';
                final totalPages = data == null || data.count == 0
                    ? 1
                    : ((data.count - 1) ~/ 20) + 1;

                final query = search.trim().toLowerCase();
                final filteredRows = rows.where((e) {
                  final matchesFilter = switch (statusFilter) {
                    'ACTIVE' => e.status.toUpperCase() == 'ACTIVE',
                    'EXPIRING' => _isExpiringSoon(e, now),
                    _ => true,
                  };
                  if (!matchesFilter) return false;
                  if (query.isEmpty) return true;
                  return e.studentName.toLowerCase().contains(query) ||
                      e.admissionNumber.toLowerCase().contains(query) ||
                      e.courseName.toLowerCase().contains(query) ||
                      e.courseCode.toLowerCase().contains(query);
                }).toList();

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
                              child: _EnrollmentStatCard(
                                label: 'Total enrollments',
                                value: data == null ? '…' : '${data.count}',
                                caption: 'Academy records',
                                showDot: true,
                                dotColor: const Color(0xFF3730A3),
                                icon: Icons.how_to_reg_outlined,
                                iconColor: const Color(0xFF4F46E5),
                                iconBg: const Color(0xFFEEF2FF),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _EnrollmentStatCard(
                                label: 'Active on page',
                                value: data == null ? '…' : '$active',
                                caption: activePct ?? 'Live status',
                                captionColor: const Color(0xFF059669),
                                showDot: true,
                                dotColor: const Color(0xFF059669),
                                icon: Icons.verified_rounded,
                                iconColor: const Color(0xFF059669),
                                iconBg: const Color(0xFFECFDF5),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _EnrollmentStatCard(
                                label: 'Ending ≤ 30 days',
                                value: data == null ? '…' : '$endingSoon',
                                caption: 'On this page',
                                icon: Icons.hourglass_bottom_rounded,
                                iconColor: const Color(0xFF1D4ED8),
                                iconBg: const Color(0xFFEFF6FF),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _EnrollmentStatCard(
                                label: 'Courses on page',
                                value: data == null ? '…' : '$coursesCount',
                                caption: coursesCaption,
                                icon: Icons.menu_book_outlined,
                                iconColor: const Color(0xFF4F46E5),
                                iconBg: const Color(0xFFEEF2FF),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Search bar matching screenshot
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
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
                              controller: searchController,
                              onChanged: (value) =>
                                  setState(() => search = value),
                              decoration: const InputDecoration(
                                hintText: 'Search student, course, or ID...',
                                hintStyle: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding:
                                EdgeInsets.symmetric(vertical: 11),
                              ),
                            ),
                          ),
                          if (search.isNotEmpty)
                            IconButton(
                              onPressed: () {
                                searchController.clear();
                                setState(() => search = '');
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Color(0xFF94A3B8),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Filter chips ("All", "Active", "Expiring soon")
                    if (data != null) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _EnrollmentFilterPill(
                              label: 'All (${rows.length})',
                              selected: statusFilter == 'ALL',
                              onTap: () =>
                                  setState(() => statusFilter = 'ALL'),
                            ),
                            const SizedBox(width: 8),
                            _EnrollmentFilterPill(
                              label: 'Active ($active)',
                              selected: statusFilter == 'ACTIVE',
                              onTap: () =>
                                  setState(() => statusFilter = 'ACTIVE'),
                            ),
                            const SizedBox(width: 8),
                            _EnrollmentFilterPill(
                              label: 'Expiring soon ($endingSoon)',
                              selected: statusFilter == 'EXPIRING',
                              onTap: () =>
                                  setState(() => statusFilter = 'EXPIRING'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Section header ("Enrollment Records" + count badge + Page X of Y)
                      Row(
                        children: [
                          Text(
                            'Enrollment Records',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${data.count} records',
                              style: textTheme.labelSmall?.copyWith(
                                color: const Color(0xFF3730A3),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Page $page of $totalPages',
                            style: textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (state != null)
                      state
                    else if (rows.isEmpty)
                      AdminStateMessage(
                        icon: Icons.how_to_reg_outlined,
                        title: 'No enrollments yet',
                        message: 'Enroll a student into a course to get started.',
                        actionLabel: 'Enroll student',
                        onAction: addEnrollment,
                      )
                    else if (filteredRows.isEmpty)
                        AdminStateMessage(
                          icon: Icons.search_off_rounded,
                          title: 'No matching enrollments',
                          message: 'Try clearing your search or filter.',
                          actionLabel: 'Reset',
                          onAction: () {
                            searchController.clear();
                            setState(() {
                              search = '';
                              statusFilter = 'ALL';
                            });
                          },
                        )
                      else ...[
                          for (final enrollment in filteredRows) ...[
                            _EnrollmentRecordCard(
                              enrollment: enrollment,
                              enrolledText: _date(enrollment.enrolledAt),
                              accessUntilText: _date(enrollment.accessEndAt),
                              onTap: () async {
                                await context.push(
                                  '/enrollments/${enrollment.uuid}',
                                );
                                if (mounted) refresh();
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          AdminPager(
                            page: page,
                            pageSize: 20,
                            total: data!.count,
                            noun: 'enrollments',
                            onPage: changePage,
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

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: const Color(0xFF334155),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnrollmentStatCard extends StatelessWidget {
  const _EnrollmentStatCard({
    required this.label,
    required this.value,
    required this.caption,
    this.captionColor = const Color(0xFF64748B),
    this.showDot = false,
    this.dotColor = const Color(0xFF64748B),
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });

  final String label;
  final String value;
  final String caption;
  final Color captionColor;
  final bool showDot;
  final Color dotColor;
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
          Row(
            children: [
              if (showDot) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: dotColor,
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
                    color: captionColor,
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

class _EnrollmentFilterPill extends StatelessWidget {
  const _EnrollmentFilterPill({
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
              selected ? const Color(0xFF3730A3) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected ? Colors.white : const Color(0xFF475569),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _EnrollmentRecordCard extends StatelessWidget {
  const _EnrollmentRecordCard({
    required this.enrollment,
    required this.enrolledText,
    required this.accessUntilText,
    required this.onTap,
  });

  final Enrollment enrollment;
  final String enrolledText;
  final String accessUntilText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final initials = adminInitials(enrollment.studentName);
    final isActive = enrollment.status.toUpperCase() == 'ACTIVE';

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
              // Top row: Avatar + Student Name/Admission/Course + Status Pill
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFF3730A3),
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
                        Text(
                          enrollment.studentName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        if (enrollment.admissionNumber.isNotEmpty) ...[
                          const SizedBox(height: 4),
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
                              enrollment.admissionNumber,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF3730A3),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 5),
                        Text(
                          '${enrollment.courseName} (${enrollment.courseCode})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF1D4ED8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusPill(
                    label: enrollment.status.toUpperCase(),
                    tone: toneForStatus(enrollment.status),
                    compact: true,
                  ),
                ],
              ),

              if (enrolledText.isNotEmpty || accessUntilText.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      if (enrolledText.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: Color(0xFF1D4ED8),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Enrolled $enrolledText',
                              style: textTheme.labelMedium?.copyWith(
                                color: const Color(0xFF1E293B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      if (accessUntilText.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lock_outline_rounded,
                              size: 13,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Access until $accessUntilText',
                              style: textTheme.labelMedium?.copyWith(
                                color: const Color(0xFF475569),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Bottom action link matching screenshot ("Manage Access >")
              Row(
                children: [
                  Expanded(
                    child: Text(
                      enrollment.courseCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Manage Access',
                        style: textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Color(0xFF1D4ED8),
                      ),
                    ],
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

class _CreateEnrollmentDialog extends ConsumerStatefulWidget {
  const _CreateEnrollmentDialog();

  @override
  ConsumerState<_CreateEnrollmentDialog> createState() =>
      _CreateEnrollmentDialogState();
}

class _CreateEnrollmentDialogState
    extends ConsumerState<_CreateEnrollmentDialog> {
  Student? selectedStudent;
  Course? selectedCourse;
  String status = 'ACTIVE';

  List<Student> students = [];
  List<Course> courses = [];

  bool loadingStudents = false;
  bool loadingCourses = false;
  bool saving = false;

  String? error;

  @override
  void initState() {
    super.initState();
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    if (!mounted) return;
    setState(() {
      loadingStudents = true;
      loadingCourses = true;
    });

    try {
      final loadedStudents = <Student>[];
      final loadedCourses = <Course>[];
      final studentRepository = ref.read(studentRepositoryProvider);
      final courseRepository = ref.read(courseRepositoryProvider);
      Future<void> loadStudents() async {
        var page = 1;
        while (mounted) {
          final response = await studentRepository.list(page: page);
          loadedStudents.addAll(response.results);
          if (response.results.isEmpty ||
              loadedStudents.length >= response.count) {
            break;
          }
          page++;
        }
      }

      Future<void> loadCourses() async {
        var page = 1;
        while (mounted) {
          final response = await courseRepository.list(page: page);
          loadedCourses.addAll(response.results);
          if (response.results.isEmpty ||
              loadedCourses.length >= response.count) {
            break;
          }
          page++;
        }
      }

      await Future.wait([loadStudents(), loadCourses()]);

      if (mounted) {
        setState(() {
          students = loadedStudents;
          courses = loadedCourses;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Could not load students or courses: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          loadingStudents = false;
          loadingCourses = false;
        });
      }
    }
  }

  Future<void> save() async {
    if (selectedStudent == null) {
      setState(() {
        error = 'Please select a student.';
      });
      return;
    }

    if (selectedCourse == null) {
      setState(() {
        error = 'Please select a course.';
      });
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await ref.read(enrollmentManagementRepositoryProvider).create(
        studentUuid: selectedStudent!.uuid,
        courseUuid: selectedCourse!.uuid,
        status: status,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enroll Student'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                key: ValueKey('student_dd_${students.length}'),
                value: students.any((s) => s.uuid == selectedStudent?.uuid)
                    ? selectedStudent?.uuid
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Student',
                ),
                items: students
                    .map(
                      (student) => DropdownMenuItem<String>(
                    value: student.uuid,
                    child: Text(
                      '${student.fullName} (${student.admissionNumber})',
                    ),
                  ),
                )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selectedStudent =
                        students.firstWhere((s) => s.uuid == value);
                    error = null;
                  });
                },
              ),
              if (loadingStudents) const LinearProgressIndicator(),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                isExpanded: true,
                key: ValueKey('course_dd_${courses.length}'),
                value: courses.any((c) => c.uuid == selectedCourse?.uuid)
                    ? selectedCourse?.uuid
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Course',
                ),
                items: courses
                    .map(
                      (course) => DropdownMenuItem<String>(
                    value: course.uuid,
                    child: Text('${course.name} (${course.code})'),
                  ),
                )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selectedCourse =
                        courses.firstWhere((c) => c.uuid == value);
                    error = null;
                  });
                },
              ),
              if (loadingCourses) const LinearProgressIndicator(),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: status,
                decoration: const InputDecoration(
                  labelText: 'Enrollment Status',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'ACTIVE',
                    child: Text('Active'),
                  ),
                  DropdownMenuItem(
                    value: 'PENDING',
                    child: Text('Pending'),
                  ),
                  DropdownMenuItem(
                    value: 'COMPLETED',
                    child: Text('Completed'),
                  ),
                  DropdownMenuItem(
                    value: 'CANCELLED',
                    child: Text('Cancelled'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    status = value ?? 'ACTIVE';
                  });
                },
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving || loadingStudents || loadingCourses ? null : save,
          child: Text(
            saving ? 'Enrolling...' : 'Enroll Student',
          ),
        ),
      ],
    );
  }
}

class _BulkEnrollmentDialog extends ConsumerStatefulWidget {
  const _BulkEnrollmentDialog();

  @override
  ConsumerState<_BulkEnrollmentDialog> createState() =>
      _BulkEnrollmentDialogState();
}

class _BulkEnrollmentDialogState
    extends ConsumerState<_BulkEnrollmentDialog> {
  List<Course> courses = [];

  Course? selectedCourse;

  DateTime? joinedDateFrom;
  DateTime? joinedDateTo;

  bool grantAccess = true;

  DateTime? accessStartAt;
  DateTime? accessEndAt;

  bool loadingCourses = false;
  bool saving = false;

  String? error;

  Map<String, dynamic>? result;

  @override
  void initState() {
    super.initState();
    loadCourses();
  }

  Future<void> loadCourses() async {
    setState(() {
      loadingCourses = true;
    });

    try {
      final loadedCourses = <Course>[];
      final repository = ref.read(courseRepositoryProvider);
      int nextPage = 1;
      while (true) {
        final response = await repository.list(page: nextPage);
        loadedCourses.addAll(response.results);
        if (response.results.isEmpty ||
            loadedCourses.length >= response.count) {
          break;
        }
        nextPage++;
      }
      if (!mounted) return;
      setState(() {
        courses = loadedCourses;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = 'Could not load courses: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          loadingCourses = false;
        });
      }
    }
  }

  Future<DateTime?> pickDate(
      DateTime? current,
      ) async {
    return showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
  }

  Future<DateTime?> pickDateTime(
      DateTime? current,
      ) async {
    final initial = current ?? DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (date == null || !mounted) {
      return null;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        initial,
      ),
    );

    if (time == null) {
      return null;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> submit() async {
    if (selectedCourse == null) {
      setState(() {
        error = 'Please select a course.';
      });

      return;
    }

    if (joinedDateFrom == null) {
      setState(() {
        error = 'Student Admission Date From is required.';
      });

      return;
    }

    if (joinedDateTo != null && joinedDateTo!.isBefore(joinedDateFrom!)) {
      setState(() {
        error = 'Joined Date To must be on or after Joined Date From.';
      });

      return;
    }

    if (grantAccess &&
        accessStartAt != null &&
        accessEndAt != null &&
        !accessEndAt!.isAfter(accessStartAt!)) {
      setState(() {
        error = 'Access end time must be after access start time.';
      });

      return;
    }

    setState(() {
      saving = true;
      error = null;
      result = null;
    });

    try {
      final response = await ref
          .read(
        enrollmentManagementRepositoryProvider,
      )
          .bulkAssignByAdmissionDate(
        courseUuid: selectedCourse!.uuid,
        joinedDateFrom: joinedDateFrom!,
        joinedDateTo: joinedDateTo,
        grantAccess: grantAccess,
        accessStartAt: grantAccess ? accessStartAt : null,
        accessEndAt: grantAccess ? accessEndAt : null,
      );

      if (!mounted) return;

      setState(() {
        result = response;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  String formatDate(
      DateTime? value,
      ) {
    if (value == null) {
      return 'Not selected';
    }

    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  String formatDateTime(
      DateTime? value,
      ) {
    if (value == null) {
      return 'Not selected';
    }

    return '${formatDate(value)} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return AlertDialog(
      title: const Text('Bulk Assign Course'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                key: ValueKey('bulk_course_dd_${courses.length}'),
                value: courses.any((c) => c.uuid == selectedCourse?.uuid)
                    ? selectedCourse?.uuid
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Course *',
                ),
                items: courses
                    .map(
                      (course) => DropdownMenuItem<String>(
                    value: course.uuid,
                    child: Text(
                      '${course.name} (${course.code})',
                    ),
                  ),
                )
                    .toList(),
                onChanged: loadingCourses
                    ? null
                    : (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    selectedCourse = courses.firstWhere(
                          (c) => c.uuid == value,
                    );

                    error = null;
                  });
                },
              ),
              if (loadingCourses) const LinearProgressIndicator(),
              const SizedBox(
                height: 16,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Student Admission Date From *',
                ),
                subtitle: Text(
                  formatDate(
                    joinedDateFrom,
                  ),
                ),
                trailing: const Icon(
                  Icons.calendar_month_outlined,
                ),
                onTap: () async {
                  final value = await pickDate(
                    joinedDateFrom,
                  );

                  if (value != null && mounted) {
                    setState(() {
                      joinedDateFrom = value;
                    });
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Student Admission Date To',
                ),
                subtitle: Text(
                  formatDate(
                    joinedDateTo,
                  ),
                ),
                trailing: const Icon(
                  Icons.calendar_month_outlined,
                ),
                onTap: () async {
                  final value = await pickDate(
                    joinedDateTo,
                  );

                  if (value != null && mounted) {
                    setState(() {
                      joinedDateTo = value;
                    });
                  }
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Grant Access',
                ),
                subtitle: const Text(
                  'Create active course access for matched students',
                ),
                value: grantAccess,
                onChanged: (value) {
                  setState(() {
                    grantAccess = value;
                  });
                },
              ),
              if (grantAccess) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Access Start',
                  ),
                  subtitle: Text(
                    formatDateTime(
                      accessStartAt,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.schedule,
                  ),
                  onTap: () async {
                    final value = await pickDateTime(
                      accessStartAt,
                    );

                    if (value != null && mounted) {
                      setState(() {
                        accessStartAt = value;
                      });
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Access End',
                  ),
                  subtitle: Text(
                    formatDateTime(
                      accessEndAt,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.event_available,
                  ),
                  onTap: () async {
                    final value = await pickDateTime(
                      accessEndAt,
                    );

                    if (value != null && mounted) {
                      setState(() {
                        accessEndAt = value;
                      });
                    }
                  },
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(
                    top: 12,
                  ),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.error,
                    ),
                  ),
                ),
              if (result != null) ...[
                const SizedBox(
                  height: 18,
                ),
                const Divider(),
                const SizedBox(
                  height: 8,
                ),
                Text(
                  'Bulk Enrollment Result',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium,
                ),
                const SizedBox(
                  height: 12,
                ),
                Text(
                  'Course: ${result!['course_name'] ?? '-'}',
                ),
                Text(
                  'Matched Students: ${result!['matched_students_count'] ?? 0}',
                ),
                Text(
                  'Created Enrollments: ${result!['created_enrollments_count'] ?? 0}',
                ),
                Text(
                  'Skipped Students: ${result!['skipped_students_count'] ?? 0}',
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving
              ? null
              : () {
            Navigator.pop(
              context,
              result != null,
            );
          },
          child: Text(
            result == null ? 'Cancel' : 'Close',
          ),
        ),
        if (result == null)
          FilledButton.icon(
            onPressed: saving || loadingCourses ? null : submit,
            icon: saving
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(
              Icons.group_add,
            ),
            label: Text(
              saving ? 'Assigning...' : 'Assign Course',
            ),
          ),
      ],
    );
  }
}