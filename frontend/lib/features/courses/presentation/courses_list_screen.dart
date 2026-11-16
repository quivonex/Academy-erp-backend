import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../course_categories/data/course_category.dart';
import '../../course_categories/data/course_category_repository.dart';
import '../data/course.dart';
import '../data/course_repository.dart';

class CoursesListScreen extends ConsumerStatefulWidget {
  const CoursesListScreen({super.key});

  @override
  ConsumerState<CoursesListScreen> createState() => _CoursesListScreenState();
}

class _CoursesListScreenState extends ConsumerState<CoursesListScreen> {
  final searchController = TextEditingController();
  late Future<CoursePage> result;
  String search = '';
  String filterTab = 'ALL'; // ALL | PUBLISHED | ONLINE | HYBRID
  int page = 1;
  bool creating = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    result =
        ref.read(courseRepositoryProvider).list(search: search, page: page);
  }

  void goToPage(int next) {
    setState(() {
      page = next;
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
      final created = await showDialog<Course>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const CreateCourseDialog(),
      );
      if (!mounted || created == null) return;
      setState(() {
        searchController.clear();
        search = '';
        filterTab = 'ALL';
        page = 1;
        reload();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Draft saved. Add content, preview and publish when ready.',
          ),
        ),
      );
      await context.push('/courses/${created.uuid}');
      if (mounted) setState(reload);
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  String _mode(String raw) {
    final v = raw.replaceAll('_', ' ').toLowerCase();
    return v.isEmpty ? 'Course' : v[0].toUpperCase() + v.substring(1);
  }

  IconData _modeIcon(String raw) {
    switch (raw.toUpperCase()) {
      case 'HYBRID':
        return Icons.laptop_mac_rounded;
      case 'OFFLINE':
        return Icons.apartment_rounded;
      default:
        return Icons.desktop_windows_outlined;
    }
  }

  void applySearch() {
    setState(() {
      search = searchController.text.trim();
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
          // Top header matching screenshot ("Courses" + active badge + refresh + "+ Add course")
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: FutureBuilder<CoursePage>(
              future: result,
              builder: (context, snapshot) {
                final rows = snapshot.connectionState == ConnectionState.done &&
                    !snapshot.hasError &&
                    snapshot.data != null
                    ? snapshot.data!.results
                    : const <Course>[];
                final activeCount = rows.where((c) => c.isPublished).length;

                final activeBadge = Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    snapshot.connectionState == ConnectionState.done &&
                            !snapshot.hasError &&
                            snapshot.data != null
                        ? '$activeCount active'
                        : '…',
                    style: textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF3730A3),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );

                final refreshButton = IconButton(
                  onPressed: () => setState(reload),
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: Color(0xFF334155),
                  ),
                  tooltip: 'Refresh',
                  visualDensity: VisualDensity.compact,
                );

                final addCourseButton = FilledButton.icon(
                  onPressed: creating ? null : _openCreate,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add course'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF3730A3),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 46),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final mobile = constraints.maxWidth < 520;

                    final titleAndControls = Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Courses',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        activeBadge,
                        const SizedBox(width: 2),
                        refreshButton,
                      ],
                    );

                    if (mobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          titleAndControls,
                          const SizedBox(height: 12),
                          SizedBox(width: double.infinity, child: addCourseButton),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: titleAndControls),
                        const SizedBox(width: 16),
                        addCourseButton,
                      ],
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: FutureBuilder<CoursePage>(
              future: result,
              builder: (context, snapshot) {
                final state = adminFutureState(
                  snapshot,
                  noun: 'courses',
                  onRetry: () => setState(reload),
                );
                final data = snapshot.connectionState == ConnectionState.done &&
                    !snapshot.hasError
                    ? snapshot.data
                    : null;
                final rows = data?.results ?? const <Course>[];
                final published = rows.where((c) => c.isPublished).length;
                final featured = rows.where((c) => c.isFeatured).length;
                final online = rows.where((c) => c.isPurchasableOnline).length;
                final onlineModeCount = rows
                    .where((c) => c.deliveryMode.toUpperCase() == 'ONLINE')
                    .length;
                final hybridModeCount = rows
                    .where((c) => c.deliveryMode.toUpperCase() == 'HYBRID')
                    .length;

                final visibleCourses = switch (filterTab) {
                  'PUBLISHED' => rows.where((c) => c.isPublished).toList(),
                  'ONLINE' => rows
                      .where((c) => c.deliveryMode.toUpperCase() == 'ONLINE')
                      .toList(),
                  'HYBRID' => rows
                      .where((c) => c.deliveryMode.toUpperCase() == 'HYBRID')
                      .toList(),
                  _ => rows,
                };

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
                        final draftsCount = rows.length - published;

                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: _CourseStatCard(
                                label: search.isEmpty
                                    ? 'Total courses'
                                    : 'Matching',
                                value: data == null ? '…' : '${data.count}',
                                caption: 'All academy wings',
                                icon: Icons.menu_book_outlined,
                                iconColor: const Color(0xFF4F46E5),
                                iconBg: const Color(0xFFEEF2FF),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _CourseStatCard(
                                label: 'Published',
                                value: data == null ? '…' : '$published',
                                valueColor: const Color(0xFF059669),
                                caption: data == null
                                    ? '…'
                                    : '$draftsCount drafts pending',
                                icon: Icons.public_rounded,
                                iconColor: const Color(0xFF059669),
                                iconBg: const Color(0xFFECFDF5),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _CourseStatCard(
                                label: 'Featured',
                                value: data == null ? '…' : '$featured',
                                valueColor: const Color(0xFF1D4ED8),
                                caption: 'Highlighted banner',
                                icon: Icons.star_border_rounded,
                                iconColor: const Color(0xFF1D4ED8),
                                iconBg: const Color(0xFFEFF6FF),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _CourseStatCard(
                                label: 'Explore Listed',
                                value: data == null ? '…' : '$online',
                                caption: 'In public app feed',
                                icon: Icons.storefront_outlined,
                                iconColor: const Color(0xFF4F46E5),
                                iconBg: const Color(0xFFEEF2FF),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Search bar with blue "Search" button
                    _CourseSearchBar(
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

                    // Filter pill strip ("All", "Published", "Online", "Hybrid")
                    if (data != null) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _CourseFilterPill(
                              label: 'All (${rows.length})',
                              selected: filterTab == 'ALL',
                              onTap: () => setState(() => filterTab = 'ALL'),
                            ),
                            const SizedBox(width: 8),
                            _CourseFilterPill(
                              label: 'Published ($published)',
                              selected: filterTab == 'PUBLISHED',
                              onTap: () =>
                                  setState(() => filterTab = 'PUBLISHED'),
                            ),
                            const SizedBox(width: 8),
                            _CourseFilterPill(
                              label: 'Online ($onlineModeCount)',
                              selected: filterTab == 'ONLINE',
                              onTap: () => setState(() => filterTab = 'ONLINE'),
                            ),
                            const SizedBox(width: 8),
                            _CourseFilterPill(
                              label: 'Hybrid ($hybridModeCount)',
                              selected: filterTab == 'HYBRID',
                              onTap: () => setState(() => filterTab = 'HYBRID'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    if (state != null)
                      state
                    else if (visibleCourses.isEmpty)
                      AdminStateMessage(
                        icon: Icons.auto_stories_outlined,
                        title: 'No courses found',
                        message: search.isEmpty
                            ? 'Add your first course to the catalogue.'
                            : 'Try a different search or filter.',
                      )
                    else ...[
                        for (final course in visibleCourses) ...[
                          _CourseCatalogueCard(
                            course: course,
                            modeLabel: _mode(course.deliveryMode),
                            modeIcon: _modeIcon(course.deliveryMode),
                            onTap: () async {
                              await context.push('/courses/${course.uuid}');
                              if (mounted) setState(reload);
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        AdminPager(
                          page: page,
                          pageSize: 20,
                          total: data!.count,
                          noun: 'courses',
                          onPage: goToPage,
                        ),
                      ],

                    const SizedBox(height: 14),

                    // Bottom Public Portal Sync status card matching screenshot
                    _PublicPortalSyncCard(
                      publishedCount: published,
                    ),
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

class _CourseStatCard extends StatelessWidget {
  const _CourseStatCard({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF0F172A),
    required this.caption,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });

  final String label;
  final String value;
  final Color valueColor;
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
                color: valueColor,
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

class _CourseSearchBar extends StatelessWidget {
  const _CourseSearchBar({
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
                hintText: 'Search by course name or code...',
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
              backgroundColor: const Color(0xFF3730A3),
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

class _CourseFilterPill extends StatelessWidget {
  const _CourseFilterPill({
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

class _CourseCatalogueCard extends StatelessWidget {
  const _CourseCatalogueCard({
    required this.course,
    required this.modeLabel,
    required this.modeIcon,
    required this.onTap,
  });

  final Course course;
  final String modeLabel;
  final IconData modeIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final avatarText = adminInitials(course.code);

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
              // Top row: Avatar + Course title/featured/subtitle/code + Price & Published pill
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: course.isFeatured
                          ? const Color(0xFF3730A3)
                          : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      avatarText,
                      style: TextStyle(
                        color: course.isFeatured
                            ? Colors.white
                            : const Color(0xFF3730A3),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        if (course.isFeatured) ...[
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.star_rounded,
                                  size: 12,
                                  color: Color(0xFF1D4ED8),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Featured',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (course.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            course.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            course.code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${course.price}',
                        style: jakarta(
                          textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: course.isPublished
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: course.isPublished
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF64748B),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              course.isPublished ? 'Published' : 'Draft',
                              style: textTheme.labelSmall?.copyWith(
                                color: course.isPublished
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFF475569),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Bottom soft strip with mode, category, duration & chevron
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      modeIcon,
                      size: 14,
                      color: const Color(0xFF475569),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      modeLabel,
                      style: textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((course.categoryName ?? '').isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '•',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ),
                      const Icon(
                        Icons.record_voice_over_outlined,
                        size: 14,
                        color: Color(0xFF475569),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          course.categoryName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF334155),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    if (course.durationMonths != null) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '•',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ),
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: Color(0xFF475569),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${course.durationMonths} months',
                        style: textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF334155),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Color(0xFF94A3B8),
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

class _PublicPortalSyncCard extends StatelessWidget {
  const _PublicPortalSyncCard({required this.publishedCount});

  final int publishedCount;

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
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              size: 18,
              color: Color(0xFF3730A3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Public Portal Sync: Live',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'All $publishedCount active courses are visible on mobile explorer apps.',
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                    height: 1.4,
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

class CreateCourseDialog extends ConsumerStatefulWidget {
  const CreateCourseDialog({super.key});

  @override
  ConsumerState<CreateCourseDialog> createState() => CreateCourseDialogState();
}

class CreateCourseDialogState extends ConsumerState<CreateCourseDialog> {
  final key = GlobalKey<FormState>();

  final name = TextEditingController();
  final code = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController(text: '0.00');
  final durationMonths = TextEditingController();
  final accessDays = TextEditingController();
  final featuredOrder = TextEditingController(text: '0');
  final certificateWatchPercentage = TextEditingController(text: '100');

  String mode = 'ONLINE';

  List<AdminCourseCategory> categories = [];
  AdminCourseCategory? selectedCategory;

  final String generatedCode = 'CRS-${DateTime.now().microsecondsSinceEpoch}';

  bool isFeatured = false;
  bool isCertificateEnabled = false;

  bool loadingCategories = false;
  bool saving = false;
  String? error;
  String? categoryError;

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  Future<void> loadCategories() async {
    if (loadingCategories || saving) return;
    final repository = ref.read(courseCategoryRepositoryProvider);
    setState(() {
      loadingCategories = true;
      categoryError = null;
    });
    try {
      final all = <AdminCourseCategory>[];
      var nextPage = 1;
      var received = 0;
      while (true) {
        final response = await repository.list(page: nextPage);
        if (!mounted) return;
        all.addAll(response.results);
        received += response.results.length;
        if (response.results.isEmpty || received >= response.count) break;
        nextPage++;
      }
      if (!mounted) return;
      setState(() {
        final unique = {for (final item in all) item.uuid: item};
        categories = unique.values.where((item) => item.isActive).toList();
        if (!categories.any((c) => c.uuid == selectedCategory?.uuid)) {
          selectedCategory = null;
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => categoryError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => categoryError = 'Could not load course categories.');
      }
    } finally {
      if (mounted) setState(() => loadingCategories = false);
    }
  }

  Future<void> _addNewCategory() async {
    final newCat = await showDialog<AdminCourseCategory>(
      context: context,
      builder: (_) => const _CreateCategoryQuickDialog(),
    );
    if (newCat != null && mounted) {
      await loadCategories();
      setState(() {
        selectedCategory = categories.firstWhere(
              (c) => c.uuid == newCat.uuid,
          orElse: () => newCat,
        );
      });
    }
  }

  String? validateInteger(String? value, {bool optional = false}) {
    final text = (value ?? '').trim();
    if (optional && text.isEmpty) return null;
    final number = int.tryParse(text);
    return number == null || number < 0 || number > 2147483647
        ? 'Enter a whole number from 0 to 2147483647'
        : null;
  }

  String? validatePrice(String? value) {
    final text = (value ?? '').trim();
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) {
      return 'Enter a non-negative price with up to 2 decimal places';
    }
    final whole = text.split('.').first.replaceFirst(RegExp(r'^0+'), '');
    return whole.length > 8 ? 'Maximum price is 99999999.99' : null;
  }

  String? validateCertificateWatchPercentage(String? value) {
    final percentage = double.tryParse((value ?? '').trim());

    if (percentage == null || percentage < 1 || percentage > 100) {
      return 'Enter a percentage from 1 to 100';
    }

    return null;
  }

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    description.dispose();
    price.dispose();
    durationMonths.dispose();
    accessDays.dispose();
    featuredOrder.dispose();
    certificateWatchPercentage.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || loadingCategories) return;
    if (!(key.currentState?.validate() ?? false)) {
      setState(
            () => error = 'Check the course details, including Advanced settings.',
      );
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() {
      saving = true;
      error = null;
    });

    try {
      final course = await ref.read(courseRepositoryProvider).create(
        name: name.text,
        code: code.text.trim().isEmpty ? generatedCode : code.text,
        description: description.text,
        price: price.text.trim(),
        deliveryMode: mode,
        categoryUuid: selectedCategory?.uuid,
        durationMonths: durationMonths.text.trim().isEmpty
            ? null
            : int.parse(durationMonths.text.trim()),
        accessDurationDays: accessDays.text.trim().isEmpty
            ? null
            : int.parse(accessDays.text.trim()),
        isActive: true,
        isPublished: false,
        isPurchasableOnline: false,
        isFeatured: isFeatured,
        isCertificateEnabled: isCertificateEnabled,
        certificateRequiredWatchPercentage:
        certificateWatchPercentage.text.trim(),
        featuredOrder:
        isFeatured ? int.parse(featuredOrder.text.trim()) : 0,
      );

      if (!mounted) return;
      setState(() => saving = false);
      Navigator.of(context).pop(course);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not create course. Please try again.');
      }
    } finally {
      if (mounted && saving) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AdminFormDialog(
      icon: Icons.auto_stories_outlined,
      title: 'Create course draft',
      subtitle: 'Start with the basics. Add learning content after saving.',
      onClose: saving ? null : () => Navigator.of(context).pop(),
      body: IgnorePointer(
        ignoring: saving,
        child: Form(
          key: key,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                enabled: !saving,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Course name'),
                validator: requiredField,
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(
                        'category_dd_${categories.length}_${selectedCategory?.uuid}',
                      ),
                      isExpanded: true,
                      value: categories
                          .any((c) => c.uuid == selectedCategory?.uuid)
                          ? selectedCategory?.uuid
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Course Category',
                      ),
                      items: categories
                          .map(
                            (category) => DropdownMenuItem<String>(
                          value: category.uuid,
                          child: Text(
                            category.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                          .toList(),
                      onChanged: saving || loadingCategories
                          ? null
                          : (value) {
                        setState(() {
                          selectedCategory = value == null
                              ? null
                              : categories.firstWhere(
                                (item) => item.uuid == value,
                          );
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed:
                    saving || loadingCategories ? null : _addNewCategory,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('New'),
                  ),
                ],
              ),
              if (loadingCategories) const LinearProgressIndicator(),
              if (categoryError != null) ...[
                const SizedBox(height: 10),
                AdminErrorBanner(message: categoryError!),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: saving ? null : loadCategories,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry categories'),
                  ),
                ),
              ],
              if (selectedCategory != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: saving || loadingCategories
                        ? null
                        : () => setState(() => selectedCategory = null),
                    child: const Text('Clear category'),
                  ),
                ),
              const SizedBox(height: 10),
              TextFormField(
                controller: description,
                enabled: !saving,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: price,
                enabled: !saving,
                decoration: const InputDecoration(labelText: 'Course fee (₹)'),
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                validator: validatePrice,
              ),
              const SizedBox(height: 10),
              ExpansionTile(
                maintainState: true,
                title: const Text('Advanced settings'),
                subtitle: const Text(
                  'Code, duration, certificates and featuring',
                ),
                children: [
                  TextFormField(
                    controller: code,
                    enabled: !saving,
                    maxLength: 50,
                    decoration: const InputDecoration(
                      labelText: 'Course code (optional)',
                      hintText: 'Generated automatically if left blank',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: durationMonths,
                    enabled: !saving,
                    validator: (value) =>
                        validateInteger(value, optional: true),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Duration (Months)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: accessDays,
                    enabled: !saving,
                    validator: (value) =>
                        validateInteger(value, optional: true),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Student Access Duration (Days)',
                      hintText: 'Example: 180',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: mode,
                    isExpanded: true,
                    decoration:
                    const InputDecoration(labelText: 'Delivery mode'),
                    items: const [
                      DropdownMenuItem(value: 'ONLINE', child: Text('Online')),
                      DropdownMenuItem(
                        value: 'OFFLINE',
                        child: Text('Offline'),
                      ),
                      DropdownMenuItem(value: 'HYBRID', child: Text('Hybrid')),
                    ],
                    onChanged: saving
                        ? null
                        : (value) => setState(() => mode = value ?? mode),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable Course Certificate'),
                    subtitle: const Text(
                      'Students can receive a certificate after completing the required learning progress.',
                    ),
                    value: isCertificateEnabled,
                    onChanged: saving
                        ? null
                        : (value) {
                      setState(() {
                        isCertificateEnabled = value;
                      });
                    },
                  ),
                  if (isCertificateEnabled) ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: certificateWatchPercentage,
                      enabled: !saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: validateCertificateWatchPercentage,
                      decoration: const InputDecoration(
                        labelText: 'Required video watch percentage',
                        hintText: 'Example: 85',
                        suffixText: '%',
                      ),
                    ),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Featured Course'),
                    value: isFeatured,
                    onChanged: saving
                        ? null
                        : (value) {
                      setState(() {
                        isFeatured = value;
                      });
                    },
                  ),
                  if (isFeatured) ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: featuredOrder,
                      enabled: !saving,
                      validator: validateInteger,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Featured Order',
                        hintText: '0 = first priority',
                      ),
                    ),
                  ],
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Save a draft first. Add subjects, chapters, lessons and materials on the course page, then preview and publish.',
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
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
          onPressed: saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        GradientButton(
          label: 'Create draft',
          icon: Icons.check_rounded,
          loading: saving,
          onPressed: saving || loadingCategories ? null : save,
        ),
      ],
    ),
  );
}

class _CreateCategoryQuickDialog extends ConsumerStatefulWidget {
  const _CreateCategoryQuickDialog();

  @override
  ConsumerState<_CreateCategoryQuickDialog> createState() =>
      __CreateCategoryQuickDialogState();
}

class __CreateCategoryQuickDialogState
    extends ConsumerState<_CreateCategoryQuickDialog> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final descController = TextEditingController();
  bool saving = false;
  String? error;

  @override
  void dispose() {
    nameController.dispose();
    descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (saving || !(formKey.currentState?.validate() ?? false)) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final created = await ref.read(courseCategoryRepositoryProvider).create(
        name: nameController.text,
        description: descController.text,
      );
      if (mounted) Navigator.of(context).pop(created);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not create category.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Course Category'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Category Name *'),
              validator: (v) =>
              v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
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
        FilledButton(
          onPressed: saving ? null : _save,
          child: saving
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Save Category'),
        ),
      ],
    );
  }
}

String? requiredField(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;