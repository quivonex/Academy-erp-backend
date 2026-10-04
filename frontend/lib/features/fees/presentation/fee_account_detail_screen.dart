import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../enrollments/data/enrollment.dart';
import '../../enrollments/data/enrollment_repository.dart';
import '../data/fee_models.dart';
import '../data/fee_repository.dart';

class FeeAccountDetailScreen extends ConsumerStatefulWidget {
  const FeeAccountDetailScreen({
    super.key,
    required this.enrollmentUuid,
  });

  final String enrollmentUuid;

  @override
  ConsumerState<FeeAccountDetailScreen> createState() =>
      _FeeAccountDetailScreenState();
}

class _FeeAccountDetailScreenState
    extends ConsumerState<FeeAccountDetailScreen> {
  late Future<FeeAccount?> accountFuture;
  Future<Paged<Installment>>? paymentsFuture;

  FeeAccount? account;
  int page = 1;
  int revision = 0;
  bool busy = false;
  bool changed = false;
  String? error;

  FeeRepository get repo => ref.read(feeRepositoryProvider);

  bool current(int ticket) => mounted && ticket == revision;

  @override
  void initState() {
    super.initState();
    loadAccount();
  }

  @override
  void didUpdateWidget(
      covariant FeeAccountDetailScreen oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.enrollmentUuid != widget.enrollmentUuid) {
      revision++;
      busy = changed = false;
      error = null;
      page = 1;
      account = null;
      paymentsFuture = null;
      loadAccount();
    }
  }

  void loadAccount() {
    final ticket = revision;

    accountFuture = repo
        .feeAccountForEnrollment(widget.enrollmentUuid)
        .then((value) {
      if (current(ticket)) {
        account = value;
        paymentsFuture = value == null
            ? null
            : repo.installments(
          feeAccountUuid: value.uuid,
          page: page,
        );
      }

      return value;
    });
  }

  void refresh() {
    if (busy) return;

    setState(() {
      revision++;
      page = 1;
      error = null;
      account = null;
      paymentsFuture = null;
      loadAccount();
    });
  }

  void loadPayments(int next) {
    if (busy || account == null || next < 1) return;

    setState(() {
      page = next;
      paymentsFuture = repo.installments(
        feeAccountUuid: account!.uuid,
        page: page,
      );
    });
  }

  void applyAccount(
      FeeAccount value, {
        bool resetPayments = false,
      }) {
    account = value;
    accountFuture = Future.value(value);

    if (resetPayments) {
      page = 1;
      paymentsFuture = repo.installments(
        feeAccountUuid: value.uuid,
        page: page,
      );
    }
  }

  Future<void> openAction(
      _FeeAction action, [
        Installment? installment,
      ]) async {
    if (busy) return;

    if (action == _FeeAction.voidPayment &&
        (installment == null ||
            installment.status.toUpperCase() !=
                InstallmentStatus.recorded)) {
      return;
    }

    final ticket = revision;
    final enrollmentUuid = widget.enrollmentUuid;

    setState(() {
      busy = true;
      error = null;
    });

    try {
      final latest =
      await repo.feeAccountForEnrollment(enrollmentUuid);

      if (!current(ticket)) return;

      if (latest != null) {
        setState(() => applyAccount(latest));
      }

      if (action == _FeeAction.create && latest != null) {
        setState(() {
          applyAccount(latest, resetPayments: true);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This enrollment already has a fee account.',
            ),
          ),
        );
        return;
      }

      if (action != _FeeAction.create && latest == null) {
        setState(() {
          account = null;
          accountFuture = Future.value(null);
          paymentsFuture = null;
        });
        return;
      }

      if (action == _FeeAction.record &&
          (latest!.isPaid || latest.balanceAmount <= 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This fee account is fully paid.'),
          ),
        );
        return;
      }

      final result = await showDialog<_FeeResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _FeeActionDialog(
          action: action,
          enrollmentUuid: enrollmentUuid,
          account: latest,
          installment: installment,
        ),
      );

      if (!current(ticket) || result == null) return;

      setState(() {
        applyAccount(result.account, resetPayments: true);
        changed = true;
      });

      final message = switch (action) {
        _FeeAction.create => 'Fee account created.',
        _FeeAction.record => 'Payment recorded successfully.',
        _FeeAction.voidPayment =>
        'Payment voided. Balance updated.',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on ApiException catch (e) {
      if (current(ticket)) {
        setState(() => error = e.message);
      }
    } catch (_) {
      if (current(ticket)) {
        setState(() {
          error = 'Could not open the fee action. Please retry.';
        });
      }
    } finally {
      if (current(ticket)) {
        setState(() => busy = false);
      }
    }
  }

  void back() {
    if (busy) return;

    if (context.canPop()) {
      context.pop(changed);
    } else {
      context.go('/fees');
    }
  }

  Widget summary(FeeAccount a) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Balance due',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            formatInr(a.balanceAmount),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: a.paidFraction,
            minHeight: 8,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              Text('Total: ${formatInr(a.totalAmount)}'),
              Text('Discount: ${formatInr(a.discountAmount)}'),
              Text('Net payable: ${formatInr(a.netPayable)}'),
              Text('Paid: ${formatInr(a.paidAmount)}'),
              Text(
                'Due: ${a.dueDate == null ? 'Not set' : formatDate(a.dueDate!)}',
              ),
            ],
          ),
          if (a.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Notes: ${a.notes}'),
          ],
          if ((a.createdByName ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Created by: ${a.createdByName}'),
          ],
          if (a.createdAt != null)
            Text(
              'Created on: ${formatDate(a.createdAt!.toLocal())}',
            ),
        ],
      ),
    );
  }

  Widget paymentRow(Installment i) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                formatInr(i.amount),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SoftBadge(label: i.status),
              if (i.status.toUpperCase() ==
                  InstallmentStatus.recorded)
                AdminOutlineButton(
                  label: 'Void',
                  icon: Icons.block,
                  danger: true,
                  onPressed: busy
                      ? null
                      : () => openAction(
                    _FeeAction.voidPayment,
                    i,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Method: ${PaymentMethod.label(i.paymentMethod)}',
          ),
          if (i.paymentDate != null)
            Text(
              'Payment date: ${formatDate(i.paymentDate!)}',
            ),
          if (i.transactionReference.isNotEmpty)
            Text('Reference: ${i.transactionReference}'),
          if ((i.recordedByName ?? '').isNotEmpty)
            Text('Recorded by: ${i.recordedByName}'),
          if (i.notes.isNotEmpty) Text('Notes: ${i.notes}'),
          if (i.isVoided) ...[
            Text('Void reason: ${i.voidReason ?? '—'}'),
            if ((i.voidedByName ?? '').isNotEmpty)
              Text('Voided by: ${i.voidedByName}'),
            if (i.voidedAt != null)
              Text(
                'Voided on: ${formatDate(i.voidedAt!.toLocal())}',
              ),
          ],
        ],
      ),
    );
  }

  Widget paymentHistory() {
    return FutureBuilder<Paged<Installment>>(
      future: paymentsFuture,
      builder: (context, snapshot) {
        final state = adminFutureState(
          snapshot,
          noun: 'payments',
          onRetry: () => loadPayments(page),
        );

        if (state != null) return state;

        final data = snapshot.data;

        if (data == null) {
          return const Text('Payment history unavailable.');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.results.isEmpty)
              AdminStateMessage(
                icon: Icons.receipt_long_outlined,
                title: data.count == 0
                    ? 'No payments recorded'
                    : 'No payments on this page',
                message: data.count == 0
                    ? 'Record a payment when the student pays.'
                    : 'Go to a previous page or refresh.',
              ),
            for (final installment in data.results) ...[
              paymentRow(installment),
              const SizedBox(height: 12),
            ],
            IgnorePointer(
              ignoring: busy,
              child: AdminPager(
                page: page,
                pageSize: FeeRepository.pageSize,
                total: data.count,
                noun: 'payments',
                onPage: loadPayments,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !busy,
      child: FutureBuilder<FeeAccount?>(
        future: accountFuture,
        builder: (context, snapshot) {
          final state = adminFutureState(
            snapshot,
            noun: 'fee account',
            onRetry: refresh,
          );

          final a = snapshot.data;

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: busy ? null : back,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Fees'),
                ),
              ),
              if (busy) const LinearProgressIndicator(),
              if (error != null) ...[
                const SizedBox(height: 12),
                AdminErrorBanner(message: error!),
              ],
              const SizedBox(height: 16),
              if (state != null)
                state
              else if (a == null)
                AdminStateMessage(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'No fee account for this enrollment',
                  message:
                  'Set the course fee before recording payments.',
                  actionLabel:
                  busy ? null : 'Create fee account',
                  onAction: busy
                      ? null
                      : () => openAction(_FeeAction.create),
                )
              else ...[
                  AdminPageHeader(
                    title: a.studentName,
                    eyebrow: AdminEyebrow(
                      section: 'Fee account',
                      detail: a.admissionNumber.isEmpty
                          ? null
                          : a.admissionNumber,
                    ),
                    subtitle: a.courseCode.isEmpty
                        ? a.courseName
                        : '${a.courseName} (${a.courseCode})',
                    titleTrailing: [
                      SoftBadge(
                        label: FeeAccountStatus.label(a.status),
                      ),
                      if (a.isOverdue)
                        const SoftBadge(label: 'Overdue'),
                    ],
                    actions: [
                      AdminOutlineButton(
                        label: 'Refresh',
                        icon: Icons.refresh,
                        onPressed: busy ? null : refresh,
                      ),
                      if (a.studentUuid.isNotEmpty)
                        AdminOutlineButton(
                          label: 'Student profile',
                          icon: Icons.person_outline,
                          onPressed: busy
                              ? null
                              : () => context.push(
                            '/students/${a.studentUuid}',
                          ),
                        ),
                      GradientButton(
                        label: a.isPaid
                            ? 'Fully paid'
                            : 'Record payment',
                        icon: Icons.payments_outlined,
                        onPressed:
                        busy || a.isPaid || a.balanceAmount <= 0
                            ? null
                            : () => openAction(
                          _FeeAction.record,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  summary(a),
                  const SizedBox(height: 24),
                  Text(
                    'Payment history',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  paymentHistory(),
                ],
            ],
          );
        },
      ),
    );
  }
}

enum _FeeAction { create, record, voidPayment }

class _FeeResult {
  const _FeeResult(this.account);
  final FeeAccount account;
}

// Store user-entered money as integer paise for validation.
int? _paise(
    String? value, {
      bool blankIsZero = false,
    }) {
  final text = value?.trim() ?? '';

  if (text.isEmpty && blankIsZero) return 0;

  if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(text)) {
    return null;
  }

  final parts = text.split('.');

  return int.parse(parts.first) * 100 +
      (parts.length == 1
          ? 0
          : int.parse(parts[1].padRight(2, '0')));
}

String? _positiveAmount(String? value) {
  final paise = _paise(value);

  if (paise == null) {
    return 'Enter up to 8 whole digits and 2 decimal places.';
  }

  return paise > 0
      ? null
      : 'Amount must be greater than zero.';
}

class _FeeActionDialog extends ConsumerStatefulWidget {
  const _FeeActionDialog({
    required this.action,
    required this.enrollmentUuid,
    this.account,
    this.installment,
  });

  final _FeeAction action;
  final String enrollmentUuid;
  final FeeAccount? account;
  final Installment? installment;

  @override
  ConsumerState<_FeeActionDialog> createState() =>
      _FeeActionDialogState();
}

class _FeeActionDialogState
    extends ConsumerState<_FeeActionDialog> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController();
  final discount = TextEditingController(text: '0');
  final reference = TextEditingController();
  final notes = TextEditingController();
  final reason = TextEditingController();

  Future<Enrollment>? enrollmentFuture;
  DateTime? date;
  String method = 'CASH';

  bool saving = false;
  bool picking = false;
  String? error;
  _FeeResult? savedResult;

  bool get create => widget.action == _FeeAction.create;
  bool get record => widget.action == _FeeAction.record;
  bool get locked => saving || picking;
  bool get editable => !locked && savedResult == null;

  @override
  void initState() {
    super.initState();

    if (create) loadEnrollment();

    if (record) {
      final now = DateTime.now();
      date = DateTime(now.year, now.month, now.day);
    }
  }

  void loadEnrollment() {
    enrollmentFuture = ref
        .read(enrollmentManagementRepositoryProvider)
        .detail(widget.enrollmentUuid);
  }

  @override
  void dispose() {
    for (final c in [
      amount,
      discount,
      reference,
      notes,
      reason,
    ]) {
      c.dispose();
    }

    super.dispose();
  }

  void close() {
    if (!locked) {
      Navigator.of(context).pop(savedResult);
    }
  }

  Future<void> pickDate() async {
    if (!editable) return;

    setState(() => picking = true);

    try {
      final initial = date ?? DateTime.now();
      final day = DateTime(
        initial.year,
        initial.month,
        initial.day,
      );

      final picked = await showDatePicker(
        context: context,
        initialDate: day,
        firstDate: day.isBefore(DateTime(2000))
            ? day
            : DateTime(2000),
        lastDate: day.isAfter(DateTime(2100, 12, 31))
            ? day
            : DateTime(2100, 12, 31),
      );

      if (mounted && picked != null) {
        setState(() => date = picked);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Could not open the date picker. Please retry.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => picking = false);
      }
    }
  }

  Future<void> save() async {
    if (!editable ||
        form.currentState?.validate() != true) {
      return;
    }

    if (record &&
        (widget.account!.isPaid ||
            widget.account!.balanceAmount <= 0)) {
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      final repo = ref.read(feeRepositoryProvider);
      FeeAccount updated;

      if (create) {
        updated = await repo.createFeeAccount(
          enrollmentUuid: widget.enrollmentUuid,
          totalAmount: _paise(amount.text)! / 100,
          discountAmount:
          _paise(discount.text, blankIsZero: true)! / 100,
          dueDate: date,
          notes: notes.text.trim(),
        );
      } else if (record) {
        final result = await repo.recordInstallment(
          feeAccountUuid: widget.account!.uuid,
          amount: _paise(amount.text)! / 100,
          paymentMethod: method,
          transactionReference: reference.text.trim(),
          paymentDate: date,
          notes: notes.text.trim(),
        );

        updated = result.feeAccount;
      } else {
        final result = await repo.voidInstallment(
          installmentUuid: widget.installment!.uuid,
          reason: reason.text.trim(),
        );

        updated = result.feeAccount;
      }

      if (!mounted) return;

      setState(() {
        savedResult = _FeeResult(updated);
        saving = false;
      });

      close();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = savedResult != null
              ? 'Saved successfully. Close this dialog '
              'to view the updated account.'
              : 'Could not save. Please check the details '
              'and retry.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Widget dateField() {
    return FieldLabel(
      label: create
          ? 'Due date (optional)'
          : 'Payment date',
      child: InputDecorator(
        decoration: adminFieldDecoration(context),
        child: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              date == null
                  ? 'No due date'
                  : formatDate(date!),
            ),
            IconButton(
              tooltip: 'Choose date',
              onPressed: editable ? pickDate : null,
              icon: const Icon(Icons.event),
            ),
            if (create && date != null)
              IconButton(
                tooltip: 'Clear date',
                onPressed: editable
                    ? () => setState(() => date = null)
                    : null,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ),
    );
  }

  Widget fields() {
    return Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (create || record) ...[
            FieldLabel(
              label: create
                  ? 'Total fee (₹)'
                  : 'Amount received (₹)',
              required: true,
              trailing: record
                  ? TextButton(
                onPressed: editable
                    ? () => amount.text = apiAmount(
                  widget.account!.balanceAmount,
                )
                    : null,
                child: const Text('Full balance'),
              )
                  : null,
              child: TextFormField(
                controller: amount,
                enabled: editable,
                keyboardType:
                const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: adminFieldDecoration(
                  context,
                  hint: '1500.00',
                ),
                validator: (v) {
                  final message = _positiveAmount(v);
                  if (message != null) return message;

                  if (record &&
                      _paise(v)! >
                          (widget.account!.balanceAmount * 100)
                              .round()) {
                    return 'Amount exceeds the pending balance.';
                  }

                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            if (create) ...[
              FieldLabel(
                label: 'Discount (₹)',
                child: TextFormField(
                  controller: discount,
                  enabled: editable,
                  keyboardType:
                  const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: adminFieldDecoration(
                    context,
                    hint: '0.00',
                  ),
                  validator: (v) {
                    final d = _paise(v, blankIsZero: true);
                    final total = _paise(amount.text);

                    if (d == null) {
                      return 'Enter a valid amount with '
                          'at most 2 decimal places.';
                    }

                    if (total != null && d >= total) {
                      return 'Discount must be less '
                          'than the total fee.';
                    }

                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (record) ...[
              FieldLabel(
                label: 'Payment method',
                required: true,
                child: DropdownButtonFormField<String>(
                  value: method,
                  isExpanded: true,
                  decoration: adminFieldDecoration(context),
                  items: [
                    for (final entry
                    in PaymentMethod.values.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: editable
                      ? (v) => setState(
                        () => method = v ?? 'CASH',
                  )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              FieldLabel(
                label: 'Transaction reference (optional)',
                child: TextFormField(
                  controller: reference,
                  enabled: editable,
                  maxLength: 100,
                  decoration: adminFieldDecoration(
                    context,
                    hint: 'UTR / transaction ID / receipt number',
                  ),
                  validator: (v) =>
                  (v?.trim().length ?? 0) > 100
                      ? 'Use at most 100 characters.'
                      : null,
                ),
              ),
              const SizedBox(height: 16),
            ],
            dateField(),
            const SizedBox(height: 16),
            FieldLabel(
              label: 'Notes',
              child: TextFormField(
                controller: notes,
                enabled: editable,
                maxLines: 3,
                decoration: adminFieldDecoration(
                  context,
                  hint: 'Optional notes',
                ),
              ),
            ),
          ] else
            FieldLabel(
              label: 'Void reason',
              required: true,
              child: TextFormField(
                controller: reason,
                enabled: editable,
                maxLines: 3,
                maxLength: 1000,
                decoration: adminFieldDecoration(
                  context,
                  hint: 'Explain why this payment should be voided',
                ),
                validator: (v) {
                  final length = v?.trim().length ?? 0;

                  return length < 3 || length > 1000
                      ? 'Enter between 3 and 1000 characters.'
                      : null;
                },
              ),
            ),
          if (error != null) ...[
            const SizedBox(height: 12),
            AdminErrorBanner(message: error!),
          ],
        ],
      ),
    );
  }

  Widget dialog({
    Enrollment? enrollment,
    Widget? state,
  }) {
    final label = create
        ? 'Create fee account'
        : record
        ? 'Record payment'
        : 'Void payment';

    final subtitle = create
        ? enrollment == null
        ? 'Loading enrollment...'
        : '${enrollment.studentName} • ${enrollment.courseName}'
        : record
        ? '${widget.account!.studentName} • '
        '${widget.account!.courseName}\n'
        'Balance: ${formatInr(widget.account!.balanceAmount)}'
        : '${formatInr(widget.installment!.amount)} via '
        '${PaymentMethod.label(widget.installment!.paymentMethod)}. '
        'Voiding adds this amount back to the pending balance.';

    return AdminFormDialog(
      icon: create
          ? Icons.account_balance_wallet_outlined
          : record
          ? Icons.payments_outlined
          : Icons.block,
      title: label,
      subtitle: subtitle,
      onClose: locked ? null : close,
      body: state ?? fields(),
      actions: [
        TextButton(
          onPressed: locked ? null : close,
          child: Text(
            savedResult == null ? 'Cancel' : 'Close',
          ),
        ),
        if (savedResult == null)
          GradientButton(
            label: label,
            loading: saving,
            onPressed: editable &&
                state == null &&
                (!create || enrollment != null)
                ? save
                : null,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !locked,
      child: create
          ? FutureBuilder<Enrollment>(
        future: enrollmentFuture,
        builder: (context, snapshot) {
          final state = adminFutureState(
            snapshot,
            noun: 'enrollment',
            onRetry: () {
              if (editable) {
                setState(loadEnrollment);
              }
            },
          );

          if (state != null) {
            return dialog(state: state);
          }

          if (snapshot.data == null) {
            return dialog(
              state: const Text('Enrollment unavailable.'),
            );
          }

          return dialog(enrollment: snapshot.data);
        },
      )
          : dialog(),
    );
  }
}