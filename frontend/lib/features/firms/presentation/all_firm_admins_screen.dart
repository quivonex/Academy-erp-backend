import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/status_pill.dart';
import '../data/firm_admin_model.dart';
import '../data/firm_admin_repository.dart';
import 'firm_admins_section.dart' show prettyUserType;

class AllFirmAdminsScreen extends ConsumerStatefulWidget {
  const AllFirmAdminsScreen({super.key});

  @override
  ConsumerState<AllFirmAdminsScreen> createState() =>
      _AllFirmAdminsScreenState();
}

class _AllFirmAdminsScreenState
    extends ConsumerState<AllFirmAdminsScreen> {
  final _searchController = TextEditingController();

  String _search = '';
  bool? _activeFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(allFirmAdminsProvider);

    try {
      await ref.read(allFirmAdminsProvider.future);
    } catch (_) {
      // The provider displays the request error.
    }
  }

  Widget _filterChip(String label, bool? value, {int? count}) {
    return CountFilterPill(
      label: label,
      count: count,
      selected: _activeFilter == value,
      onTap: () => setState(() => _activeFilter = value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminsAsync = ref.watch(allFirmAdminsProvider);
    final all = adminsAsync.valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          title: 'All firm admins',
          subtitle: 'Administrators across every academy on the platform.',
          titleTrailing: [
            if (all != null)
              SoftBadge(
                label: all.length == 1
                    ? '1 admin'
                    : '${all.length} admins',
                dot: true,
                background: const Color(0xFFF1F5F9),
                foreground: const Color(0xFF334155),
              ),
          ],
          actions: [
            AdminOutlineButton(
              label: 'Refresh',
              icon: Icons.refresh_rounded,
              onPressed: _refresh,
            ),
          ],
        ),
        const SizedBox(height: 22),
        AdminSearchField(
          controller: _searchController,
          hint: 'Search name, email or firm…',
          onChanged: (value) {
            setState(() => _search = value.trim().toLowerCase());
          },
          onClear: () {
            _searchController.clear();
            setState(() => _search = '');
          },
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _filterChip('ALL', null, count: all?.length),
            _filterChip(
              'ACTIVE',
              true,
              count: all?.where((a) => a.isActive).length,
            ),
            _filterChip(
              'INACTIVE',
              false,
              count: all?.where((a) => !a.isActive).length,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: adminsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, _) => SingleChildScrollView(
              child: AdminStateMessage(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load firm admins',
                message: '$error',
                actionLabel: 'Retry',
                onAction: _refresh,
                isError: true,
              ),
            ),
            data: (admins) {
              final filtered = admins.where((admin) {
                final matchesStatus = _activeFilter == null ||
                    admin.isActive == _activeFilter;

                final searchable = [
                  admin.fullName,
                  admin.firstName,
                  admin.lastName,
                  admin.email,
                  admin.firmName,
                ].join(' ').toLowerCase();

                return matchesStatus &&
                    searchable.contains(_search);
              }).toList();

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Showing ${filtered.length} of ${admins.length} admins',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (filtered.isEmpty)
                      const AdminStateMessage(
                        icon: Icons.search_off_rounded,
                        title: 'No matching admins',
                        message: 'No firm admins match your filters.',
                      ),
                    for (final admin in filtered)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AdminCard(
                          admin: admin,
                          onTap: admin.firmUuid.isEmpty
                              ? null
                              : () => context.push(
                                    '/firms/${admin.firmUuid}',
                                  ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({required this.admin, required this.onTap});

  final FirmAdmin admin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final name =
        admin.fullName.trim().isEmpty ? admin.email : admin.fullName.trim();
    final metaStyle = textTheme.bodySmall?.copyWith(
      color: const Color(0xFF475569),
    );

    Widget meta(IconData icon, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: colors.textSubtle),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: metaStyle,
              ),
            ),
          ],
        );

    return AdminCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      onTap: onTap,
      child: Row(
        children: [
          GradientAvatar(
            label: adminInitials(name),
            seed: admin.email,
            size: 44,
            circle: true,
            statusDot: admin.isActive
                ? const Color(0xFF10B981)
                : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 16),
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
                      name,
                      style: jakarta(
                        textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Text(
                      prettyUserType(admin.userType),
                      style: textTheme.labelMedium?.copyWith(
                        color: colors.textSubtle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 18,
                  runSpacing: 6,
                  children: [
                    meta(Icons.mail_outline_rounded, admin.email),
                    if (admin.firmName.isNotEmpty)
                      meta(Icons.apartment_rounded, admin.firmName),
                    meta(
                      Icons.calendar_today_outlined,
                      'Joined ${formatDate(admin.dateJoined)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          StatusPill(
            label: admin.isActive ? 'ACTIVE' : 'INACTIVE',
            tone: admin.isActive ? PillTone.success : PillTone.neutral,
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            color: onTap == null ? Colors.transparent : colors.textSubtle,
          ),
        ],
      ),
    );
  }
}
