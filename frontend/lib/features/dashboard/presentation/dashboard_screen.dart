import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/session/user_role.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/admin_ui.dart';
import '../data/dashboard_repository.dart';

final superAdminDashboardSummaryProvider =
FutureProvider.autoDispose<SuperAdminDashboardSummary>((ref) {
  return ref
      .watch(dashboardRepositoryProvider)
      .superAdminSummary();
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);

    if (session.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (session.role == UserRole.superAdmin) {
      return const _SuperAdminDashboard();
    }

    if ((session.role != UserRole.academyAdmin &&
        session.role != UserRole.firmStaff) ||
        (session.firmUuid ?? '').isEmpty) {
      return const _DashboardMessage(
        icon: Icons.lock_outline_rounded,
        title: 'Dashboard unavailable',
        message: 'Please sign in with an academy admin account.',
      );
    }

    return _AcademyDashboard(
      key: ValueKey('${session.userUuid}_${session.firmUuid}'),
      academyName: session.firmName?.trim().isNotEmpty == true
          ? session.firmName!.trim()
          : 'Your Academy',
    );
  }
}

class _AcademyDashboard extends ConsumerStatefulWidget {
  const _AcademyDashboard({super.key, required this.academyName});

  final String academyName;

  @override
  ConsumerState<_AcademyDashboard> createState() =>
      _AcademyDashboardState();
}

class _AcademyDashboardState extends ConsumerState<_AcademyDashboard> {
  late Future<DashboardSummary> _summaryFuture;
  bool _refreshing = false;

  DashboardRepository get _repository =>
      ref.read(dashboardRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _summaryFuture = _repository.summary();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;

    setState(() {
      _refreshing = true;
      _summaryFuture = _repository.summary();
    });

    try {
      await _summaryFuture;
    } catch (_) {
      // Error is shown inside FutureBuilder.
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  void _open(String route) {
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<DashboardSummary>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 100),
                _DashboardMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load dashboard',
                  message:
                  'Check your internet connection and try again.',
                  actionLabel: 'Retry',
                  onAction: _refresh,
                ),
              ],
            );
          }

          final summary = snapshot.data;
          if (summary == null) {
            return const _DashboardMessage(
              icon: Icons.dashboard_outlined,
              title: 'Dashboard unavailable',
              message: 'No dashboard data was received.',
            );
          }

          final students = summary.metricFor('Students');
          final teachers = summary.metricFor('Teachers');
          final courses = summary.metricFor('Courses');
          final enrollments = summary.metricFor('Enrollments');

          final totalPaid = summary.metricFor('Total paid');
          final pendingBalance = summary.metricFor('Pending balance');
          final monthCollection =
          summary.metricFor('Collected since month start');

          final pendingGrading = summary.metricFor('Pending grading');
          final upcomingClasses = summary.metricFor('Upcoming classes');
          final liveNow = summary.metricFor('Live now');

          return _CenteredList(
            maxWidth: 1400,
            children: [
              _HeroSection(
                academyName: widget.academyName,
                students: students.text,
                onRefresh: _refresh,
                refreshing: _refreshing,
              ),
              const SizedBox(height: 24),

              Text(
                'Academy overview',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              _ResponsiveGrid(
                phoneColumns: 2,
                tabletColumns: 2,
                desktopColumns: 4,
                children: [
                  _MetricCard(
                    label: 'Students',
                    value: students.text,
                    caption: students.caption ?? 'Registered students',
                    icon: Icons.school_outlined,
                    color: colors.primary,
                    onTap: () => _open('/students'),
                  ),
                  _MetricCard(
                    label: 'Teachers',
                    value: teachers.text,
                    caption: teachers.caption ?? 'Active teaching staff',
                    icon: Icons.co_present_outlined,
                    color: const Color(0xFF7C3AED),
                    onTap: () => _open('/teachers'),
                  ),
                  _MetricCard(
                    label: 'Courses',
                    value: courses.text,
                    caption: courses.caption ?? 'Active courses',
                    icon: Icons.auto_stories_outlined,
                    color: const Color(0xFF0284C7),
                    onTap: () => _open('/courses'),
                  ),
                  _MetricCard(
                    label: 'Enrollments',
                    value: enrollments.text,
                    caption: 'Course allocations',
                    icon: Icons.how_to_reg_outlined,
                    color: const Color(0xFF059669),
                    onTap: () => _open('/enrollments'),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              Text(
                'Needs attention',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              _ResponsiveGrid(
                phoneColumns: 1,
                tabletColumns: 2,
                desktopColumns: 3,
                children: [
                  _AttentionCard(
                    title: 'Pending grading',
                    value: pendingGrading.text,
                    message: 'Student submissions need review.',
                    icon: Icons.assignment_late_outlined,
                    background: const Color(0xFFFFF7ED),
                    foreground: const Color(0xFFC2410C),
                    onTap: () => _open('/assignments'),
                  ),
                  _AttentionCard(
                    title: 'Pending fee balance',
                    value: pendingBalance.text,
                    message: 'Fees still awaiting collection.',
                    icon: Icons.account_balance_wallet_outlined,
                    background: const Color(0xFFFFF1F2),
                    foreground: const Color(0xFFBE123C),
                    onTap: () => _open('/fees'),
                  ),
                  _AttentionCard(
                    title: 'Upcoming classes',
                    value: upcomingClasses.text,
                    message: '${liveNow.text} currently live class(es).',
                    icon: Icons.video_camera_front_outlined,
                    background: const Color(0xFFEFF6FF),
                    foreground: const Color(0xFF1D4ED8),
                    onTap: () => _open('/live-classes'),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              Text(
                'Financial overview',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              AdminCard(
                child: _ResponsiveGrid(
                  phoneColumns: 1,
                  tabletColumns: 3,
                  desktopColumns: 3,
                  gap: 18,
                  children: [
                    _FinanceValue(
                      label: 'Collected this month',
                      value: monthCollection.text,
                      icon: Icons.trending_up_rounded,
                      color: colors.success,
                    ),
                    _FinanceValue(
                      label: 'Total paid',
                      value: totalPaid.text,
                      icon: Icons.payments_outlined,
                      color: colors.primary,
                    ),
                    _FinanceValue(
                      label: 'Pending balance',
                      value: pendingBalance.text,
                      icon: Icons.warning_amber_rounded,
                      color: colors.warning,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'Quick actions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              _ResponsiveGrid(
                phoneColumns: 2,
                tabletColumns: 4,
                desktopColumns: 7,
                gap: 12,
                children: [
                  _QuickAction(
                    label: 'Add student',
                    icon: Icons.person_add_alt_1_outlined,
                    onTap: () => _open('/students'),
                  ),
                  _QuickAction(
                    label: 'Create course',
                    icon: Icons.add_circle_outline_rounded,
                    onTap: () => _open('/courses'),
                  ),
                  _QuickAction(
                    label: 'Manage fees',
                    icon: Icons.currency_rupee_rounded,
                    onTap: () => _open('/fees'),
                  ),
                  _QuickAction(
                    label: 'Schedule class',
                    icon: Icons.add_to_queue_outlined,
                    onTap: () => _open('/live-classes'),
                  ),
                  _QuickAction(
                    label: 'Upload material',
                    icon: Icons.upload_file_outlined,
                    onTap: () => _open('/materials'),
                  ),
                  _QuickAction(
                    label: 'Assignments',
                    icon: Icons.assignment_outlined,
                    onTap: () => _open('/assignments'),
                  ),
                  _QuickAction(
                    label: 'Notifications',
                    icon: Icons.notifications_outlined,
                    onTap: () => _open('/notifications'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HERO BANNER
// ═══════════════════════════════════════════════════════════════════════════════

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.academyName,
    required this.campusId,
    required this.studentCount,
    required this.refreshing,
    required this.onRefresh,
  });

  final String academyName;
  final String campusId;
  final String studentCount;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF3525CD),
            Color(0xFF4338CA),
            Color(0xFF6366F1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x404F46E5),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Ambient lighting accents
          Positioned(
            right: -50,
            bottom: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 200,
            top: -40,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFFC0C1FF).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badges row
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'ACADEMIC SESSION 2026–27',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFE3DFFF),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF34D399),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Active & Operational',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                            color: const Color(0xFFA7F3D0),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                'Welcome back, $academyName',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              // Subtitle
              Text(
                '$studentCount students currently registered • Campus ID: $campusId • 100% of staff records verified',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFE3DFFF).withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION HEADER
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF131B2E),
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              trailing!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF8E90A6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// OVERVIEW CARD (Students, Teachers, Courses, Enrollments)
// ═══════════════════════════════════════════════════════════════════════════════

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.label,
    required this.value,
    required this.badge,
    required this.badgeColor,
    required this.badgeBg,
    required this.caption,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.onTap,
  });

  final String label;
  final String value;
  final String badge;
  final Color badgeColor;
  final Color badgeBg;
  final String caption;
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        hoverColor: const Color(0xFFF8FAFC),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF525469),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          value,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF131B2E),
                            letterSpacing: -0.5,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badge,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                              color: badgeColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF8E90A6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: iconFg.withValues(alpha: 0.12),
                  ),
                ),
                child: Icon(icon, size: 22, color: iconFg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ATTENTION CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _LegacyAttentionCard extends StatelessWidget {
  const _LegacyAttentionCard({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.value,
    required this.valueColor,
    required this.title,
    required this.titleColor,
    required this.message,
    required this.messageColor,
    required this.bgColor,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String value;
  final Color valueColor;
  final String title;
  final Color titleColor;
  final String message;
  final Color messageColor;
  final Color bgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 24, color: iconFg),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          value,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: valueColor,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: messageColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, size: 20, color: iconFg),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FINANCE CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _FinanceCard extends StatelessWidget {
  const _FinanceCard({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.value,
    required this.label,
    this.valueColor,
    this.trailing,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String value;
  final String label;
  final Color? valueColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: iconFg),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: valueColor ?? const Color(0xFF131B2E),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF525469),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DETAILED REPORTS CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _DetailedReportsCard extends StatelessWidget {
  const _DetailedReportsCard({
    required this.report,
    required this.reportFuture,
    required this.enrollmentStatus,
    required this.dateFrom,
    required this.dateTo,
    required this.onSelectReport,
    required this.onEnrollmentStatusChanged,
    required this.onPickDate,
    required this.onClearDates,
    required this.onOpenReport,
    required this.onRetry,
  });

  final DashboardReport report;
  final Future<DashboardReportPage> reportFuture;
  final String? enrollmentStatus;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final ValueChanged<DashboardReport> onSelectReport;
  final ValueChanged<String?> onEnrollmentStatusChanged;
  final Future<void> Function({required bool isFrom}) onPickDate;
  final VoidCallback onClearDates;
  final ValueChanged<String> onOpenReport;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detailed reports',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF131B2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Live records from your academy data stream',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF525469),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Export CSV'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                  textStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Filter pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final type in DashboardReport.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _ReportFilterPill(
                      label: type.title,
                      selected: report == type,
                      onTap: () => onSelectReport(type),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Date filters
          if (report.usesDates)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _DateChip(
                  icon: Icons.calendar_today_outlined,
                  label: 'From:',
                  value: dateFrom == null ? 'Oct 01, 2026' : _displayDate(dateFrom!),
                  onTap: () => onPickDate(isFrom: true),
                ),
                _DateChip(
                  icon: Icons.event_outlined,
                  label: 'To:',
                  value: dateTo == null ? 'Oct 07, 2026' : _displayDate(dateTo!),
                  onTap: () => onPickDate(isFrom: false),
                ),
                if (dateFrom != null || dateTo != null)
                  TextButton(
                    onPressed: onClearDates,
                    child: const Text('Clear'),
                  ),
              ],
            ),
          if (report == DashboardReport.enrollments) ...[
            if (report.usesDates) const SizedBox(height: 12),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                value: enrollmentStatus,
                decoration: const InputDecoration(
                  labelText: 'Enrollment status',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All statuses')),
                  DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                  DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                  DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                  DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
                ],
                onChanged: onEnrollmentStatusChanged,
              ),
            ),
          ],
          const SizedBox(height: 20),
          // Results
          FutureBuilder<DashboardReportPage>(
            future: reportFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || snapshot.data == null) {
                return _InlineMessage(
                  icon: Icons.cloud_off_rounded,
                  message: 'Could not load this report.',
                  actionLabel: 'Retry',
                  onAction: onRetry,
                );
              }
              final page = snapshot.data!;
              if (page.rows.isEmpty) {
                return const _InlineMessage(
                  icon: Icons.inbox_outlined,
                  message: 'No records found for this report.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary metrics
                  if (page.metrics.isNotEmpty)
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        for (final metric in page.metrics)
                          Text(
                            '${metric.label}: ${metric.text}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color: const Color(0xFF525469),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  // Transaction rows
                  for (final row in page.rows.take(5))
                    _LedgerRow(
                      title: row.title,
                      subtitle: row.subtitle,
                      details: row.details,
                      onTap:
                      row.route == null ? null : () => onOpenReport(row.route!),
                    ),
                  if (page.count > page.rows.length)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '${page.count} total records. Use the respective module to view all records.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF8E90A6),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

String _displayDate(DateTime dt) {
  final months = [
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
    'Dec'
  ];
  final month = months[dt.month - 1];
  final day = dt.day.toString().padLeft(2, '0');
  return '$month $day, ${dt.year}';
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF64748B), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF525469),
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

class _ReportFilterPill extends StatelessWidget {
  const _ReportFilterPill({
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
      color: selected ? const Color(0xFFEEF0FF) : const Color(0xFFE6E9FF),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check_rounded,
                    size: 15, color: Color(0xFF4F46E5)),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected
                      ? const Color(0xFF4F46E5)
                      : const Color(0xFF525469),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF4F3FF),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: const Color(0xFF8E90A6)),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF525469),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF131B2E),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LEDGER ROW (Transaction item)
// ═══════════════════════════════════════════════════════════════════════════════

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.title,
    required this.subtitle,
    required this.details,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final List<String> details;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFFF4F3FF),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          hoverColor: const Color(0xFFEEF0FF),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF0FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    size: 20,
                    color: Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF131B2E),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF525469),
                        ),
                      ),
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          details.join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF8E90A6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF8E90A6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TODAY'S SCHEDULE CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _TodayScheduleCard extends StatelessWidget {
  const _TodayScheduleCard({required this.onLaunchRoom});

  final VoidCallback onLaunchRoom;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined,
                  size: 22, color: Color(0xFF4F46E5)),
              const SizedBox(width: 8),
              Text(
                "Today's Schedule",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF131B2E),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6E9FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Oct 7',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Class item
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Class 10 Physics Lab',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF131B2E),
                        ),
                      ),
                    ),
                    Text(
                      '04:00 PM',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF4F46E5),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Instructor: Rahul Patil • Room 204 & Stream',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF525469),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Avatar stack
                    SizedBox(
                      width: 60,
                      height: 26,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            child: _MiniAvatar(
                              label: 'AP',
                              color: const Color(0xFF4F46E5),
                            ),
                          ),
                          Positioned(
                            left: 18,
                            child: _MiniAvatar(
                              label: 'RJ',
                              color: const Color(0xFF6366F1),
                            ),
                          ),
                          Positioned(
                            left: 36,
                            child: _MiniAvatar(
                              label: '+4',
                              color: const Color(0xFF003F5C),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: onLaunchRoom,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        minimumSize: const Size(0, 32),
                        textStyle:
                        Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Launch Room'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Attendance
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE6E9FF).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Overall Attendance Rate',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF525469),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '96.4%',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF047857),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: 0.964,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFDDE2FD),
                    valueColor:
                    const AlwaysStoppedAnimation(Color(0xFF059669)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '6 of 6 registered students present this week',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF8E90A6),
                    fontSize: 12,
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

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CAMPUS BROADCAST CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _CampusBroadcastCard extends StatelessWidget {
  const _CampusBroadcastCard({required this.onWhatsAppAlert});

  final VoidCallback onWhatsAppAlert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_outlined,
                  size: 22, color: Color(0xFF4648D4)),
              const SizedBox(width: 8),
              Text(
                'Campus Broadcast',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF131B2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Send instant alerts or WhatsApp notifications to all parents regarding pending fee balance.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF525469),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onWhatsAppAlert,
                  icon: const Icon(Icons.chat_outlined,
                      size: 16, color: Color(0xFF059669)),
                  label: const Text('WhatsApp Alert'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF131B2E),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle:
                    Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6E9FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: const Icon(Icons.history_outlined,
                      size: 18, color: Color(0xFF334155)),
                  onPressed: () {},
                  tooltip: 'SMS Logs',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUICK ACTIONS GRID
// ═══════════════════════════════════════════════════════════════════════════════

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
    required this.canManageAcademy,
    required this.onOpen,
  });

  final bool canManageAcademy;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final actions = <({String label, IconData icon, String route, bool adminOnly})>[
      (label: 'Add student', icon: Icons.person_add_alt_1_outlined, route: '/students', adminOnly: true),
      (label: 'Create course', icon: Icons.add_circle_outline_rounded, route: '/courses', adminOnly: true),
      (label: 'Manage fees', icon: Icons.currency_rupee_rounded, route: '/fees', adminOnly: true),
      (label: 'Schedule class', icon: Icons.add_to_queue_outlined, route: '/live-classes', adminOnly: true),
      (label: 'Upload material', icon: Icons.upload_file_outlined, route: '/materials', adminOnly: true),
      (label: 'Assignments', icon: Icons.assignment_outlined, route: '/assignments', adminOnly: true),
      (label: 'Notifications', icon: Icons.notifications_outlined, route: '/notifications', adminOnly: false),
    ];

    final visibleActions = actions
        .where((action) => canManageAcademy || !action.adminOnly)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1200
            ? 7
            : width >= 900
            ? 4
            : width >= 600
            ? 3
            : 2;
        const gap = 12.0;
        final cardWidth = (width - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final action in visibleActions)
              SizedBox(
                width: cardWidth,
                child: _QuickActionTile(
                  label: action.label,
                  icon: action.icon,
                  onTap: () => onOpen(action.route),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        hoverColor: const Color(0xFF4F46E5).withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF0FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: const Color(0xFF4F46E5)),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF131B2E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUPER ADMIN DASHBOARD
// ═══════════════════════════════════════════════════════════════════════════════

class _SuperAdminDashboard extends ConsumerWidget {
  const _SuperAdminDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final summaryState = ref.watch(superAdminDashboardSummaryProvider);

    void refresh() {
      ref.invalidate(superAdminDashboardSummaryProvider);
    }

    return RefreshIndicator(
      onRefresh: () async {
        refresh();
        await ref.read(superAdminDashboardSummaryProvider.future);
      },
      child: summaryState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 100),
            _DashboardMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load dashboard',
              message: 'Check your internet connection and try again.',
              actionLabel: 'Retry',
              onAction: refresh,
            ),
          ],
        ),
        data: (summary) => _CenteredList(
          children: [
            _HeroSection(
              academyName: 'Platform administration',
              students: '${summary.totalFirms} academies',
              onRefresh: refresh,
              refreshing: summaryState.isLoading,
              superAdmin: true,
            ),
            const SizedBox(height: 24),

            _OverviewLabel(
              title: 'System overview',
              onRefresh: refresh,
            ),
            const SizedBox(height: 10),

            _ResponsiveGrid(
              phoneColumns: 2,
              tabletColumns: 2,
              desktopColumns: 4,
              children: [
                _MetricCard(
                  label: 'Academies',
                  value: summary.totalFirms.toString(),
                  caption: '${summary.activeFirms} currently active',
                  icon: Icons.apartment_outlined,
                  color: colors.primary,
                  onTap: () => context.go('/firms'),
                ),
                _MetricCard(
                  label: 'Students',
                  value: summary.totalStudents.toString(),
                  caption: '${summary.activeStudents} active students',
                  icon: Icons.school_outlined,
                  color: const Color(0xFF0D9488),
                  onTap: () => context.go('/firms'),
                ),
                _MetricCard(
                  label: 'Courses',
                  value: summary.totalCourses.toString(),
                  caption: '${summary.activeCourses} active courses',
                  icon: Icons.auto_stories_outlined,
                  color: const Color(0xFF7C3AED),
                  onTap: () => context.go('/firms'),
                ),
                _MetricCard(
                  label: 'Enrollments',
                  value: summary.totalEnrollments.toString(),
                  caption: '${summary.activeEnrollments} active enrollments',
                  icon: Icons.how_to_reg_outlined,
                  color: const Color(0xFF0284C7),
                  onTap: () => context.go('/firms'),
                ),
              ],
            ),

            const SizedBox(height: 28),

            Text(
              'Platform actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            _ResponsiveGrid(
              phoneColumns: 1,
              tabletColumns: 2,
              desktopColumns: 2,
              gap: 12,
              children: [
                _PlatformActionTile(
                  title: 'Manage academies',
                  subtitle: 'View, configure & monitor active tenant firms',
                  icon: Icons.business_outlined,
                  onTap: () => context.go('/firms'),
                ),
                _PlatformActionTile(
                  title: 'Manage firm admins',
                  subtitle: 'Assign roles, credentials & permissions',
                  icon: Icons.manage_accounts_outlined,
                  onTap: () => context.go('/firm-admins'),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Center(child: _SignedInPill(label: 'Super Admin')),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.academyName,
    required this.students,
    required this.onRefresh,
    required this.refreshing,
    this.superAdmin = false,
  });

  final String academyName;
  final String students;
  final VoidCallback onRefresh;
  final bool refreshing;
  final bool superAdmin;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final phone = _isPhoneWidth(MediaQuery.sizeOf(context).width);

    final spinner = const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Colors.white,
      ),
    );

    final refreshButton = phone
        ? IconButton(
      tooltip: 'Refresh',
      onPressed: refreshing ? null : onRefresh,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.18),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.12),
      ),
      icon: refreshing ? spinner : const Icon(Icons.refresh_rounded),
    )
        : OutlinedButton.icon(
      onPressed: refreshing ? null : onRefresh,
      icon: refreshing ? spinner : const Icon(Icons.refresh_rounded),
      label: Text(refreshing ? 'Refreshing...' : 'Refresh'),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white38),
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
      ),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2563EB),
            Color(0xFF4F46E5),
            Color(0xFF4338CA),
          ],
        ),
        borderRadius: BorderRadius.circular(phone ? 18 : 22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x334F46E5),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -50,
            bottom: -60,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(phone ? 20 : 30),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          superAdmin
                              ? '👋  Welcome back'
                              : '👋  Good to see you',
                          style: textTheme.labelMedium?.copyWith(
                            color: const Color(0xFFE0E7FF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        academyName,
                        style: jakarta(
                          (phone
                              ? textTheme.headlineSmall
                              : textTheme.headlineMedium)
                              ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Text(
                          superAdmin
                              ? 'Manage your Academy ERP platform, institutes, '
                              'courses, and system admins from one place.'
                              : '$students students are currently in your academy.',
                          style: (phone
                              ? textTheme.bodySmall
                              : textTheme.bodyMedium)
                              ?.copyWith(
                            color: const Color(0xFFE0E7FF),
                            height: 1.5,
                          ),
                        ),
                      ),
                      if (superAdmin) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            students,
                            style: textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                refreshButton,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final phone = _isPhoneWidth(MediaQuery.sizeOf(context).width);

    return AdminCard(
      onTap: onTap,
      padding: EdgeInsets.all(phone ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminIconTile(
            icon: icon,
            size: phone ? 38 : 42,
            background: color.withValues(alpha: 0.10),
            foreground: color,
          ),
          SizedBox(height: phone ? 14 : 18),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: jakarta(
              (phone ? textTheme.headlineSmall : textTheme.headlineMedium)
                  ?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.6,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.title,
    required this.value,
    required this.message,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String title;
  final String value;
  final String message;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: foreground.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              AdminIconTile(
                icon: icon,
                size: 46,
                background: Colors.white,
                foreground: foreground,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: jakarta(
                        textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: foreground,
                        ),
                      ),
                    ),
                    Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: foreground, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinanceValue extends StatelessWidget {
  const _FinanceValue({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        AdminIconTile(
          icon: icon,
          size: 44,
          background: color.withValues(alpha: 0.10),
          foreground: color,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: jakarta(
                  textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: context.colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AdminIconTile(icon: icon, size: 42),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardMessage extends StatelessWidget {
  const _DashboardMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: AdminCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AdminIconTile(icon: icon, size: 56),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 18),
                  GradientButton(
                    label: actionLabel!,
                    onPressed: onAction,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RESPONSIVE LAYOUT HELPERS (design only)
// ═══════════════════════════════════════════════════════════════════════════════

/// Phone < 600px ≤ tablet < 1000px ≤ desktop.
bool _isPhoneWidth(double width) => width < 600;

/// Scrollable body with centred, width-capped content.
class _CenteredList extends StatelessWidget {
  const _CenteredList({required this.children, this.maxWidth = 1200});

  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

/// Equal-width grid: column count depends on the available width.
class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({
    required this.children,
    required this.phoneColumns,
    required this.tabletColumns,
    required this.desktopColumns,
    this.gap = 14,
  });

  final List<Widget> children;
  final int phoneColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < 600
            ? phoneColumns
            : width < 1000
            ? tabletColumns
            : desktopColumns;
        final cellWidth = (width - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(width: cellWidth, child: child),
          ],
        );
      },
    );
  }
}

/// "SYSTEM OVERVIEW" label with a small refresh link.
class _OverviewLabel extends StatelessWidget {
  const _OverviewLabel({required this.title, required this.onRefresh});

  final String title;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Refresh'),
        ),
      ],
    );
  }
}

/// Full-width action row: icon tile, title, subtitle and chevron.
class _PlatformActionTile extends StatelessWidget {
  const _PlatformActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AdminCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          AdminIconTile(
            icon: icon,
            size: 44,
            background: const Color(0xFFF1F5F9),
            foreground: const Color(0xFF475569),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        ],
      ),
    );
  }
}

/// "● Signed in as Super Admin" pill.
class _SignedInPill extends StatelessWidget {
  const _SignedInPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Signed in as $label',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}