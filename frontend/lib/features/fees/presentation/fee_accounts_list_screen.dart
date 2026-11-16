import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/status_pill.dart';
import '../data/fee_models.dart';
import '../data/fee_repository.dart';
import 'fee_dialogs.dart';

PillTone feeStatusTone(String status) => switch (status.toUpperCase()) {
  FeeAccountStatus.paid => PillTone.success,
  FeeAccountStatus.partiallyPaid => PillTone.warning,
  FeeAccountStatus.unpaid => PillTone.danger,
  _ => PillTone.neutral,
};

class FeeAccountsListScreen extends ConsumerStatefulWidget {
  const FeeAccountsListScreen({super.key});

  @override
  ConsumerState<FeeAccountsListScreen> createState() =>
      _FeeAccountsListScreenState();
}

class _FeeAccountsListScreenState extends ConsumerState<FeeAccountsListScreen> {
  final searchController = TextEditingController();
  late Future<Paged<FeeAccount>> result;

  int page = 1;
  String? statusFilter;
  String search = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    result = ref.read(feeRepositoryProvider).feeAccounts(
      page: page,
      status: statusFilter,
    );
  }

  void refresh() => setState(_reload);

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _setStatus(String? value) {
    setState(() {
      statusFilter = value;
      page = 1;
      _reload();
    });
  }

  void _changePage(int value) {
    setState(() {
      page = value;
      _reload();
    });
  }

  Future<void> _create() async {
    final created = await showDialog<FeeAccount>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CreateFeeAccountDialog(),
    );
    if (created == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Fee account created for ${created.studentName}')),
    );
    await context.push('/fees/${created.enrollmentUuid}');
    if (mounted) refresh();
  }

  bool _matchesSearch(FeeAccount account, String query) {
    if (query.isEmpty) return true;
    return account.studentName.toLowerCase().contains(query) ||
        account.admissionNumber.toLowerCase().contains(query) ||
        account.courseName.toLowerCase().contains(query) ||
        account.courseCode.toLowerCase().contains(query) ||
        account.enrollmentUuid.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Eyebrow + "Fees" + refresh + "+ Create fee account"
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'FINANCE',
                      style: textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF4F46E5),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '•',
                        style: TextStyle(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Course fees & installments',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Fees',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: refresh,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                      tooltip: 'Refresh',
                      visualDensity: VisualDensity.compact,
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _create,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Create fee account'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF3730A3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
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
              ],
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: FutureBuilder<Paged<FeeAccount>>(
              future: result,
              builder: (context, snapshot) {
                final state = adminFutureState(
                  snapshot,
                  noun: 'fee accounts',
                  onRetry: refresh,
                );
                final data = snapshot.data;
                final rows = data?.results ?? const <FeeAccount>[];

                final outstanding =
                rows.fold<double>(0, (sum, a) => sum + a.balanceAmount);
                final collected =
                rows.fold<double>(0, (sum, a) => sum + a.paidAmount);
                final overdue = rows.where((a) => a.isOverdue).length;

                final query = search.trim().toLowerCase();
                final visibleRows =
                rows.where((a) => _matchesSearch(a, query)).toList();

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

                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: _FeeStatCard(
                                label: 'Fee accounts',
                                value: data == null ? '…' : '${data.count}',
                                caption: 'Total registered',
                                icon: Icons.credit_card_outlined,
                                iconColor: const Color(0xFF7C3AED),
                                iconBg: const Color(0xFFF5F3FF),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _FeeStatCard(
                                label: 'Collected',
                                value: data == null ? '…' : formatInr(collected),
                                valueColor: const Color(0xFF059669),
                                caption: 'On this page',
                                icon: Icons.payments_outlined,
                                iconColor: const Color(0xFF059669),
                                iconBg: const Color(0xFFECFDF5),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _FeeStatCard(
                                label: 'Outstanding',
                                value:
                                data == null ? '…' : formatInr(outstanding),
                                caption: 'On this page',
                                icon: Icons.description_outlined,
                                iconColor: const Color(0xFFD97706),
                                iconBg: const Color(0xFFFFFBEB),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _FeeStatCard(
                                label: 'Overdue',
                                value: data == null ? '…' : '$overdue',
                                caption: 'On this page',
                                icon: Icons.calendar_today_outlined,
                                iconColor: const Color(0xFFE11D48),
                                iconBg: const Color(0xFFFFF1F2),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Filter chips ("All", "Unpaid", "Partially paid", "Paid")
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final entry in const [
                            ['All', null],
                            ['Unpaid', FeeAccountStatus.unpaid],
                            ['Partially paid', FeeAccountStatus.partiallyPaid],
                            ['Paid', FeeAccountStatus.paid],
                          ]) ...[
                            if (entry[0] != 'All') const SizedBox(width: 8),
                            _FeeFilterPill(
                              label: entry[0]!,
                              selected: statusFilter == entry[1],
                              onTap: () => _setStatus(entry[1]),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Search bar matching screenshot
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
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
                              controller: searchController,
                              onChanged: (value) =>
                                  setState(() => search = value),
                              decoration: const InputDecoration(
                                hintText:
                                'Search fee account, student name, receipt...',
                                hintStyle: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 13.5,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding:
                                EdgeInsets.symmetric(vertical: 11),
                              ),
                            ),
                          ),
                          if (search.isNotEmpty)
                            IconButton(
                              onPressed: () {
                                searchController.clear();
                                setState(() => search = '');
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Color(0xFF94A3B8),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    if (state != null)
                      state
                    else if (rows.isEmpty)
                      _EmptyFeeAccountsCard(
                        isFiltered: statusFilter != null,
                        filterLabel: statusFilter == null
                            ? ''
                            : FeeAccountStatus.label(statusFilter!).toLowerCase(),
                        onPrimaryAction: statusFilter == null
                            ? _create
                            : () => _setStatus(null),
                      )
                    else if (visibleRows.isEmpty)
                        AdminStateMessage(
                          icon: Icons.search_off_rounded,
                          title: 'No matching fee accounts',
                          message: 'Try a different student name, admission ID, or course.',
                          actionLabel: 'Clear search',
                          onAction: () {
                            searchController.clear();
                            setState(() => search = '');
                          },
                        )
                      else ...[
                          for (final account in visibleRows) ...[
                            _FeeAccountCard(
                              account: account,
                              onTap: () async {
                                await context.push('/fees/${account.enrollmentUuid}');
                                if (mounted) refresh();
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          AdminPager(
                            page: page,
                            pageSize: FeeRepository.pageSize,
                            total: data!.count,
                            noun: 'fee accounts',
                            onPage: _changePage,
                          ),
                        ],
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

class _FeeStatCard extends StatelessWidget {
  const _FeeStatCard({
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: jakarta(
              textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: valueColor,
                fontSize: 24,
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

class _FeeFilterPill extends StatelessWidget {
  const _FeeFilterPill({
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
              selected ? const Color(0xFF3730A3) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? Colors.white : const Color(0xFF334155),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFeeAccountsCard extends StatelessWidget {
  const _EmptyFeeAccountsCard({
    required this.isFiltered,
    required this.filterLabel,
    required this.onPrimaryAction,
  });

  final bool isFiltered;
  final String filterLabel;
  final VoidCallback onPrimaryAction;

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
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.payments_outlined,
              size: 26,
              color: Color(0xFF3730A3),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isFiltered ? 'No $filterLabel fee accounts' : 'No fee accounts yet',
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
              isFiltered
                  ? 'Choose another filter to see other fee accounts.'
                  : 'Create a fee account for an enrollment to start recording payments, installment plans, and generate GST receipts.',
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
              onPressed: onPrimaryAction,
              icon: Icon(
                isFiltered ? Icons.filter_list_off_rounded : Icons.add_rounded,
                size: 18,
              ),
              label: Text(isFiltered ? 'Show all' : 'Create fee account'),
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
        ],
      ),
    );
  }
}

class _FeeAccountCard extends StatelessWidget {
  const _FeeAccountCard({required this.account, required this.onTap});

  final FeeAccount account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final course = account.courseCode.isEmpty
        ? account.courseName
        : '${account.courseName} (${account.courseCode})';
    final initials = adminInitials(account.studentName);

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
                    width: 44,
                    height: 44,
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
                              account.studentName,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            if (account.admissionNumber.isNotEmpty)
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
                                  account.admissionNumber,
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
                          course,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (account.isOverdue)
                    const StatusPill(
                      label: 'OVERDUE',
                      tone: PillTone.danger,
                      compact: true,
                    )
                  else
                    StatusPill(
                      label: FeeAccountStatus.label(account.status).toUpperCase(),
                      tone: feeStatusTone(account.status),
                      compact: true,
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
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.payments_outlined,
                          size: 14,
                          color: Color(0xFF059669),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Paid ${formatInr(account.paidAmount)} of ${formatInr(account.netPayable)}',
                          style: textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF1E293B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (!account.isPaid)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 14,
                            color: Color(0xFFD97706),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Balance ${formatInr(account.balanceAmount)}',
                            style: textTheme.labelMedium?.copyWith(
                              color: const Color(0xFF475569),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    if (account.dueDate != null && !account.isPaid)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            account.isOverdue
                                ? Icons.event_busy_outlined
                                : Icons.event_outlined,
                            size: 14,
                            color: account.isOverdue
                                ? const Color(0xFFE11D48)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            account.isOverdue
                                ? 'Overdue since ${formatDate(account.dueDate!)}'
                                : 'Due ${formatDate(account.dueDate!)}',
                            style: textTheme.labelMedium?.copyWith(
                              color: account.isOverdue
                                  ? const Color(0xFFE11D48)
                                  : const Color(0xFF475569),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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