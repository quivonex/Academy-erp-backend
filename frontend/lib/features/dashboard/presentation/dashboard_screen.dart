import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/session/user_role.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../firms/data/firm_admin_repository.dart';
import '../../firms/data/firm_repository.dart';
import '../data/dashboard_repository.dart';

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

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
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

              Wrap(
                spacing: 16,
                runSpacing: 16,
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

              Wrap(
                spacing: 16,
                runSpacing: 16,
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
                    message: '$liveNow currently live class(es).',
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
                child: Wrap(
                  spacing: 32,
                  runSpacing: 24,
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

              Wrap(
                spacing: 12,
                runSpacing: 12,
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

class _SuperAdminDashboard extends ConsumerWidget {
  const _SuperAdminDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final firms = ref.watch(firmsListProvider);
    final admins = ref.watch(allFirmAdminsProvider);

    void refresh() {
      ref.invalidate(firmsListProvider);
      ref.invalidate(allFirmAdminsProvider);
    }

    final firmList = firms.valueOrNull ?? [];
    final adminList = admins.valueOrNull ?? [];

    return RefreshIndicator(
      onRefresh: () async => refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _HeroSection(
            academyName: 'Platform administration',
            students: '${firmList.length} academies',
            onRefresh: refresh,
            refreshing: firms.isLoading || admins.isLoading,
            superAdmin: true,
          ),
          const SizedBox(height: 24),

          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _MetricCard(
                label: 'Academies',
                value: firmList.length.toString(),
                caption: 'Registered organizations',
                icon: Icons.apartment_outlined,
                color: colors.primary,
                onTap: () => context.go('/firms'),
              ),
              _MetricCard(
                label: 'Active academies',
                value: firmList.where((item) => item.isActive).length.toString(),
                caption: 'Currently operational',
                icon: Icons.verified_outlined,
                color: colors.success,
                onTap: () => context.go('/firms'),
              ),
              _MetricCard(
                label: 'Firm admins',
                value: adminList.length.toString(),
                caption: 'Academy administrators',
                icon: Icons.admin_panel_settings_outlined,
                color: const Color(0xFF7C3AED),
                onTap: () => context.go('/firm-admins'),
              ),
              _MetricCard(
                label: 'Active admins',
                value: adminList.where((item) => item.isActive).length.toString(),
                caption: 'Accounts with active access',
                icon: Icons.people_outline_rounded,
                color: const Color(0xFF0284C7),
                onTap: () => context.go('/firm-admins'),
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

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _QuickAction(
                label: 'Manage academies',
                icon: Icons.business_outlined,
                onTap: () => context.go('/firms'),
              ),
              _QuickAction(
                label: 'Manage firm admins',
                icon: Icons.manage_accounts_outlined,
                onTap: () => context.go('/firm-admins'),
              ),
            ],
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: context.colors.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: context.colors.heroShadow,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 20,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                superAdmin ? 'Welcome back' : 'Good to see you',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                academyName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                superAdmin
                    ? 'Manage your Academy ERP platform from one place.'
                    : '$students students are currently in your academy.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: refreshing ? null : onRefresh,
            icon: refreshing
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.refresh_rounded),
            label: Text(refreshing ? 'Refreshing...' : 'Refresh'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
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
    return SizedBox(
      width: 245,
      child: AdminCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminIconTile(
              icon: icon,
              background: color.withValues(alpha: 0.12),
              foreground: color,
            ),
            const SizedBox(height: 20),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          ],
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
    return SizedBox(
      width: 320,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              AdminIconTile(
                icon: icon,
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
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: foreground,
                      ),
                    ),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: foreground),
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
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          AdminIconTile(
            icon: icon,
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.textMuted,
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
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 19),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: context.colors.textPrimary,
        side: BorderSide(color: context.colors.borderSubtle),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      child: AdminCard(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52, color: context.colors.textMuted),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
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
    );
  }
}