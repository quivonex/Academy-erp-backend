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
      canManageAcademy: session.role == UserRole.academyAdmin,
    );
  }
}

class _AcademyDashboard extends ConsumerStatefulWidget {
  const _AcademyDashboard({
    super.key,
    required this.academyName,
    required this.canManageAcademy,
  });

  final String academyName;
  final bool canManageAcademy;

  @override
  ConsumerState<_AcademyDashboard> createState() =>
      _AcademyDashboardState();
}

class _AcademyDashboardState extends ConsumerState<_AcademyDashboard> {
  late Future<DashboardSummary> _summaryFuture;
  late Future<DashboardReportPage> _reportFuture;
  DashboardReport _selectedReport = DashboardReport.collection;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _enrollmentStatus;
  bool _refreshing = false;

  DashboardRepository get _repository =>
      ref.read(dashboardRepositoryProvider);

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
    } catch (_) {
      // Each FutureBuilder below presents a retry state.
    } finally {
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
                subtitle: '${students.text} students currently registered',
                refreshing: _refreshing,
                onRefresh: _refresh,
              ),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Academy overview'),
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
                    caption: teachers.caption ?? 'Teaching staff',
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
              _SectionTitle(title: 'Needs attention'),
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
                    onTap: () => _selectReport(DashboardReport.grading),
                  ),
                  _AttentionCard(
                    title: 'Pending fee balance',
                    value: pendingBalance.text,
                    message: 'Fees still awaiting collection.',
                    icon: Icons.account_balance_wallet_outlined,
                    background: const Color(0xFFFFF1F2),
                    foreground: const Color(0xFFBE123C),
                    onTap: () => _selectReport(DashboardReport.dues),
                  ),
                  _AttentionCard(
                    title: 'Upcoming classes',
                    value: upcomingClasses.text,
                    message: '$liveNow class(es) live right now.',
                    icon: Icons.video_camera_front_outlined,
                    background: const Color(0xFFEFF6FF),
                    foreground: const Color(0xFF1D4ED8),
                    onTap: () => _open('/live-classes'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _SectionTitle(title: 'Financial overview'),
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
              _SectionTitle(
                title: 'Detailed reports',
                subtitle: 'Live records from your academy data',
              ),
              const SizedBox(height: 12),
              _ReportsCard(
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
              const SizedBox(height: 28),
              _SectionTitle(title: 'Quick actions'),
              const SizedBox(height: 12),
              _QuickActions(
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

class _ReportsCard extends StatelessWidget {
  const _ReportsCard({
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
    return AdminCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in DashboardReport.values)
                ChoiceChip(
                  label: Text(type.title),
                  selected: report == type,
                  onSelected: (_) => onSelectReport(type),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (report.usesDates)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _DateFilterButton(
                  label: dateFrom == null
                      ? 'From date'
                      : _displayDate(dateFrom!),
                  onPressed: () => onPickDate(isFrom: true),
                ),
                _DateFilterButton(
                  label: dateTo == null ? 'To date' : _displayDate(dateTo!),
                  onPressed: () => onPickDate(isFrom: false),
                ),
                if (dateFrom != null || dateTo != null)
                  TextButton.icon(
                    onPressed: onClearDates,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Clear dates'),
                  ),
              ],
            ),
          if (report == DashboardReport.enrollments) ...[
            if (report.usesDates) const SizedBox(height: 12),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                value: enrollmentStatus,
                decoration: const InputDecoration(labelText: 'Enrollment status'),
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
          const SizedBox(height: 18),
          FutureBuilder<DashboardReportPage>(
            future: reportFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const SizedBox(
                  height: 164,
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
              return _ReportResults(
                page: page,
                onOpenReport: onOpenReport,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReportResults extends StatelessWidget {
  const _ReportResults({required this.page, required this.onOpenReport});

  final DashboardReportPage page;
  final ValueChanged<String> onOpenReport;

  @override
  Widget build(BuildContext context) {
    if (page.rows.isEmpty) {
      return const _InlineMessage(
        icon: Icons.inbox_outlined,
        message: 'No records found for this report.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            for (final metric in page.metrics)
              Text(
                '${metric.label}: ${metric.text}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: context.colors.textMuted,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        for (final row in page.rows.take(5))
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: AdminIconTile(
              icon: Icons.insert_chart_outlined_rounded,
              background: context.colors.primaryTonal,
              foreground: context.colors.primary,
            ),
            title: Text(row.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (row.details.isNotEmpty)
                  Text(
                    row.details.join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            trailing: row.route == null
                ? null
                : const Icon(Icons.chevron_right_rounded),
            onTap: row.route == null ? null : () => onOpenReport(row.route!),
          ),
        if (page.count > page.rows.length)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${page.count} total records. Use the respective module to view all records.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
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
          _HeroSection(
            academyName: 'Platform administration',
            subtitle: '${firmList.length} registered academies',
            refreshing: firms.isLoading || admins.isLoading,
            onRefresh: refresh,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _MetricCard(label: 'Academies', value: '${firmList.length}', caption: 'Registered organizations', icon: Icons.apartment_outlined, color: colors.primary, onTap: () => context.go('/firms')),
              _MetricCard(label: 'Active academies', value: '${firmList.where((item) => item.isActive).length}', caption: 'Currently operational', icon: Icons.verified_outlined, color: colors.success, onTap: () => context.go('/firms')),
              _MetricCard(label: 'Firm admins', value: '${adminList.length}', caption: 'Academy administrators', icon: Icons.admin_panel_settings_outlined, color: const Color(0xFF7C3AED), onTap: () => context.go('/firm-admins')),
              _MetricCard(label: 'Active admins', value: '${adminList.where((item) => item.isActive).length}', caption: 'Accounts with active access', icon: Icons.people_outline_rounded, color: const Color(0xFF0284C7), onTap: () => context.go('/firm-admins')),
            ],
          ),
          const SizedBox(height: 28),
          _SectionTitle(title: 'Platform actions'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _QuickAction(label: 'Manage academies', icon: Icons.business_outlined, onTap: () => context.go('/firms')),
              _QuickAction(label: 'Manage firm admins', icon: Icons.manage_accounts_outlined, onTap: () => context.go('/firm-admins')),
            ],
          ),
          const SizedBox(height: 20),
          const _InlineMessage(
            icon: Icons.info_outline_rounded,
            message: 'Firm-wise students, fees and course analytics will appear here when the Super Admin overview API is available.',
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.academyName, required this.subtitle, required this.refreshing, required this.onRefresh});
  final String academyName;
  final String subtitle;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(gradient: context.colors.heroGradient, borderRadius: BorderRadius.circular(20), boxShadow: context.colors.heroShadow),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 18,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Welcome back', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(academyName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.86))),
        ]),
        OutlinedButton.icon(
          onPressed: refreshing ? null : onRefresh,
          icon: refreshing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.refresh_rounded),
          label: Text(refreshing ? 'Refreshing...' : 'Refresh'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
    if (subtitle != null) ...[const SizedBox(height: 3), Text(subtitle!, style: Theme.of(context).textTheme.bodySmall)],
  ]);
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.caption, required this.icon, required this.color, required this.onTap});
  final String label, value, caption;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(width: 245, child: AdminCard(onTap: onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    AdminIconTile(icon: icon, background: color.withValues(alpha: 0.12), foreground: color),
    const SizedBox(height: 20),
    Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
    const SizedBox(height: 4),
    Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
    const SizedBox(height: 4),
    Text(caption, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.textMuted)),
  ])));
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.title, required this.value, required this.message, required this.icon, required this.background, required this.foreground, required this.onTap});
  final String title, value, message;
  final IconData icon;
  final Color background, foreground;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(width: 320, child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)), child: Row(children: [
    AdminIconTile(icon: icon, background: Colors.white, foreground: foreground), const SizedBox(width: 14),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: foreground)),
      Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 3), Text(message, style: Theme.of(context).textTheme.bodySmall),
    ])), Icon(Icons.arrow_forward_rounded, color: foreground),
  ]))));
}

class _FinanceValue extends StatelessWidget {
  const _FinanceValue({required this.label, required this.value, required this.icon, required this.color});
  final String label, value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(width: 220, child: Row(children: [
    AdminIconTile(icon: icon, background: color.withValues(alpha: 0.12), foreground: color), const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.textMuted)),
    ])),
  ]));
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.canManageAcademy, required this.onOpen});
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
    return Wrap(spacing: 12, runSpacing: 12, children: [
      for (final action in actions)
        if (canManageAcademy || !action.adminOnly)
          _QuickAction(label: action.label, icon: action.icon, onTap: () => onOpen(action.route)),
    ]);
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(onPressed: onTap, icon: Icon(icon, size: 19), label: Text(label), style: OutlinedButton.styleFrom(foregroundColor: context.colors.textPrimary, side: BorderSide(color: context.colors.borderSubtle), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)));
}

class _DateFilterButton extends StatelessWidget {
  const _DateFilterButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(onPressed: onPressed, icon: const Icon(Icons.calendar_today_outlined, size: 17), label: Text(label));
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.icon, required this.message, this.actionLabel, this.onAction});
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: context.colors.primaryTonal.withValues(alpha: 0.48), borderRadius: BorderRadius.circular(14)), child: Row(children: [
    Icon(icon, color: context.colors.primary), const SizedBox(width: 10), Expanded(child: Text(message)),
    if (actionLabel != null && onAction != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
  ]));
}

class _DashboardMessage extends StatelessWidget {
  const _DashboardMessage({required this.icon, required this.title, required this.message, this.actionLabel, this.onAction});
  final IconData icon;
  final String title, message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Center(child: AdminCard(child: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 52, color: context.colors.textMuted), const SizedBox(height: 16),
    Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 8),
    Text(message, textAlign: TextAlign.center),
    if (actionLabel != null && onAction != null) ...[const SizedBox(height: 18), GradientButton(label: actionLabel!, onPressed: onAction)],
  ]))));
}

String _displayDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
