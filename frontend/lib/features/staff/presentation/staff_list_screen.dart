import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';
import '../data/staff.dart';
import '../data/staff_repository.dart';

class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({super.key});
  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  final searchController = TextEditingController();
  late Future<StaffPage> result;
  String search = '';
  String statusFilter = 'ALL'; // ALL | ACTIVE | INACTIVE | DEPT
  String selectedDepartment = '';
  int page = 1;
  bool creating = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    result = ref.read(staffRepositoryProvider).list(search: search, page: page);
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
    final repository = ref.read(staffRepositoryProvider);
    setState(() => creating = true);
    try {
      final created = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CreateStaffDialog(repository),
      );
      if (!mounted || created != true) return;
      setState(() {
        searchController.clear();
        search = '';
        statusFilter = 'ALL';
        selectedDepartment = '';
        page = 1;
        reload();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff created successfully.')),
      );
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  void _resetFilters() {
    setState(() {
      searchController.clear();
      search = '';
      statusFilter = 'ALL';
      selectedDepartment = '';
      page = 1;
      reload();
    });
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
          // Title + refresh + "Add staff" CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Text(
                  'Staff',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => setState(reload),
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
                  onPressed: creating ? null : _openCreate,
                  icon: const Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 18,
                  ),
                  label: const Text('Add staff'),
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
            child: FutureBuilder<StaffPage>(
              future: result,
              builder: (context, snapshot) {
                final state = adminFutureState(
                  snapshot,
                  noun: 'staff',
                  onRetry: () => setState(reload),
                );
                final data = snapshot.connectionState == ConnectionState.done &&
                    !snapshot.hasError
                    ? snapshot.data
                    : null;
                final onPage = data?.results ?? const <Staff>[];
                final activeHere = onPage.where((s) => s.isActive).length;
                final inactiveHere = onPage.length - activeHere;
                final activePct = data == null || onPage.isEmpty
                    ? '0% online'
                    : '${(activeHere * 100 / onPage.length).round()}% active';

                final departments = onPage
                    .map((s) => s.department.trim())
                    .where((d) => d.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();

                final visibleStaff = switch (statusFilter) {
                  'ACTIVE' => onPage.where((s) => s.isActive).toList(),
                  'INACTIVE' => onPage.where((s) => !s.isActive).toList(),
                  'DEPT' => selectedDepartment.isEmpty
                      ? onPage
                      : onPage
                      .where(
                        (s) => s.department.trim() == selectedDepartment,
                  )
                      .toList(),
                  _ => onPage,
                };

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  children: [
                    // 2x2 / Responsive KPI grid
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
                              child: _StaffStatCard(
                                label: search.isEmpty
                                    ? 'Total staff'
                                    : 'Matching',
                                value: data == null ? '…' : '${data.count}',
                                caption: search.isEmpty
                                    ? 'All members'
                                    : 'Current search',
                                icon: Icons.groups_rounded,
                                iconColor: const Color(0xFF4F46E5),
                                iconBg: const Color(0xFFEEF2FF),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _StaffStatCard(
                                label: 'Active',
                                value: data == null ? '…' : '$activeHere',
                                caption: activePct,
                                captionColor: const Color(0xFF059669),
                                showGreenDot: true,
                                icon: Icons.verified_rounded,
                                iconColor: const Color(0xFF059669),
                                iconBg: const Color(0xFFECFDF5),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _StaffStatCard(
                                label: 'Inactive',
                                value: data == null ? '…' : '$inactiveHere',
                                caption: inactiveHere == 0
                                    ? 'No action required'
                                    : 'Needs review',
                                icon: Icons.person_off_outlined,
                                iconColor: const Color(0xFFE11D48),
                                iconBg: const Color(0xFFFFF1F2),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _StaffStatCard(
                                label: 'Current page',
                                value: '$page',
                                caption: '20 per page',
                                icon: Icons.layers_outlined,
                                iconColor: const Color(0xFF0284C7),
                                iconBg: const Color(0xFFF0F9FF),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Search bar with blue "Search" button
                    _StaffSearchBar(
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

                    // Filter chips row ("All", "Active", "Inactive", departments)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _StaffFilterPill(
                            label: 'All (${data?.count ?? 0})',
                            selected: statusFilter == 'ALL',
                            onTap: () => setState(() {
                              statusFilter = 'ALL';
                              selectedDepartment = '';
                            }),
                          ),
                          const SizedBox(width: 8),
                          _StaffFilterPill(
                            label: 'Active',
                            selected: statusFilter == 'ACTIVE',
                            onTap: () => setState(() {
                              statusFilter = 'ACTIVE';
                              selectedDepartment = '';
                            }),
                          ),
                          const SizedBox(width: 8),
                          _StaffFilterPill(
                            label: 'Inactive',
                            selected: statusFilter == 'INACTIVE',
                            onTap: () => setState(() {
                              statusFilter = 'INACTIVE';
                              selectedDepartment = '';
                            }),
                          ),
                          for (final dept in departments) ...[
                            const SizedBox(width: 8),
                            _StaffFilterPill(
                              label: dept,
                              selected: statusFilter == 'DEPT' &&
                                  selectedDepartment == dept,
                              onTap: () => setState(() {
                                statusFilter = 'DEPT';
                                selectedDepartment = dept;
                              }),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (state != null)
                      state
                    else if (visibleStaff.isEmpty)
                      _EmptyStaffCard(
                        creating: creating,
                        onAddStaff: _openCreate,
                        onImportCsv: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Use Add staff to create records or import from your academy portal.',
                              ),
                            ),
                          );
                        },
                        onReset: _resetFilters,
                      )
                    else ...[
                        for (final staff in visibleStaff) ...[
                          _StaffDirectoryCard(
                            staff: staff,
                            onTap: () async {
                              await context.push('/staff/${staff.uuid}');
                              if (mounted) setState(reload);
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        AdminPager(
                          page: page,
                          pageSize: 20,
                          total: data!.count,
                          noun: 'staff',
                          onPage: goToPage,
                        ),
                      ],

                    const SizedBox(height: 18),

                    // Role-Based Governance card
                    const _RoleGovernanceCard(),

                    const SizedBox(height: 14),

                    // Bottom assistance banner
                    _StaffAssistanceCard(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Assign roles and departments while adding or editing staff.',
                            ),
                          ),
                        );
                      },
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

class _StaffStatCard extends StatelessWidget {
  const _StaffStatCard({
    required this.label,
    required this.value,
    required this.caption,
    this.captionColor = const Color(0xFF64748B),
    this.showGreenDot = false,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });

  final String label;
  final String value;
  final String caption;
  final Color captionColor;
  final bool showGreenDot;
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
              if (showGreenDot) ...[
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

class _StaffSearchBar extends StatelessWidget {
  const _StaffSearchBar({
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
                hintText: 'Search name, ID, or department...',
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

class _StaffFilterPill extends StatelessWidget {
  const _StaffFilterPill({
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

class _EmptyStaffCard extends StatelessWidget {
  const _EmptyStaffCard({
    required this.creating,
    required this.onAddStaff,
    required this.onImportCsv,
    required this.onReset,
  });

  final bool creating;
  final VoidCallback onAddStaff;
  final VoidCallback onImportCsv;
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
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.manage_accounts_outlined,
                  size: 36,
                  color: Color(0xFF4338CA),
                ),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3730A3),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'No staff found',
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
              'Your institution directory is clean. Add faculty admins, registrars, or clerical staff to assign roles.',
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
              onPressed: creating ? null : onAddStaff,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Add New Staff'),
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
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: creating ? null : onImportCsv,
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: const Text('Import CSV'),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFEEF2FF),
                foregroundColor: const Color(0xFF3730A3),
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onReset,
            child: const Text('Reset filters'),
          ),
        ],
      ),
    );
  }
}

class _RoleGovernanceCard extends StatelessWidget {
  const _RoleGovernanceCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 19,
                  color: Color(0xFF3730A3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Role-Based Governance',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Academy Security Standard',
                      style: textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Staff accounts maintain granular access across the ERP. Role assignments instantly sync capabilities for live sessions, grading books, batch announcements, and fee registers.',
            style: textTheme.bodySmall?.copyWith(
              color: const Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              Expanded(
                child: _RoleMiniTile(
                  icon: Icons.admin_panel_settings_outlined,
                  iconColor: Color(0xFF3730A3),
                  title: 'Admin Access',
                  subtitle: 'Full System',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _RoleMiniTile(
                  icon: Icons.co_present_outlined,
                  iconColor: Color(0xFF059669),
                  title: 'Instructor',
                  subtitle: 'Classes & Marks',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _RoleMiniTile(
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: Color(0xFF4F46E5),
                  title: 'Finance',
                  subtitle: 'Fee Desk',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleMiniTile extends StatelessWidget {
  const _RoleMiniTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffAssistanceCard extends StatelessWidget {
  const _StaffAssistanceCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF2FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.help_outline_rounded,
                  size: 20,
                  color: Color(0xFF3730A3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need staff setup assistance?',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Explore role mapping templates',
                      style: textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffDirectoryCard extends StatelessWidget {
  const _StaffDirectoryCard({
    required this.staff,
    required this.onTap,
  });

  final Staff staff;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final displayName =
    staff.fullName.trim().isEmpty ? staff.employeeId : staff.fullName;
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
                                staff.employeeId,
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
                          staff.designation.isEmpty
                              ? 'Staff'
                              : staff.designation,
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
                      color: staff.isActive
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
                            color: staff.isActive
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFDC2626),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          staff.isActive ? 'Active' : 'Inactive',
                          style: textTheme.labelSmall?.copyWith(
                            color: staff.isActive
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
                    if (staff.department.isNotEmpty) ...[
                      const Icon(
                        Icons.business_outlined,
                        size: 14,
                        color: Color(0xFF3730A3),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        staff.department,
                        style: textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF1E293B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (staff.department.isNotEmpty && staff.phone.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '•',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ),
                    if (staff.phone.isNotEmpty) ...[
                      const Icon(
                        Icons.call_outlined,
                        size: 14,
                        color: Color(0xFF1D4ED8),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          staff.phone,
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

class _CreateStaffDialog extends StatefulWidget {
  const _CreateStaffDialog(
      this.repository,
      );

  final StaffRepository repository;

  @override
  State<_CreateStaffDialog> createState() => _CreateStaffDialogState();
}

class _CreateStaffDialogState extends State<_CreateStaffDialog> {
  final formKey = GlobalKey<FormState>();
  final employeeId = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final designation = TextEditingController();
  final department = TextEditingController();
  final address = TextEditingController();

  DateTime? joinedDate;
  bool saving = false;
  String? error;

  @override
  void dispose() {
    employeeId.dispose();
    firstName.dispose();
    lastName.dispose();
    email.dispose();
    phone.dispose();
    designation.dispose();
    department.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    if (!(formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

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
        designation: designation.text,
        department: department.text,
        joinedDate: joinedDate,
        address: address.text,
      );
      if (!mounted) return;
      setState(() => saving = false);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not create staff. Please try again.');
      }
    } finally {
      if (mounted && saving) setState(() => saving = false);
    }
  }

  Future<void> pickJoinedDate() async {
    if (saving) return;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: joinedDate ?? DateTime.now(),
    );
    if (!mounted || saving || picked == null) return;
    setState(() => joinedDate = picked);
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
      title: 'Add staff',
      subtitle: 'Create a staff record for your academy.',
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
              label: 'Designation',
              controller: designation,
              maxLength: 150,
            ),
            const SizedBox(height: 16),
            field(
              label: 'Department',
              controller: department,
              maxLength: 150,
            ),
            const SizedBox(height: 16),
            field(
              label: 'Address',
              controller: address,
              maxLines: 3,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 16),
            FieldLabel(
              label: 'Joined date',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(joinedDate == null
                    ? 'Select date (optional)'
                    : '${joinedDate!.year}-'
                    '${joinedDate!.month.toString().padLeft(2, '0')}-'
                    '${joinedDate!.day.toString().padLeft(2, '0')}'),
                leading: const Icon(Icons.calendar_today_outlined),
                trailing: joinedDate == null
                    ? null
                    : IconButton(
                  tooltip: 'Clear joined date',
                  onPressed: saving
                      ? null
                      : () => setState(() => joinedDate = null),
                  icon: const Icon(Icons.clear_rounded),
                ),
                onTap: saving ? null : pickJoinedDate,
              ),
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
          label: 'Save staff',
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