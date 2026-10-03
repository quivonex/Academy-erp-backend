import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/status_pill.dart';
import '../data/fee_models.dart';
import '../data/fee_repository.dart';
import 'fee_accounts_list_screen.dart' show feeStatusTone;
import 'fee_dialogs.dart';

/// Route: /fees/:enrollmentUuid
///
/// Keyed by enrollment because the backend has no fee-account detail
/// endpoint and each enrollment has at most one fee account. This also lets
/// the enrollment detail screen link straight here.
class FeeAccountDetailScreen extends ConsumerStatefulWidget {
  const FeeAccountDetailScreen({super.key, required this.enrollmentUuid});

  final String enrollmentUuid;

  @override
  ConsumerState<FeeAccountDetailScreen> createState() =>
      _FeeAccountDetailScreenState();
}

class _FeeAccountDetailScreenState
    extends ConsumerState<FeeAccountDetailScreen> {
  late Future<FeeAccount?> accountFuture;
  Future<Paged<Installment>>? installmentsFuture;

  /// Latest known copy; record/void responses replace it without a refetch.
  FeeAccount? account;
  int installmentsPage = 1;

  FeeRepository get _repo => ref.read(feeRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  void _loadAccount() {
    accountFuture =
        _repo.feeAccountForEnrollment(widget.enrollmentUuid).then((value) {
      account = value;
      if (value != null) _loadInstallments(value.uuid);
      return value;
    });
  }

  void _loadInstallments(String feeAccountUuid) {
    installmentsFuture = _repo.installments(
      feeAccountUuid: feeAccountUuid,
      page: installmentsPage,
    );
  }

  void refresh() => setState(() {
        installmentsPage = 1;
        _loadAccount();
      });

  void _changeInstallmentsPage(int value) {
    final current = account;
    if (current == null) return;
    setState(() {
      installmentsPage = value;
      _loadInstallments(current.uuid);
    });
  }

  void _applyChange(InstallmentChange change, String message) {
    setState(() {
      account = change.feeAccount;
      accountFuture = Future.value(change.feeAccount);
      installmentsPage = 1;
      _loadInstallments(change.feeAccount.uuid);
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createAccount() async {
    final created = await showDialog<FeeAccount>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          CreateFeeAccountDialog(enrollmentUuid: widget.enrollmentUuid),
    );
    if (created != null && mounted) refresh();
  }

  Future<void> _recordPayment(FeeAccount current) async {
    final change = await showDialog<InstallmentChange>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RecordInstallmentDialog(account: current),
    );
    if (change != null && mounted) {
      _applyChange(
        change,
        'Payment of ${formatInr(change.installment.amount)} recorded',
      );
    }
  }

  Future<void> _voidPayment(Installment installment) async {
    final change = await showDialog<InstallmentChange>(
      context: context,
      barrierDismissible: false,
      builder: (_) => VoidInstallmentDialog(installment: installment),
    );
    if (change != null && mounted) {
      _applyChange(
        change,
        'Payment of ${formatInr(change.installment.amount)} voided',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FeeAccount?>(
      future: accountFuture,
      builder: (context, snapshot) {
        final state = adminFutureState(
          snapshot,
          noun: 'fee account',
          onRetry: refresh,
        );

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/fees'),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Fees'),
              ),
            ),
            const SizedBox(height: 8),
            if (state != null)
              state
            else if (account == null)
              AdminStateMessage(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No fee account for this enrollment',
                message:
                    'Create one to set the course fee and start recording payments.',
                actionLabel: 'Create fee account',
                onAction: _createAccount,
              )
            else ...[
              _Header(
                account: account!,
                onRecord: () => _recordPayment(account!),
                onRefresh: refresh,
              ),
              const SizedBox(height: 20),
              _SummaryCard(account: account!),
              const SizedBox(height: 28),
              _InstallmentsSection(
                future: installmentsFuture,
                page: installmentsPage,
                onPage: _changeInstallmentsPage,
                onVoid: _voidPayment,
                onRecord:
                    account!.isPaid ? null : () => _recordPayment(account!),
                onRetry: () => setState(() => _loadInstallments(account!.uuid)),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ─────────────────────────── header ───────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.account,
    required this.onRecord,
    required this.onRefresh,
  });

  final FeeAccount account;
  final VoidCallback onRecord;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final course = account.courseCode.isEmpty
        ? account.courseName
        : '${account.courseName} (${account.courseCode})';

    return AdminPageHeader(
      eyebrow: AdminEyebrow(
        section: 'Fee account',
        detail: account.admissionNumber.isEmpty ? null : account.admissionNumber,
      ),
      title: account.studentName,
      subtitle: course,
      titleTrailing: [
        account.isOverdue
            ? const StatusPill(label: 'OVERDUE', tone: PillTone.danger)
            : StatusPill(
                label: FeeAccountStatus.label(account.status).toUpperCase(),
                tone: feeStatusTone(account.status),
              ),
        IconButton(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh',
        ),
      ],
      actions: [
        if (account.studentUuid.isNotEmpty)
          AdminOutlineButton(
            label: 'Student profile',
            icon: Icons.person_outline_rounded,
            onPressed: () => context.push('/students/${account.studentUuid}'),
          ),
        GradientButton(
          label: account.isPaid ? 'Fully paid' : 'Record payment',
          icon: account.isPaid ? Icons.verified_rounded : Icons.add_rounded,
          onPressed: account.isPaid ? null : onRecord,
        ),
      ],
    );
  }
}

// ─────────────────────────── summary ───────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.account});

  final FeeAccount account;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final percent = (account.paidFraction * 100).round();

    final barColor = account.isPaid
        ? const Color(0xFF059669)
        : account.isOverdue
            ? const Color(0xFFE11D48)
            : colors.primary;

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The one number that matters most: what is still owed.
          Text(
            account.isPaid ? 'Fully paid' : 'Balance due',
            style: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            formatInr(account.isPaid ? account.paidAmount : account.balanceAmount),
            style: jakarta(
              textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: account.isOverdue ? const Color(0xFFE11D48) : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: account.paidFraction,
              minHeight: 10,
              backgroundColor: const Color(0xFFEEF0F5),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$percent% paid — ${formatInr(account.paidAmount)} '
            'of ${formatInr(account.netPayable)}',
            style: textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 22),
          const Divider(height: 1),
          const SizedBox(height: 18),
          Wrap(
            spacing: 32,
            runSpacing: 16,
            children: [
              _Figure(label: 'Total fee', value: formatInr(account.totalAmount)),
              _Figure(
                label: 'Discount',
                value: account.discountAmount > 0
                    ? '− ${formatInr(account.discountAmount)}'
                    : formatInr(0),
              ),
              _Figure(label: 'Net payable', value: formatInr(account.netPayable)),
              _Figure(label: 'Paid', value: formatInr(account.paidAmount)),
              _Figure(
                label: 'Due date',
                value: account.dueDate == null
                    ? 'Not set'
                    : formatDate(account.dueDate!),
                danger: account.isOverdue,
              ),
            ],
          ),
          if (account.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Notes',
              style: textTheme.labelLarge?.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: 4),
            Text(account.notes, style: textTheme.bodyMedium),
          ],
          if (account.createdByName != null || account.createdAt != null) ...[
            const SizedBox(height: 18),
            Text(
              [
                'Created',
                if (account.createdAt != null)
                  'on ${formatDate(account.createdAt!.toLocal())}',
                if ((account.createdByName ?? '').isNotEmpty)
                  'by ${account.createdByName}',
              ].join(' '),
              style: textTheme.bodySmall?.copyWith(color: colors.textSubtle),
            ),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.danger = false});

  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: danger ? const Color(0xFFE11D48) : colors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── installments ───────────────────────────

class _InstallmentsSection extends StatelessWidget {
  const _InstallmentsSection({
    required this.future,
    required this.page,
    required this.onPage,
    required this.onVoid,
    required this.onRecord,
    required this.onRetry,
  });

  final Future<Paged<Installment>>? future;
  final int page;
  final ValueChanged<int> onPage;
  final ValueChanged<Installment> onVoid;
  final VoidCallback? onRecord;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Payment history',
          style: jakarta(
            textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<Paged<Installment>>(
          future: future,
          builder: (context, snapshot) {
            final state = adminFutureState(
              snapshot,
              noun: 'payments',
              onRetry: onRetry,
            );
            if (state != null) return state;

            final data = snapshot.data;
            final rows = data?.results ?? const <Installment>[];

            if (rows.isEmpty) {
              return AdminStateMessage(
                icon: Icons.receipt_long_outlined,
                title: 'No payments recorded yet',
                message: 'Record the first installment when the student pays.',
                actionLabel: onRecord == null ? null : 'Record payment',
                onAction: onRecord,
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final installment in rows)
                  _InstallmentRow(
                    installment: installment,
                    onVoid: () => onVoid(installment),
                  ),
                AdminPager(
                  page: page,
                  pageSize: FeeRepository.pageSize,
                  total: data!.count,
                  noun: 'payments',
                  onPage: onPage,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  const _InstallmentRow({required this.installment, required this.onVoid});

  final Installment installment;
  final VoidCallback onVoid;

  @override
  Widget build(BuildContext context) {
    final i = installment;
    final method = PaymentMethod.label(i.paymentMethod);

    return AdminListRow(
      title: formatInr(i.amount),
      icon: i.isVoided ? Icons.block_rounded : Icons.payments_outlined,
      subtitle: i.transactionReference.isEmpty
          ? method
          : '$method • Ref ${i.transactionReference}',
      meta: [
        if (i.paymentDate != null)
          MetaChip(
            icon: Icons.event_outlined,
            label: 'Paid ${formatDate(i.paymentDate!)}',
          ),
        if ((i.recordedByName ?? '').isNotEmpty)
          MetaChip(
            icon: Icons.person_outline_rounded,
            label: 'Recorded by ${i.recordedByName}',
          ),
        if (i.isVoided)
          MetaChip(
            icon: Icons.info_outline_rounded,
            label: [
              'Voided',
              if ((i.voidedByName ?? '').isNotEmpty) 'by ${i.voidedByName}',
              if ((i.voidReason ?? '').isNotEmpty) '— ${i.voidReason}',
            ].join(' '),
          ),
        if (i.notes.isNotEmpty)
          MetaChip(icon: Icons.notes_rounded, label: i.notes),
      ],
      trailing: [
        StatusPill(
          label: i.isVoided ? 'VOIDED' : 'RECORDED',
          tone: i.isVoided ? PillTone.neutral : PillTone.success,
          compact: true,
        ),
        if (!i.isVoided)
          IconButton(
            tooltip: 'Void payment',
            onPressed: onVoid,
            icon: const Icon(Icons.block_rounded, size: 20),
          ),
      ],
    );
  }
}
