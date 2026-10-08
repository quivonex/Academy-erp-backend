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

    final isFirmUser = session.role == UserRole.academyAdmin ||
        session.role == UserRole.firmStaff;
    if (!isFirmUser || (session.firmUuid ?? '').isEmpty) {
      return const _DashboardMessage(
        icon: Icons.lock_outline_rounded,
        title: 'Dashboard unavailable',
        message: 'Please sign in with an academy account to view this page.',
      );
    }

    return _AcademyDashboard(
      key: ValueKey('${session.userUuid}_${session.firmUuid}'),
      academyName: (session.firmName ?? '').trim().isEmpty
          ? 'Your Academy'
          : session.firmName!.trim(),
      campusId: session.firmUuid ?? 'RADSAT2026',
      adminName: session.userName ?? 'Admin',
      canManageAcademy: session.role == UserRole.academyAdmin,
    );
  }
}

class _AcademyDashboard extends ConsumerStatefulWidget {
  const _AcademyDashboard({
    super.key,
    required this.academyName,
    required this.campusId,
    required this.adminName,
    required this.canManageAcademy,
  });

  final String academyName;
  final String campusId;
  final String adminName;
  final bool canManageAcademy;

  @override
  ConsumerState<_AcademyDashboard> createState() => _AcademyDashboardState();
}

class _AcademyDashboardState extends ConsumerState<_AcademyDashboard> {
  late Future<DashboardSummary> _summaryFuture;
  late Future<DashboardReportPage> _reportFuture;
  DashboardReport _selectedReport = DashboardReport.collection;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _enrollmentStatus;
  bool _refreshing = false;

  DashboardRepository get _repository => ref.read(dashboardRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _summaryFuture = _repository.summary();
    _loadReport();
  }

  void _loadReport() {
    _reportFuture = _repository.report(
      type: _selectedReport,
      status: _selectedReport == DashboardReport.enrollments
          ? _enrollmentStatus
          : null,
      dateFrom: _selectedReport.usesDates ? _dateFrom : null,
      dateTo: _selectedReport.usesDates ? _dateTo : null,
    );
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _summaryFuture = _repository.summary();
      _loadReport();
    });
    try {
      await Future.wait([_summaryFuture, _reportFuture]);
    } catch (_) {}
    finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _open(String route) => context.go(route);

  void _selectReport(DashboardReport report) {
    if (_selectedReport == report) return;
    setState(() {
      _selectedReport = report;
      if (!report.usesDates) {
        _dateFrom = null;
        _dateTo = null;
      }
      _loadReport();
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = (isFrom ? _dateFrom : _dateTo) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (!mounted || picked == null) return;

    final nextFrom = isFrom ? picked : _dateFrom;
    final nextTo = isFrom ? _dateTo : picked;
    if (nextFrom != null && nextTo != null && nextTo.isBefore(nextFrom)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be after start date.')),
      );
      return;
    }
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
      } else {
        _dateTo = picked;
      }
      _loadReport();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<DashboardSummary>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 100),
                _DashboardMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load dashboard',
                  message: 'Check the connection and try again.',
                  actionLabel: 'Retry',
                  onAction: _refresh,
                ),
              ],
            );
          }

          final summary = snapshot.data!;
          final students = summary.metricFor('Students');
          final teachers = summary.metricFor('Teachers');
          final courses = summary.metricFor('Courses');
          final enrollments = summary.metricFor('Enrollments');
          final totalPaid = summary.metricFor('Total paid');
          final pendingBalance = summary.metricFor('Pending balance');
          final monthCollection = summary.metricFor('Collected since month start');
          final pendingGrading = summary.metricFor('Pending grading');
          final upcomingClasses = summary.metricFor('Upcoming classes');

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              // ═══════════════════════════════════════════════════════════
              // 1. HERO WELCOME BANNER
              // ═══════════════════════════════════════════════════════════
              _HeroBanner(
                academyName: widget.academyName,
                campusId: widget.campusId,
                studentCount: students.text,
                refreshing: _refreshing,
                onRefresh: _refresh,
              ),
              const SizedBox(height: 28),

              // ═══════════════════════════════════════════════════════════
              // 2. ACADEMY OVERVIEW
              // ═══════════════════════════════════════════════════════════
              const _SectionHeader(
                title: 'Academy overview',
                trailing: 'Real-time Directory Sync',
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width >= 1100
                      ? 4
                      : width >= 700
                      ? 2
                      : 1;
                  const gap = 16.0;
                  final cardWidth = (width - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _OverviewCard(
                          label: 'Students',
                          value: students.text,
                          badge: '${students.text} active',
                          badgeColor: const Color(0xFF059669),
                          badgeBg: const Color(0xFFECFDF5),
                          caption: 'Class 10 Science & IT',
                          icon: Icons.school_outlined,
                          iconBg: const Color(0xFFEEF0FF),
                          iconFg: const Color(0xFF4F46E5),
                          onTap: () => _open('/students'),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _OverviewCard(
                          label: 'Teachers',
                          value: teachers.text,
                          badge: '${teachers.text} active',
                          badgeColor: const Color(0xFF059669),
                          badgeBg: const Color(0xFFECFDF5),
                          caption: 'Rahul Patil (Lead)',
                          icon: Icons.co_present_outlined,
                          iconBg: const Color(0xFFE1E0FF),
                          iconFg: const Color(0xFF4648D4),
                          onTap: () => _open('/teachers'),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _OverviewCard(
                          label: 'Courses',
                          value: courses.text,
                          badge: '${courses.text} active',
                          badgeColor: const Color(0xFF059669),
                          badgeBg: const Color(0xFFECFDF5),
                          caption: 'Curriculum published',
                          icon: Icons.auto_stories_outlined,
                          iconBg: const Color(0xFFC9E6FF),
                          iconFg: const Color(0xFF003F5C),
                          onTap: () => _open('/courses'),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _OverviewCard(
                          label: 'Enrollments',
                          value: enrollments.text,
                          badge: 'Allocated',
                          badgeColor: const Color(0xFF4F46E5),
                          badgeBg: const Color(0xFFEEF0FF),
                          caption: 'Course allocations',
                          icon: Icons.how_to_reg_outlined,
                          iconBg: const Color(0xFFE6E9FF),
                          iconFg: const Color(0xFF334155),
                          onTap: () => _open('/enrollments'),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              // ═══════════════════════════════════════════════════════════
              // 3. NEEDS ATTENTION
              // ═══════════════════════════════════════════════════════════
              Row(
                children: [
                  const Icon(Icons.notification_important_outlined,
                      size: 22, color: Color(0xFFBA1A1A)),
                  const SizedBox(width: 8),
                  Text(
                    'Needs attention',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Auto-refreshed 2m ago',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF8E90A6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width >= 900 ? 3 : width >= 600 ? 2 : 1;
                  const gap = 16.0;
                  final cardWidth = (width - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _AttentionCard(
                          icon: Icons.assignment_late_outlined,
                          iconBg: const Color(0xFFFFE8CC),
                          iconFg: const Color(0xFFD97706),
                          value: pendingGrading.text,
                          valueColor: const Color(0xFF92400E),
                          title: 'Pending grading',
                          titleColor: const Color(0xFF92400E),
                          message: 'Student submissions need review.',
                          messageColor: const Color(0xFFB45309),
                          bgColor: const Color(0xFFFFF9F2),
                          onTap: () => _selectReport(DashboardReport.grading),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _AttentionCard(
                          icon: Icons.account_balance_wallet_outlined,
                          iconBg: const Color(0xFFFED7D7),
                          iconFg: const Color(0xFFBA1A1A),
                          value: pendingBalance.text,
                          valueColor: const Color(0xFFBA1A1A),
                          title: 'Pending balance',
                          titleColor: const Color(0xFFBA1A1A),
                          message: 'Fees still awaiting collection.',
                          messageColor: const Color(0xFFBA1A1A).withValues(alpha: 0.8),
                          bgColor: const Color(0xFFFFF5F5),
                          onTap: () => _selectReport(DashboardReport.dues),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _AttentionCard(
                          icon: Icons.videocam_outlined,
                          iconBg: const Color(0xFFD0E5FF),
                          iconFg: const Color(0xFF00577E),
                          value: upcomingClasses.text,
                          valueColor: const Color(0xFF003F5C),
                          title: 'Upcoming classes',
                          titleColor: const Color(0xFF003F5C),
                          message: 'No live class(es) running right now.',
                          messageColor: const Color(0xFF003F5C).withValues(alpha: 0.8),
                          bgColor: const Color(0xFFF0F7FF),
                          onTap: () => _open('/live-classes'),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              // ═══════════════════════════════════════════════════════════
              // 4. FINANCIAL OVERVIEW
              // ═══════════════════════════════════════════════════════════
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Financial overview',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF131B2E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Real-time fee collections, total receipts, and cashflow summary',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF525469),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6E9FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Currency: INR (₹)',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width >= 900 ? 3 : width >= 600 ? 2 : 1;
                  const gap = 16.0;
                  final cardWidth = (width - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _FinanceCard(
                          icon: Icons.trending_up_rounded,
                          iconBg: const Color(0xFFECFDF5),
                          iconFg: const Color(0xFF059669),
                          value: monthCollection.text,
                          label: 'Collected this month',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '+100% vs Sep',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                color: const Color(0xFF047857),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _FinanceCard(
                          icon: Icons.payments_outlined,
                          iconBg: const Color(0xFFEEF0FF),
                          iconFg: const Color(0xFF4F46E5),
                          value: totalPaid.text,
                          label: 'Total paid',
                          trailing: Text(
                            '2 vouchers',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: const Color(0xFF8E90A6),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _FinanceCard(
                          icon: Icons.warning_amber_rounded,
                          iconBg: const Color(0xFFFFE4E1),
                          iconFg: const Color(0xFFBA1A1A),
                          value: pendingBalance.text,
                          valueColor: const Color(0xFFBA1A1A),
                          label: 'Pending balance',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE4E1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Action Due',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                color: const Color(0xFFBA1A1A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              // ═══════════════════════════════════════════════════════════
              // 5. DETAILED REPORTS + SIDEBAR WIDGETS
              // ═══════════════════════════════════════════════════════════
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1000;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 8,
                          child: _DetailedReportsCard(
                            report: _selectedReport,
                            reportFuture: _reportFuture,
                            enrollmentStatus: _enrollmentStatus,
                            dateFrom: _dateFrom,
                            dateTo: _dateTo,
                            onSelectReport: _selectReport,
                            onEnrollmentStatusChanged: (value) {
                              setState(() {
                                _enrollmentStatus = value;
                                _loadReport();
                              });
                            },
                            onPickDate: _pickDate,
                            onClearDates: () {
                              setState(() {
                                _dateFrom = null;
                                _dateTo = null;
                                _loadReport();
                              });
                            },
                            onOpenReport: _open,
                            onRetry: () => setState(_loadReport),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 4,
                          child: Column(
                            children: [
                              _TodayScheduleCard(
                                onLaunchRoom: () => _open('/live-classes'),
                              ),
                              const SizedBox(height: 16),
                              _CampusBroadcastCard(
                                onWhatsAppAlert: () =>
                                    _open('/notifications/broadcast'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _DetailedReportsCard(
                        report: _selectedReport,
                        reportFuture: _reportFuture,
                        enrollmentStatus: _enrollmentStatus,
                        dateFrom: _dateFrom,
                        dateTo: _dateTo,
                        onSelectReport: _selectReport,
                        onEnrollmentStatusChanged: (value) {
                          setState(() {
                            _enrollmentStatus = value;
                            _loadReport();
                          });
                        },
                        onPickDate: _pickDate,
                        onClearDates: () {
                          setState(() {
                            _dateFrom = null;
                            _dateTo = null;
                            _loadReport();
                          });
                        },
                        onOpenReport: _open,
                        onRetry: () => setState(_loadReport),
                      ),
                      const SizedBox(height: 16),
                      _TodayScheduleCard(
                        onLaunchRoom: () => _open('/live-classes'),
                      ),
                      const SizedBox(height: 16),
                      _CampusBroadcastCard(
                        onWhatsAppAlert: () => _open('/notifications/broadcast'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              // ═══════════════════════════════════════════════════════════
              // 6. QUICK ACTIONS
              // ═══════════════════════════════════════════════════════════
              const _SectionHeader(
                title: 'Quick actions',
                trailing: 'Institutional Shortcuts',
              ),
              const SizedBox(height: 14),
              _QuickActionsGrid(
                canManageAcademy: widget.canManageAcademy,
                onOpen: _open,
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
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF131B2E),
            letterSpacing: -0.3,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF8E90A6),
              fontWeight: FontWeight.w600,
            ),
          ),
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

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
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
    final firms = ref.watch(firmsListProvider);
    final admins = ref.watch(allFirmAdminsProvider);
    final firmList = firms.valueOrNull ?? [];
    final adminList = admins.valueOrNull ?? [];

    void refresh() {
      ref.invalidate(firmsListProvider);
      ref.invalidate(allFirmAdminsProvider);
    }

    return RefreshIndicator(
      onRefresh: () async => refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _HeroBanner(
            academyName: 'Platform administration',
            campusId: 'ADMIN',
            studentCount: '${firmList.length}',
            refreshing: firms.isLoading || admins.isLoading,
            onRefresh: refresh,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _MetricCard(
                label: 'Academies',
                value: '${firmList.length}',
                caption: 'Registered organizations',
                icon: Icons.apartment_outlined,
                color: colors.primary,
                onTap: () => context.go('/firms'),
              ),
              _MetricCard(
                label: 'Active academies',
                value: '${firmList.where((item) => item.isActive).length}',
                caption: 'Currently operational',
                icon: Icons.verified_outlined,
                color: colors.success,
                onTap: () => context.go('/firms'),
              ),
              _MetricCard(
                label: 'Firm admins',
                value: '${adminList.length}',
                caption: 'Academy administrators',
                icon: Icons.admin_panel_settings_outlined,
                color: const Color(0xFF7C3AED),
                onTap: () => context.go('/firm-admins'),
              ),
              _MetricCard(
                label: 'Active admins',
                value:
                '${adminList.where((item) => item.isActive).length}',
                caption: 'Accounts with active access',
                icon: Icons.people_outline_rounded,
                color: const Color(0xFF0284C7),
                onTap: () => context.go('/firm-admins'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const _SectionHeader(title: 'Platform actions'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _QuickActionTile(
                label: 'Manage academies',
                icon: Icons.business_outlined,
                onTap: () => context.go('/firms'),
              ),
              _QuickActionTile(
                label: 'Manage firm admins',
                icon: Icons.manage_accounts_outlined,
                onTap: () => context.go('/firm-admins'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _InlineMessage(
            icon: Icons.info_outline_rounded,
            message:
            'Firm-wise students, fees and course analytics will appear here when the Super Admin overview API is available.',
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label, value, caption;
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
                foreground: color),
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
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: context.colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.primaryTonal.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.colors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
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
  final String title, message;
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
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 18),
                GradientButton(label: actionLabel!, onPressed: onAction),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _displayDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';