import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/session/user_role.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/brand_utils.dart';
import '../../../core/widgets/admin_ui.dart';
import '../data/dashboard_repository.dart';

final superAdminDashboardSummaryProvider =
FutureProvider.autoDispose<SuperAdminDashboardSummary>((ref) {
  return ref.watch(dashboardRepositoryProvider).superAdminSummary();
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
      academyName: cleanFirmName(session.firmName),
    );
  }
}

class _AcademyDashboard extends ConsumerStatefulWidget {
  const _AcademyDashboard({super.key, required this.academyName});

  final String academyName;

  @override
  ConsumerState<_AcademyDashboard> createState() => _AcademyDashboardState();
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
                  message: 'Check your internet connection and try again.',
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
              const SizedBox(height: 20),

              // Quick Actions horizontal row matching reference screenshot[cite: 3]
              const _SectionHeaderRow(
                title: 'Quick Actions',
                trailing: 'Shortcuts',
                trailingColor: Color(0xFF64748B),
              ),
              const SizedBox(height: 10),
              // Keep all quick actions inside the phone width instead of
              // using a horizontally clipped action row.
              _ResponsiveGrid(
                phoneColumns: 2,
                tabletColumns: 3,
                desktopColumns: 3,
                gap: 10,
                children: [
                  _QuickActionChip(
                    label: 'Add Student',
                    icon: Icons.person_add_alt_1_outlined,
                    iconColor: const Color(0xFF4F46E5),
                    iconBg: const Color(0xFFEEF2FF),
                    onTap: () => _open('/students'),
                  ),
                  _QuickActionChip(
                    label: 'Register Faculty',
                    icon: Icons.badge_outlined,
                    iconColor: const Color(0xFF4F46E5),
                    iconBg: const Color(0xFFEEF2FF),
                    onTap: () => _open('/teachers'),
                  ),
                  _QuickActionChip(
                    label: 'Collect Fee',
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: const Color(0xFF059669),
                    iconBg: const Color(0xFFECFDF5),
                    onTap: () => _open('/fees'),
                  ),
                  _QuickActionChip(
                    label: 'Create Course',
                    icon: Icons.add_circle_outline_rounded,
                    iconColor: const Color(0xFF0284C7),
                    iconBg: const Color(0xFFF0F9FF),
                    onTap: () => _open('/courses'),
                  ),
                  _QuickActionChip(
                    label: 'Schedule Class',
                    icon: Icons.add_to_queue_outlined,
                    iconColor: const Color(0xFF7C3AED),
                    iconBg: const Color(0xFFF5F3FF),
                    onTap: () => _open('/live-classes'),
                  ),
                  _QuickActionChip(
                    label: 'Upload Material',
                    icon: Icons.upload_file_outlined,
                    iconColor: const Color(0xFF4F46E5),
                    iconBg: const Color(0xFFEEF2FF),
                    onTap: () => _open('/materials'),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // Academy overview 2x2 / responsive grid[cite: 3]
              const _SectionHeaderRow(
                title: 'Academy overview',
                trailing: 'Active Session',
                trailingColor: Color(0xFF3730A3),
                trailingBold: true,
              ),
              const SizedBox(height: 12),
              _ResponsiveGrid(
                phoneColumns: 2,
                tabletColumns: 2,
                desktopColumns: 4,
                gap: 12,
                children: [
                  _MetricCard(
                    label: 'Students',
                    value: students.text,
                    caption: students.caption ?? 'Registered students',
                    icon: Icons.school_outlined,
                    color: const Color(0xFF4F46E5),
                    onTap: () => _open('/students'),
                  ),
                  _MetricCard(
                    label: 'Teachers',
                    value: teachers.text,
                    caption: teachers.caption ?? 'Active teaching staff',
                    icon: Icons.badge_outlined,
                    color: const Color(0xFF4F46E5),
                    onTap: () => _open('/teachers'),
                  ),
                  _MetricCard(
                    label: 'Courses',
                    value: courses.text,
                    caption: courses.caption ?? 'Active courses',
                    icon: Icons.menu_book_outlined,
                    color: const Color(0xFF2563EB),
                    onTap: () => _open('/courses'),
                  ),
                  _MetricCard(
                    label: 'Enrollments',
                    value: enrollments.text,
                    caption: 'Course allocations',
                    icon: Icons.how_to_reg_outlined,
                    color: const Color(0xFF10B981),
                    onTap: () => _open('/enrollments'),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Needs attention stacked list cards[cite: 3]
              const _SectionHeaderRow(
                title: 'Needs attention',
                trailing: '3 Pending',
                trailingColor: Color(0xFFDC2626),
                trailingBold: true,
                showDot: true,
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  _AttentionCard(
                    title: 'Pending grading',
                    value: pendingGrading.text,
                    message: 'Student submissions need review.',
                    icon: Icons.warning_amber_rounded,
                    background: Colors.white,
                    foreground: const Color(0xFFEA580C),
                    iconBg: const Color(0xFFFFF7ED),
                    onTap: () => _open('/assignments'),
                  ),
                  const SizedBox(height: 10),
                  _AttentionCard(
                    title: 'Pending fee balance',
                    value: pendingBalance.text,
                    message: 'Fees still awaiting collection.',
                    icon: Icons.account_balance_wallet_outlined,
                    background: Colors.white,
                    foreground: const Color(0xFFDC2626),
                    iconBg: const Color(0xFFFEF2F2),
                    onTap: () => _open('/fees'),
                  ),
                  const SizedBox(height: 10),
                  _AttentionCard(
                    title: 'Upcoming classes',
                    value: upcomingClasses.text,
                    message: '${liveNow.text} currently live class(es).',
                    icon: Icons.videocam_outlined,
                    background: Colors.white,
                    foreground: const Color(0xFF2563EB),
                    iconBg: const Color(0xFFEFF6FF),
                    onTap: () => _open('/live-classes'),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Financial overview[cite: 2]
              _SectionTitle(
                title: 'Financial overview',
                subtitle: 'Fee collection snapshot',
              ),
              const SizedBox(height: 12),
              AdminCard(
                padding: const EdgeInsets.all(18),
                child: _ResponsiveGrid(
                  phoneColumns: 1,
                  tabletColumns: 3,
                  desktopColumns: 3,
                  gap: 14,
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

              const SizedBox(height: 24),

              // Recent activity card matching screenshot[cite: 3]
              _RecentActivitySection(
                academyName: widget.academyName,
                onViewAll: () => _open('/notifications'),
              ),

              const SizedBox(height: 16),

              // Weekly Attendance Trend chart card matching screenshot[cite: 3]
              const _WeeklyAttendanceCard(),
            ],
          );
        },
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
          maxWidth: 1400,
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
            const SizedBox(height: 12),
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
                  icon: Icons.menu_book_outlined,
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
            const _SectionTitle(
              title: 'Platform actions',
              subtitle: 'Tenant and administrator controls',
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

// ═══════════════════════════════════════════════════════════════════════════════
// HERO & SECTION COMPONENTS (Matching Screen Design)[cite: 3]
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionHeaderRow extends StatelessWidget {
  const _SectionHeaderRow({
    required this.title,
    this.trailing,
    this.trailingColor = const Color(0xFF64748B),
    this.trailingBold = false,
    this.showDot = false,
    this.onTrailingTap,
  });

  final String title;
  final String? trailing;
  final Color trailingColor;
  final bool trailingBold;
  final bool showDot;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;

    Widget trailingWidget = const SizedBox.shrink();
    if (trailing != null) {
      trailingWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: trailingColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            trailing!,
            style: textTheme.labelMedium?.copyWith(
              color: trailingColor,
              fontWeight: trailingBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      );

      if (onTrailingTap != null) {
        trailingWidget = InkWell(
          onTap: onTrailingTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: trailingWidget,
          ),
        );
      }
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
              fontSize: 17,
              letterSpacing: -0.3,
            ),
          ),
        ),
        trailingWidget,
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
            fontSize: 17,
            letterSpacing: -0.3,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
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
      width: 15,
      height: 15,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Colors.white,
      ),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3730A3),
            Color(0xFF4F46E5),
            Color(0xFF2563EB),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E4F46E5),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            bottom: -50,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(phone ? 18 : 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
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
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: refreshing ? null : onRefresh,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.24),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (refreshing)
                              spinner
                            else
                              const Icon(
                                Icons.refresh_rounded,
                                size: 15,
                                color: Colors.white,
                              ),
                            const SizedBox(width: 6),
                            Text(
                              refreshing ? 'Refreshing...' : 'Refresh',
                              style: textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  academyName,
                  style: jakarta(
                    (phone
                        ? textTheme.headlineSmall
                        : textTheme.headlineMedium)
                        ?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  superAdmin
                      ? 'Manage your Academy ERP platform, institutes, '
                      'courses, and system admins from one place.'
                      : '$students students are currently active in your academy.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.4,
                  ),
                ),
                if (superAdmin) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
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
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        ),
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

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(phone ? 15 : 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: soft rounded icon box on left, label on right[cite: 3]
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 19, color: color),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: 4),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
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
    this.iconBg,
    required this.onTap,
  });

  final String title;
  final String value;
  final String message;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color? iconBg;
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg ?? foreground.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: foreground),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: jakarta(
                            textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              fontSize: 16,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 22,
              ),
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          AdminIconTile(
            icon: icon,
            size: 42,
            background: color.withValues(alpha: 0.12),
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
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: context.colors.textMuted,
                    fontWeight: FontWeight.w500,
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

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection({
    required this.academyName,
    required this.onViewAll,
  });

  final String academyName;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        _SectionHeaderRow(
          title: 'Recent activity',
          trailing: 'View all',
          trailingColor: const Color(0xFF3730A3),
          trailingBold: true,
          onTrailingTap: onViewAll,
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: const Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      'Sample data — connect to notifications API',
                      style: textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF64748B),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const _ActivityItem(
                icon: Icons.school_outlined,
                iconColor: Color(0xFF4F46E5),
                iconBg: Color(0xFFEEF2FF),
                title: 'New student enrolled',
                subtitle: 'Student batch allocation updated',
                time: '12m ago',
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const _ActivityItem(
                icon: Icons.menu_book_outlined,
                iconColor: Color(0xFF10B981),
                iconBg: Color(0xFFECFDF5),
                title: 'Course updated',
                subtitle: 'Curriculum & syllabus records synced',
                time: '1h ago',
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _ActivityItem(
                icon: Icons.verified_user_outlined,
                iconColor: Color(0xFF2563EB),
                iconBg: Color(0xFFEFF6FF),
                title: 'Admin session authenticated',
                subtitle: 'Active session for $academyName',
                time: 'Today',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String time;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: textTheme.labelMedium?.copyWith(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyAttendanceCard extends StatelessWidget {
  const _WeeklyAttendanceCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // TODO: replace with real attendance data once backend attendance module exists.
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const points = [0.22, 0.42, 0.54, 0.72, 0.76, 0.84];

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
              const Icon(
                Icons.show_chart_rounded,
                size: 18,
                color: Color(0xFF3730A3),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Weekly Attendance Trend',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '+98.2%',
                  style: textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF15803D),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 78,
            width: double.infinity,
            child: CustomPaint(
              painter: _AttendanceSparklinePainter(points: points),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final d in days)
                Text(
                  d,
                  style: textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceSparklinePainter extends CustomPainter {
  const _AttendanceSparklinePainter({required this.points});

  final List<double> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final strokePath = Path();
    final fillPath = Path();

    for (var i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final y = size.height - (points[i].clamp(0.05, 0.95) * size.height);
      if (i == 0) {
        strokePath.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        final prevX = ((i - 1) / (points.length - 1)) * size.width;
        final prevY =
            size.height - (points[i - 1].clamp(0.05, 0.95) * size.height);
        final ctrlX1 = prevX + (x - prevX) * 0.5;
        final ctrlX2 = prevX + (x - prevX) * 0.5;
        strokePath.cubicTo(ctrlX1, prevY, ctrlX2, y, x, y);
        fillPath.cubicTo(ctrlX1, prevY, ctrlX2, y, x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF4F46E5).withValues(alpha: 0.22),
          const Color(0xFF4F46E5).withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final linePaint = Paint()
      ..color = const Color(0xFF3730A3)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(strokePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant _AttendanceSparklinePainter oldDelegate) {
    return oldDelegate.points != points;
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

bool _isPhoneWidth(double width) => width < 600;

class _CenteredList extends StatelessWidget {
  const _CenteredList({required this.children, this.maxWidth = 1200});

  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
      ),
    );
  }
}

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
