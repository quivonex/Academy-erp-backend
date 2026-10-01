import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/session/user_role.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/status_pill.dart';
import '../../firms/data/firm_admin_model.dart';
import '../../firms/data/firm_admin_repository.dart';
import '../../firms/data/firm_model.dart';
import '../../firms/data/firm_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);

    if (session.role != UserRole.superAdmin) {
      return _AcademyWelcome(
        firmName: session.firmName ?? 'Your academy',
        roleLabel: session.role?.apiValue ?? '',
      );
    }

    final firms = ref.watch(firmsListProvider);
    final admins = ref.watch(allFirmAdminsProvider);

    void refresh() {
      ref.invalidate(firmsListProvider);
      ref.invalidate(allFirmAdminsProvider);
    }

    final firmList = firms.valueOrNull;
    final adminList = admins.valueOrNull;

    final totalFirms = firmList?.length;
    final activeFirms = firmList?.where((firm) => firm.isActive).length;
    final totalAdmins = adminList?.length;
    final activeAdmins = adminList?.where((admin) => admin.isActive).length;

    String metric(AsyncValue<Object?> state, int? value) {
      if (value != null) return '$value';
      if (state.hasError) return '—';
      return '…';
    }

    final operationalPct = (totalFirms == null || totalFirms == 0)
        ? null
        : ((activeFirms ?? 0) * 100 / totalFirms).round();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            eyebrow: const SoftBadge(
              label: 'Executive dashboard',
              dot: true,
            ),
            title: 'Academy overview',
            subtitle: "Welcome back — here's what's happening across your "
                'academies.',
            actions: [
              AdminOutlineButton(
                label: 'Refresh',
                icon: Icons.refresh_rounded,
                onPressed: refresh,
              ),
            ],
          ),
          const SizedBox(height: 28),

          // KPI cards
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 3
                  : constraints.maxWidth >= 560
                      ? 2
                      : 1;
              const gap = 20.0;
              final cardWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _KpiCard(
                      title: 'Academies',
                      value: metric(firms, totalFirms),
                      icon: Icons.apartment_rounded,
                      badge: totalFirms == null
                          ? null
                          : SoftBadge(
                              label: totalFirms == 1
                                  ? '1 registered'
                                  : '$totalFirms registered',
                              background: const Color(0xFFECFDF5),
                              foreground: const Color(0xFF059669),
                            ),
                      footLabel: 'Configured branches',
                      footValue: 'Multi-tenant',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _KpiCard(
                      title: 'Active academies',
                      value: metric(firms, activeFirms),
                      icon: Icons.verified_outlined,
                      iconBg: const Color(0xFFECFDF5),
                      iconFg: const Color(0xFF059669),
                      badge: operationalPct == null
                          ? null
                          : SoftBadge(
                              label: '$operationalPct% operational',
                              background: const Color(0xFFECFDF5),
                              foreground: const Color(0xFF059669),
                            ),
                      footLabel: 'Inactive / suspended',
                      footValue: totalFirms == null
                          ? '—'
                          : '${totalFirms - (activeFirms ?? 0)}',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _KpiCard(
                      title: 'Firm admins',
                      value: metric(admins, totalAdmins),
                      icon: Icons.admin_panel_settings_outlined,
                      iconBg: const Color(0xFFF5F3FF),
                      iconFg: const Color(0xFF7C3AED),
                      badge: activeAdmins == null
                          ? null
                          : SoftBadge(
                              label: '$activeAdmins active',
                              background: const Color(0xFFF5F3FF),
                              foreground: const Color(0xFF7C3AED),
                            ),
                      footLabel: 'Access role',
                      footValue: 'FIRM_ADMIN',
                    ),
                  ),
                ],
              );
            },
          ),

          if (firms.hasError || admins.hasError) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Some dashboard data could not be loaded.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF92400E),
                          ),
                    ),
                  ),
                  TextButton(
                    onPressed: refresh,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Quick actions
          AdminCard(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textTheme = Theme.of(context).textTheme;
                final info = Row(
                  children: [
                    const AdminIconTile(icon: Icons.bolt_rounded, size: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Direct actions & directory management',
                            style: jakarta(textTheme.titleMedium),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Jump to the firm directory or the admin roster.',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final buttons = Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    GradientButton(
                      label: 'View firms',
                      icon: Icons.apartment_rounded,
                      onPressed: () => context.go('/firms'),
                    ),
                    AdminOutlineButton(
                      label: 'View firm admins',
                      icon: Icons.group_outlined,
                      onPressed: () => context.go('/firm-admins'),
                    ),
                  ],
                );

                if (constraints.maxWidth < 720) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [info, const SizedBox(height: 16), buttons],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: info),
                    const SizedBox(width: 16),
                    buttons,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Institutions + recent admins
          LayoutBuilder(
            builder: (context, constraints) {
              final institutions = _InstitutionsCard(
                firms: firms,
                onRetry: refresh,
              );
              final recent = _RecentAdminsCard(admins: admins);

              if (constraints.maxWidth < 980) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [institutions, const SizedBox(height: 24), recent],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: institutions),
                  const SizedBox(width: 24),
                  Expanded(child: recent),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.footLabel,
    required this.footValue,
    this.badge,
    this.iconBg,
    this.iconFg,
  });

  final String title;
  final String value;
  final IconData icon;
  final Widget? badge;
  final String footLabel;
  final String footValue;
  final Color? iconBg;
  final Color? iconFg;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
              AdminIconTile(
                icon: icon,
                size: 40,
                background: iconBg,
                foreground: iconFg,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                value,
                style: jakarta(
                  textTheme.displayLarge?.copyWith(
                    fontSize: 40,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                    color: const Color(0xFF0F172A),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (badge != null) badge!,
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFEEF0F5)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  footLabel,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ),
              Text(
                footValue,
                style: textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InstitutionsCard extends StatelessWidget {
  const _InstitutionsCard({required this.firms, required this.onRetry});

  final AsyncValue<List<Firm>> firms;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final list = firms.valueOrNull;

    Widget body;
    if (list == null && firms.hasError) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text(
              'Could not load institutions.',
              style: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
            ),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      );
    } else if (list == null) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (list.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text(
            'No institutions registered yet.',
            style: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
          ),
        ),
      );
    } else {
      body = Column(
        children: [
          for (final firm in list.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FirmRow(firm: firm),
            ),
        ],
      );
    }

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enrolled institutions',
                      style: jakarta(textTheme.titleLarge),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Registered institutions under your supervision',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (list != null)
                SoftBadge(
                  label: 'Total: ${list.length}',
                  background: const Color(0xFFF1F5F9),
                  foreground: const Color(0xFF334155),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFEEF0F5)),
          const SizedBox(height: 16),
          body,
          if (list != null && list.length > 6)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.go('/firms'),
                child: Text('View all ${list.length} firms'),
              ),
            ),
        ],
      ),
    );
  }
}

class _FirmRow extends StatelessWidget {
  const _FirmRow({required this.firm});

  final Firm firm;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    final meta = [
      'Code: ${firm.code}',
      if (firm.email?.trim().isNotEmpty == true) firm.email!.trim(),
      if (firm.address?.trim().isNotEmpty == true) firm.address!.trim(),
    ].join('  •  ');

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        hoverColor: const Color(0xFFF8FAFC),
        onTap: () => context.push('/firms/${firm.uuid}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primaryTonal,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  adminInitials(firm.name),
                  style: jakarta(
                    textTheme.labelLarge?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firm.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusPill(
                label: firm.status.toUpperCase(),
                tone: toneForStatus(firm.status),
                compact: true,
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: colors.textSubtle),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentAdminsCard extends StatelessWidget {
  const _RecentAdminsCard({required this.admins});

  final AsyncValue<List<FirmAdmin>> admins;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final list = admins.valueOrNull;

    final recent = list == null
        ? <FirmAdmin>[]
        : ([...list]..sort((a, b) => b.dateJoined.compareTo(a.dateJoined)))
            .take(5)
            .toList();

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recently added admins',
                  style: jakarta(textTheme.titleLarge),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/firm-admins'),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFEEF0F5)),
          const SizedBox(height: 16),
          if (list == null && admins.hasError)
            Text(
              'Could not load admins.',
              style: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
            )
          else if (list == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (recent.isEmpty)
            Text(
              'No firm admins yet.',
              style: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
            )
          else
            for (final admin in recent)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: admin.isActive
                            ? colors.primary
                            : const Color(0xFFCBD5E1),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            admin.fullName.trim().isEmpty
                                ? admin.email
                                : admin.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            admin.firmName.isEmpty
                                ? admin.email
                                : admin.firmName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Joined ${formatDate(admin.dateJoined)}',
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.textSubtle,
                              fontWeight: FontWeight.w500,
                            ),
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

class _AcademyWelcome extends StatelessWidget {
  const _AcademyWelcome({required this.firmName, required this.roleLabel});

  final String firmName;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AdminPageHeader(
            eyebrow: SoftBadge(label: 'Academy workspace', dot: true),
            title: 'Welcome to Academy ERP',
            subtitle: 'Manage your students, courses and daily operations.',
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3525CD), Color(0xFF4F46E5), Color(0xFF6366F1)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x404F46E5),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    adminInitials(firmName),
                    style: jakarta(
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firmName,
                        style: jakarta(
                          textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Signed in as $roleLabel',
                        style: textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFDAD7FF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              GradientButton(
                label: 'Students',
                icon: Icons.school_outlined,
                onPressed: () => context.go('/students'),
              ),
              AdminOutlineButton(
                label: 'Courses',
                icon: Icons.auto_stories_outlined,
                onPressed: () => context.go('/courses'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
