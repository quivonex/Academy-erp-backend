import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../enrollments/data/enrollment.dart';
import '../../enrollments/data/enrollment_repository.dart';
import '../data/fee_models.dart';
import '../data/fee_repository.dart';

// ─────────────────────────── shared helpers ───────────────────────────

final _amountFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'^\d{0,8}(\.\d{0,2})?'),
);

double? _parseAmount(String text) => double.tryParse(text.trim());

String? _requiredAmount(String? value) {
  final amount = _parseAmount(value ?? '');
  if (amount == null) return 'Enter an amount';
  if (amount <= 0) return 'Amount must be more than 0';
  return null;
}

Widget _dateTile({
  required BuildContext context,
  required DateTime? value,
  required String emptyLabel,
  required bool enabled,
  required VoidCallback onPick,
  VoidCallback? onClear,
}) {
  return InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: enabled ? onPick : null,
    child: InputDecorator(
      decoration: adminFieldDecoration(
        context,
        icon: Icons.calendar_today_outlined,
        suffix: value != null && onClear != null && enabled
            ? IconButton(
                tooltip: 'Clear date',
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: onClear,
              )
            : null,
      ),
      child: Text(value == null ? emptyLabel : formatDate(value)),
    ),
  );
}

// ─────────────────────────── Create fee account ───────────────────────────

/// Returns the created [FeeAccount] on success, `null` when cancelled.
class CreateFeeAccountDialog extends ConsumerStatefulWidget {
  const CreateFeeAccountDialog({super.key, this.enrollmentUuid});

  /// When opened from an enrollment, the enrollment is pre-selected and locked.
  final String? enrollmentUuid;

  @override
  ConsumerState<CreateFeeAccountDialog> createState() =>
      _CreateFeeAccountDialogState();
}

class _CreateFeeAccountDialogState
    extends ConsumerState<CreateFeeAccountDialog> {
  final formKey = GlobalKey<FormState>();
  final total = TextEditingController();
  final discount = TextEditingController(text: '0');
  final notes = TextEditingController();

  List<Enrollment> enrollments = [];
  String? enrollmentUuid;
  DateTime? dueDate;

  bool loading = true;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    enrollmentUuid = widget.enrollmentUuid;
    total.addListener(_refreshPreview);
    discount.addListener(_refreshPreview);
    _loadEnrollments();
  }

  @override
  void dispose() {
    total.dispose();
    discount.dispose();
    notes.dispose();
    super.dispose();
  }

  void _refreshPreview() => setState(() {});

  Future<void> _loadEnrollments() async {
    try {
      final enrollmentRepo = ref.read(enrollmentManagementRepositoryProvider);
      final feeRepo = ref.read(feeRepositoryProvider);

      final loaded = <Enrollment>[];
      var page = 1;
      while (true) {
        final result = await enrollmentRepo.list(page: page);
        loaded.addAll(result.results);
        if (result.results.isEmpty || loaded.length >= result.count) break;
        page++;
      }

      // Hide enrollments that already have a fee account.
      final existing = (await feeRepo.allFeeAccounts())
          .map((a) => a.enrollmentUuid)
          .toSet();

      if (!mounted) return;
      setState(() {
        enrollments = loaded
            .where((e) =>
                !existing.contains(e.uuid) || e.uuid == widget.enrollmentUuid)
            .toList();
        error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not load enrollments. Try again.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  double get _total => _parseAmount(total.text) ?? 0;
  double get _discount => _parseAmount(discount.text) ?? 0;

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dueDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => dueDate = picked);
  }

  Future<void> _save() async {
    if (enrollmentUuid == null) {
      setState(() => error = 'Select an enrollment.');
      return;
    }
    if (!(formKey.currentState?.validate() ?? false)) return;

    setState(() {
      saving = true;
      error = null;
    });

    try {
      final created = await ref.read(feeRepositoryProvider).createFeeAccount(
            enrollmentUuid: enrollmentUuid!,
            totalAmount: _total,
            discountAmount: _discount,
            dueDate: dueDate,
            notes: notes.text,
          );
      if (mounted) Navigator.of(context).pop(created);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not create the fee account. Try again.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final net = (_total - _discount).clamp(0, double.infinity);
    final locked = widget.enrollmentUuid != null;

    return PopScope(
      canPop: !saving,
      child: AdminFormDialog(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Create fee account',
        subtitle: 'Set the course fee a student owes for one enrollment.',
        onClose: saving ? null : () => Navigator.of(context).pop(),
        body: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FieldLabel(
                label: 'Enrollment',
                required: true,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('fee_enrollment_${enrollments.length}'),
                  isExpanded: true,
                  value: enrollments.any((e) => e.uuid == enrollmentUuid)
                      ? enrollmentUuid
                      : null,
                  decoration: adminFieldDecoration(
                    context,
                    hint: loading
                        ? 'Loading enrollments…'
                        : enrollments.isEmpty
                            ? 'Every enrollment already has a fee account'
                            : 'Select student and course',
                  ),
                  items: [
                    for (final e in enrollments)
                      DropdownMenuItem(
                        value: e.uuid,
                        child: Text(
                          '${e.studentName}'
                          '${e.admissionNumber.isEmpty ? '' : ' (${e.admissionNumber})'}'
                          ' — ${e.courseName}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: saving || loading || locked
                      ? null
                      : (value) => setState(() {
                            enrollmentUuid = value;
                            error = null;
                          }),
                ),
              ),
              if (loading) ...[
                const SizedBox(height: 6),
                const LinearProgressIndicator(minHeight: 2),
              ],
              const SizedBox(height: 16),
              FormRow(
                left: FieldLabel(
                  label: 'Total fee (₹)',
                  required: true,
                  child: TextFormField(
                    controller: total,
                    enabled: !saving,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [_amountFormatter],
                    decoration: adminFieldDecoration(context, hint: '25000'),
                    validator: _requiredAmount,
                  ),
                ),
                right: FieldLabel(
                  label: 'Discount (₹)',
                  child: TextFormField(
                    controller: discount,
                    enabled: !saving,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [_amountFormatter],
                    decoration: adminFieldDecoration(context, hint: '0'),
                    validator: (value) {
                      final d = _parseAmount(value ?? '') ?? 0;
                      if (d < 0) return 'Cannot be negative';
                      if (_total > 0 && d >= _total) {
                        return 'Must be less than the total fee';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Student pays ${formatInr(net)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),
              FieldLabel(
                label: 'Due date',
                child: _dateTile(
                  context: context,
                  value: dueDate,
                  emptyLabel: 'No due date',
                  enabled: !saving,
                  onPick: _pickDueDate,
                  onClear: () => setState(() => dueDate = null),
                ),
              ),
              const SizedBox(height: 16),
              FieldLabel(
                label: 'Notes',
                child: TextFormField(
                  controller: notes,
                  enabled: !saving,
                  maxLines: 3,
                  decoration: adminFieldDecoration(
                    context,
                    hint: 'Optional, e.g. scholarship details',
                  ),
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
            label: 'Create fee account',
            icon: Icons.check_rounded,
            loading: saving,
            onPressed: saving || loading ? null : _save,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Record installment ───────────────────────────

/// Returns the [InstallmentChange] on success, `null` when cancelled.
class RecordInstallmentDialog extends ConsumerStatefulWidget {
  const RecordInstallmentDialog({super.key, required this.account});

  final FeeAccount account;

  @override
  ConsumerState<RecordInstallmentDialog> createState() =>
      _RecordInstallmentDialogState();
}

class _RecordInstallmentDialogState
    extends ConsumerState<RecordInstallmentDialog> {
  final formKey = GlobalKey<FormState>();
  final amount = TextEditingController();
  final reference = TextEditingController();
  final notes = TextEditingController();

  String method = 'CASH';
  DateTime paymentDate = DateTime.now();

  bool saving = false;
  String? error;

  @override
  void dispose() {
    amount.dispose();
    reference.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: paymentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => paymentDate = picked);
  }

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    setState(() {
      saving = true;
      error = null;
    });

    try {
      final change =
          await ref.read(feeRepositoryProvider).recordInstallment(
                feeAccountUuid: widget.account.uuid,
                amount: _parseAmount(amount.text)!,
                paymentMethod: method,
                transactionReference: reference.text,
                paymentDate: paymentDate,
                notes: notes.text,
              );
      if (mounted) Navigator.of(context).pop(change);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not record the payment. Try again.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final balance = account.balanceAmount;

    return PopScope(
      canPop: !saving,
      child: AdminFormDialog(
        icon: Icons.payments_outlined,
        title: 'Record payment',
        subtitle: '${account.studentName} • ${account.courseName}\n'
            'Balance due: ${formatInr(balance)}',
        onClose: saving ? null : () => Navigator.of(context).pop(),
        body: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FieldLabel(
                label: 'Amount received (₹)',
                required: true,
                trailing: TextButton(
                  onPressed: saving
                      ? null
                      : () => amount.text = apiAmount(balance),
                  child: const Text('Full balance'),
                ),
                child: TextFormField(
                  controller: amount,
                  enabled: !saving,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [_amountFormatter],
                  decoration: adminFieldDecoration(
                    context,
                    hint: 'Up to ${formatInr(balance)}',
                  ),
                  validator: (value) {
                    final base = _requiredAmount(value);
                    if (base != null) return base;
                    if (_parseAmount(value!)! > balance + 0.001) {
                      return 'Cannot be more than the balance '
                          '(${formatInr(balance)})';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),
              FormRow(
                left: FieldLabel(
                  label: 'Payment method',
                  required: true,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: method,
                    decoration: adminFieldDecoration(context),
                    items: [
                      for (final entry in PaymentMethod.values.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: saving
                        ? null
                        : (value) => setState(() => method = value ?? 'CASH'),
                  ),
                ),
                right: FieldLabel(
                  label: 'Payment date',
                  required: true,
                  child: _dateTile(
                    context: context,
                    value: paymentDate,
                    emptyLabel: 'Today',
                    enabled: !saving,
                    onPick: _pickDate,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FieldLabel(
                label: 'Transaction reference',
                required: PaymentMethod.expectsReference(method),
                child: TextFormField(
                  controller: reference,
                  enabled: !saving,
                  maxLength: 100,
                  decoration: adminFieldDecoration(
                    context,
                    hint: PaymentMethod.expectsReference(method)
                        ? 'UTR / transaction ID'
                        : 'Optional, e.g. receipt number',
                  ),
                  validator: (value) =>
                      PaymentMethod.expectsReference(method) &&
                              (value ?? '').trim().isEmpty
                          ? 'Enter the transaction reference'
                          : null,
                ),
              ),
              const SizedBox(height: 8),
              FieldLabel(
                label: 'Notes',
                child: TextFormField(
                  controller: notes,
                  enabled: !saving,
                  maxLines: 2,
                  decoration: adminFieldDecoration(context, hint: 'Optional'),
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
            label: 'Record payment',
            icon: Icons.check_rounded,
            loading: saving,
            onPressed: saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Void installment ───────────────────────────

/// Returns the [InstallmentChange] on success, `null` when cancelled.
class VoidInstallmentDialog extends ConsumerStatefulWidget {
  const VoidInstallmentDialog({super.key, required this.installment});

  final Installment installment;

  @override
  ConsumerState<VoidInstallmentDialog> createState() =>
      _VoidInstallmentDialogState();
}

class _VoidInstallmentDialogState
    extends ConsumerState<VoidInstallmentDialog> {
  final formKey = GlobalKey<FormState>();
  final reason = TextEditingController();

  bool saving = false;
  String? error;

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> _void() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    setState(() {
      saving = true;
      error = null;
    });

    try {
      final change = await ref.read(feeRepositoryProvider).voidInstallment(
            installmentUuid: widget.installment.uuid,
            reason: reason.text,
          );
      if (mounted) Navigator.of(context).pop(change);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not void the payment. Try again.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.installment;
    final date = i.paymentDate == null ? '' : ' on ${formatDate(i.paymentDate!)}';

    return PopScope(
      canPop: !saving,
      child: AdminFormDialog(
        icon: Icons.block_rounded,
        title: 'Void payment',
        subtitle: '${formatInr(i.amount)} via '
            '${PaymentMethod.label(i.paymentMethod)}$date. '
            'The amount is added back to the balance.',
        onClose: saving ? null : () => Navigator.of(context).pop(),
        body: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FieldLabel(
                label: 'Reason',
                required: true,
                child: TextFormField(
                  controller: reason,
                  enabled: !saving,
                  autofocus: true,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: adminFieldDecoration(
                    context,
                    hint: 'e.g. Cheque bounced, entered twice',
                  ),
                  validator: (value) => (value ?? '').trim().length < 3
                      ? 'Enter at least 3 characters'
                      : null,
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                AdminErrorBanner(message: error!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Keep payment'),
          ),
          AdminOutlineButton(
            label: saving ? 'Voiding…' : 'Void payment',
            icon: Icons.block_rounded,
            danger: true,
            onPressed: saving ? null : _void,
          ),
        ],
      ),
    );
  }
}
