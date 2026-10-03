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
  late Future<Paged<FeeAccount>> result;

  int page = 1;
  String? statusFilter;

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          eyebrow: const AdminEyebrow(
            section: 'Finance',
            detail: 'Course fees & installments',
          ),
          title: 'Fees',
          titleTrailing: [
            IconButton(
              onPressed: refresh,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
            ),
          ],
          actions: [
            GradientButton(
              label: 'Create fee account',
              icon: Icons.add_rounded,
              onPressed: _create,
            ),
          ],
        ),
        const SizedBox(height: 20),
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

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  AdminKpiGrid(
                    children: [
                      AdminKpiCard(
                        label: 'Fee accounts',
                        value: data == null ? '…' : '${data.count}',
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      AdminKpiCard(
                        label: 'Collected',
                        value: data == null ? '…' : formatInr(collected),
                        icon: Icons.savings_outlined,
                        iconBackground: const Color(0xFFECFDF5),
                        iconForeground: const Color(0xFF059669),
                        caption: 'On this page',
                      ),
                      AdminKpiCard(
                        label: 'Outstanding',
                        value: data == null ? '…' : formatInr(outstanding),
                        icon: Icons.pending_actions_outlined,
                        iconBackground: const Color(0xFFFFFBEB),
                        iconForeground: const Color(0xFFD97706),
                        caption: 'On this page',
                      ),
                      AdminKpiCard(
                        label: 'Overdue',
                        value: data == null ? '…' : '$overdue',
                        icon: Icons.event_busy_outlined,
                        iconBackground: const Color(0xFFFFF1F2),
                        iconForeground: const Color(0xFFE11D48),
                        caption: 'On this page',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in const [
                        ['All', null],
                        ['Unpaid', FeeAccountStatus.unpaid],
                        ['Partially paid', FeeAccountStatus.partiallyPaid],
                        ['Paid', FeeAccountStatus.paid],
                      ])
                        CountFilterPill(
                          label: entry[0]!,
                          selected: statusFilter == entry[1],
                          onTap: () => _setStatus(entry[1]),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (state != null)
                    state
                  else if (rows.isEmpty)
                    AdminStateMessage(
                      icon: Icons.account_balance_wallet_outlined,
                      title: statusFilter == null
                          ? 'No fee accounts yet'
                          : 'No ${FeeAccountStatus.label(statusFilter!).toLowerCase()} fee accounts',
                      message: statusFilter == null
                          ? 'Create a fee account for an enrollment to start recording payments.'
                          : 'Choose another filter to see other fee accounts.',
                      actionLabel:
                          statusFilter == null ? 'Create fee account' : 'Show all',
                      onAction: statusFilter == null
                          ? _create
                          : () => _setStatus(null),
                    )
                  else ...[
                    for (final account in rows) _FeeAccountRow(
                      account: account,
                      onTap: () async {
                        await context.push('/fees/${account.enrollmentUuid}');
                        if (mounted) refresh();
                      },
                    ),
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
    );
  }
}

class _FeeAccountRow extends StatelessWidget {
  const _FeeAccountRow({required this.account, required this.onTap});

  final FeeAccount account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final course = account.courseCode.isEmpty
        ? account.courseName
        : '${account.courseName} (${account.courseCode})';

    return AdminListRow(
      title: account.studentName,
      initials: adminInitials(account.studentName),
      seed: account.admissionNumber,
      titleBadge: account.admissionNumber.isEmpty
          ? null
          : SoftBadge(
              label: account.admissionNumber,
              monospace: true,
              background: const Color(0xFFF1F5F9),
              foreground: const Color(0xFF334155),
            ),
      subtitle: course,
      meta: [
        MetaChip(
          icon: Icons.payments_outlined,
          label: 'Paid ${formatInr(account.paidAmount)} '
              'of ${formatInr(account.netPayable)}',
        ),
        if (!account.isPaid)
          MetaChip(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Balance ${formatInr(account.balanceAmount)}',
          ),
        if (account.dueDate != null && !account.isPaid)
          MetaChip(
            icon: account.isOverdue
                ? Icons.event_busy_outlined
                : Icons.event_outlined,
            label: account.isOverdue
                ? 'Overdue since ${formatDate(account.dueDate!)}'
                : 'Due ${formatDate(account.dueDate!)}',
          ),
      ],
      trailing: [
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
      onTap: onTap,
    );
  }
}
