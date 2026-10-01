import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/student_portal_repository.dart';
import 'widgets/student_ui.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

DateTime? _parseDate(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return DateTime.tryParse(value.trim())?.toLocal();
}

String _prettyDate(String raw) {
  final date = _parseDate(raw);
  if (date == null) return raw;
  return '${date.day} ${_months[date.month - 1]} ${date.year}';
}

/// Days until access ends, or null when there is no end date.
int? _daysLeft(String? raw) {
  final date = _parseDate(raw);
  if (date == null) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final end = DateTime(date.year, date.month, date.day);
  return end.difference(today).inDays;
}

class MyCoursesScreen extends ConsumerStatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  ConsumerState<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends ConsumerState<MyCoursesScreen> {
  final List<MyCourse> _courses = [];

  final Map<String, Future<Map<String, dynamic>>> _progressFutures = {};

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  int _page = 1;
  int _requestId = 0;

  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCourses(reset: true);
  }

  Future<Map<String, dynamic>> _progressFor(
    String courseUuid,
  ) {
    return _progressFutures.putIfAbsent(
      courseUuid,
      () => ref
          .read(studentPortalRepositoryProvider)
          .courseProgress(courseUuid),
    );
  }

  Future<void> _loadCourses({
    required bool reset,
  }) async {
    if (!reset && (_loadingMore || !_hasMore)) {
      return;
    }

    final requestId = ++_requestId;
    final requestedPage = reset ? 1 : _page + 1;

    setState(() {
      _error = null;

      if (reset) {
        _loading = true;
        _loadingMore = false;
        _hasMore = true;
        _courses.clear();
        _progressFutures.clear();
      } else {
        _loadingMore = true;
      }
    });

    try {
      final result = await ref
          .read(studentPortalRepositoryProvider)
          .myCourses(page: requestedPage);

      if (!mounted || requestId != _requestId) {
        return;
      }

      setState(() {
        _courses.addAll(result.items);
        _page = requestedPage;
        _hasMore = result.hasNext;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) {
        return;
      }

      setState(() {
        _error = error.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _openCourse(String courseUuid) async {
    await context.push<void>('/student/courses/$courseUuid');

    if (!mounted) return;

    setState(() {
      _progressFutures.remove(courseUuid);
    });
  }

  Widget _courseProgress(String courseUuid) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return FutureBuilder<Map<String, dynamic>>(
      future: _progressFor(courseUuid),
      builder: (context, snapshot) {
        Widget panel(List<Widget> children) => Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F3FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            );

        if (snapshot.hasError) {
          return panel([
            Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: colors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Progress unavailable',
                    style: textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _progressFutures.remove(courseUuid);
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ]);
        }

        if (!snapshot.hasData) {
          return panel([
            Text('Course progress', style: textTheme.labelMedium),
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 8),
          ]);
        }

        final data = snapshot.data!;

        final percentage = (num.tryParse(
                  data['completion_percentage']?.toString() ?? '',
                ) ??
                0)
            .toDouble()
            .clamp(0.0, 100.0)
            .toDouble();

        final completed = int.tryParse(
              data['completed_materials']?.toString() ?? '',
            ) ??
            0;

        final total = int.tryParse(
              data['total_materials']?.toString() ?? '',
            ) ??
            0;

        final done = percentage >= 100;

        return panel([
          Row(
            children: [
              Expanded(
                child: Text('Course progress', style: textTheme.labelMedium),
              ),
              Text(
                '${percentage.toStringAsFixed(0)}% completed',
                style: textTheme.labelLarge?.copyWith(
                  color: done ? colors.success : colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 8,
              backgroundColor: colors.primaryTonal,
              color: done ? colors.success : colors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$completed of $total materials completed',
                  style: textTheme.bodySmall,
                ),
              ),
              Icon(
                done
                    ? Icons.emoji_events_outlined
                    : percentage == 0
                        ? Icons.schedule_rounded
                        : Icons.trending_up_rounded,
                size: 16,
                color: done ? colors.success : colors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                done
                    ? 'Finished'
                    : percentage == 0
                        ? 'Fresh start'
                        : 'In progress',
                style: textTheme.labelMedium?.copyWith(
                  color: done ? colors.success : colors.primary,
                ),
              ),
            ],
          ),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    final subjects = _courses
        .map((course) => course.categoryName ?? course.code)
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .length;
    final expiringSoon = _courses.where((course) {
      final days = _daysLeft(course.accessEndAt);
      return days != null && days >= 0 && days <= 30;
    }).length;

    final countLabel =
        _hasMore ? '${_courses.length}+' : '${_courses.length}';

    return RefreshIndicator(
      onRefresh: () => _loadCourses(reset: true),
      child: StudentPageFrame(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            kStudentPagePadding,
            4,
            kStudentPagePadding,
            24,
          ),
          children: [
            _MomentumHero(
              courseCount: _loading ? null : countLabel,
              singular: !_hasMore && _courses.length == 1,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.auto_stories_outlined,
                    value: _loading ? '–' : countLabel,
                    label: 'Active',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    icon: Icons.category_outlined,
                    value: _loading ? '–' : '$subjects',
                    label: 'Subjects',
                    valueColor: colors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    icon: Icons.hourglass_bottom_rounded,
                    value: _loading ? '–' : '$expiringSoon',
                    label: 'Expiring soon',
                    iconBackground:
                        expiringSoon > 0 ? colors.dangerBg : null,
                    iconColor: expiringSoon > 0 ? colors.danger : null,
                    valueColor: expiringSoon > 0 ? colors.danger : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SectionHeader(
              title: 'Enrolled courses',
              icon: Icons.school_outlined,
              trailing: _loading || _courses.isEmpty
                  ? null
                  : TonalPill(label: '$countLabel active'),
            ),
            if (_loading)
              const StudentLoading()
            else if (_courses.isEmpty && _error != null)
              StudentStateMessage(
                icon: Icons.wifi_off_rounded,
                title: 'Courses could not load',
                message: _error!,
                actionLabel: 'Try again',
                onAction: () => _loadCourses(reset: true),
                isError: true,
              )
            else if (_courses.isEmpty)
              StudentStateMessage(
                icon: Icons.school_outlined,
                title: 'No active courses yet',
                message: 'Contact your academy to get access, '
                    'or browse what is on offer.',
                actionLabel: 'Explore courses',
                onAction: () => context.go('/explore'),
              )
            else ...[
              for (final course in _courses)
                _EnrolledCourseCard(
                  course: course,
                  progress: _courseProgress(course.courseUuid),
                  onOpen: () => _openCourse(course.courseUuid),
                ),
              if (_error != null)
                InlineError(message: 'Could not load more: $_error'),
              if (_hasMore)
                LoadMoreButton(
                  label: 'Load more courses',
                  loading: _loadingMore,
                  onPressed: () => _loadCourses(reset: false),
                ),
            ],
            if (!_loading) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.primaryTonal,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.live_tv_rounded, color: colors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'See live and upcoming sessions for your courses.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/student/live-classes'),
                      child: const Text('Open'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MomentumHero extends StatelessWidget {
  const _MomentumHero({required this.courseCount, required this.singular});

  final String? courseCount;
  final bool singular;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    final message = courseCount == null
        ? 'Loading your learning space…'
        : courseCount == '0'
            ? 'Your enrolled courses will appear here.'
            : 'You have $courseCount active '
                '${singular ? 'course' : 'courses'}. Pick up where you left off.';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        gradient: colors.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: colors.heroShadow,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -6,
            top: -4,
            child: Icon(
              Icons.menu_book_rounded,
              size: 88,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TonalPill(
                label: 'My learning',
                icon: Icons.school_rounded,
                background: Colors.white.withValues(alpha: 0.18),
                foreground: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                'Keep up the momentum',
                style: textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFDAD7FF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.valueColor,
    this.iconBackground,
    this.iconColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? valueColor;
  final Color? iconBackground;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return PremiumCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          IconTile(
            icon: icon,
            size: 38,
            radius: 19,
            background: iconBackground,
            foreground: iconColor,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor ?? colors.textPrimary,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _EnrolledCourseCard extends StatelessWidget {
  const _EnrolledCourseCard({
    required this.course,
    required this.progress,
    required this.onOpen,
  });

  final MyCourse course;
  final Widget progress;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final daysLeft = _daysLeft(course.accessEndAt);
    final expiringSoon = daysLeft != null && daysLeft >= 0 && daysLeft <= 30;
    final expired = daysLeft != null && daysLeft < 0;

    void open() => onOpen();

    final accessLabel = course.accessEndAt == null
        ? 'Access active'
        : expired
            ? 'Access ended ${_prettyDate(course.accessEndAt!)}'
            : expiringSoon
                ? (daysLeft == 0
                    ? 'Access ends today'
                    : 'Access ends in $daysLeft '
                        '${daysLeft == 1 ? 'day' : 'days'}')
                : 'Access until ${_prettyDate(course.accessEndAt!)}';

    return PremiumCard(
      onTap: open,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconTile(
                icon: Icons.menu_book_rounded,
                size: 56,
                radius: 16,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        TonalPill(
                          label: course.categoryName ?? course.code,
                        ),
                        TonalPill(
                          label: accessLabel,
                          icon: expired || expiringSoon
                              ? Icons.schedule_rounded
                              : Icons.verified_outlined,
                          background: expired
                              ? colors.dangerBg
                              : expiringSoon
                                  ? colors.warningBg
                                  : colors.successBg,
                          foreground: expired
                              ? colors.danger
                              : expiringSoon
                                  ? colors.warning
                                  : colors.success,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textSubtle),
            ],
          ),
          if (course.description.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              course.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
            ),
          ],
          const SizedBox(height: 14),
          progress,
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colors.primaryDeep,
                minimumSize: const Size(0, 44),
              ),
              onPressed: open,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Continue learning'),
            ),
          ),
        ],
      ),
    );
  }
}
