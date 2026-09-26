import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../application/enrollment_wizard_notifier.dart';
import '../data/enrollment_models.dart';
import '../data/enrollment_repository.dart';

const _stageLabels = [
  'Student',
  'Academy',
  'Category',
  'Subcategory',
  'Course',
  'Batch',
  'Configure Fees',
  'Installments',
  'Gateway & Receipt',
  'Activate',
];

/// The 10-Stage Enterprise Enrollment Pipeline. Pass [enrollmentId] to
/// resume a wizard that was closed mid-flow; omit it to start fresh at
/// Stage 1.
class EnrollmentWizardScreen extends ConsumerStatefulWidget {
  const EnrollmentWizardScreen({super.key, this.enrollmentId});

  final int? enrollmentId;

  @override
  ConsumerState<EnrollmentWizardScreen> createState() => _EnrollmentWizardScreenState();
}

class _EnrollmentWizardScreenState extends ConsumerState<EnrollmentWizardScreen> {
  late int _uiStep;

  @override
  void initState() {
    super.initState();
    _uiStep = 1;
    if (widget.enrollmentId != null) {
      Future.microtask(() async {
        await ref.read(enrollmentWizardProvider.notifier).resume(widget.enrollmentId!);
        final resumed = ref.read(enrollmentWizardProvider).currentStage;
        setState(() => _uiStep = resumed);
      });
    }
  }

  void _goToStep(int step) => setState(() => _uiStep = step.clamp(1, 10));

  @override
  Widget build(BuildContext context) {
    final wizardState = ref.watch(enrollmentWizardProvider);
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('10-Stage Enterprise Enrollment Pipeline', style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 16),
        _StageIndicator(currentStep: _uiStep, onTapStep: _goToStep),
        const SizedBox(height: 24),
        if (wizardState.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.dangerBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.danger.withValues(alpha: 0.3)),
              ),
              child: Text(wizardState.errorMessage!, style: TextStyle(color: colors.danger)),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _buildStepBody(context, wizardState),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepBody(BuildContext context, EnrollmentWizardState wizardState) {
    switch (_uiStep) {
      case 1:
        return _StudentStep(onNext: () => _goToStep(2));
      case 2:
        return _AcademyStep(onNext: () => _goToStep(3));
      case 3:
        return _CategoryStep(onNext: () => _goToStep(4));
      case 4:
        return _SubcategoryStep(onNext: () => _goToStep(5));
      case 5:
        return _CourseStep(onNext: () => _goToStep(6));
      case 6:
        return _BatchStep(onNext: () => _goToStep(7));
      case 7:
        return _FeeConfigStep(onNext: () => _goToStep(8));
      case 8:
        return _InstallmentStep(onNext: () => _goToStep(9));
      case 9:
        return _PaymentStep(onNext: () => _goToStep(10));
      case 10:
        return const _ActivateStep();
      default:
        return const SizedBox.shrink();
    }
  }
}

class _StageIndicator extends StatelessWidget {
  const _StageIndicator({required this.currentStep, required this.onTapStep});
  final int currentStep;
  final ValueChanged<int> onTapStep;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _stageLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final step = index + 1;
          final isActive = step == currentStep;
          final isDone = step < currentStep;
          return InkWell(
            onTap: () => onTapStep(step),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? colors.primary : (isDone ? colors.successBg : colors.surface),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isActive ? colors.primary : colors.borderSubtle,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDone) Icon(Icons.check, size: 14, color: colors.success),
                  if (isDone) const SizedBox(width: 4),
                  Text(
                    '$step. ${_stageLabels[index]}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isActive ? Colors.white : colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StepFooter extends StatelessWidget {
  const _StepFooter({required this.onNext, required this.isSubmitting, this.label = 'Next'});
  final VoidCallback onNext;
  final bool isSubmitting;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton(
        onPressed: isSubmitting ? null : onNext,
        child: isSubmitting
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label),
      ),
    );
  }
}

// ---- Stage 1: Student -------------------------------------------------

class _StudentStep extends ConsumerStatefulWidget {
  const _StudentStep({required this.onNext});
  final VoidCallback onNext;

  @override
  ConsumerState<_StudentStep> createState() => _StudentStepState();
}

class _StudentStepState extends ConsumerState<_StudentStep> {
  final _nameController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianPhoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final wizard = ref.watch(enrollmentWizardProvider);
    final alreadyStarted = wizard.enrollmentId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Student Details', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        if (alreadyStarted)
          Text('Student: ${wizard.studentName} · Enrollment #${wizard.enrollmentId}')
        else ...[
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Student full name')),
          const SizedBox(height: 12),
          TextField(controller: _guardianNameController, decoration: const InputDecoration(labelText: 'Guardian name')),
          const SizedBox(height: 12),
          TextField(controller: _guardianPhoneController, decoration: const InputDecoration(labelText: 'Guardian phone')),
        ],
        const SizedBox(height: 24),
        _StepFooter(
          isSubmitting: wizard.isSubmitting,
          onNext: () async {
            if (alreadyStarted) {
              widget.onNext();
              return;
            }
            final ok = await ref.read(enrollmentWizardProvider.notifier).submitStage1(
                  fullName: _nameController.text.trim(),
                  guardianName: _guardianNameController.text.trim(),
                  guardianPhone: _guardianPhoneController.text.trim(),
                );
            if (ok) widget.onNext();
          },
        ),
      ],
    );
  }
}

// ---- Stage 2: Academy (informational — user is already academy-scoped) --

class _AcademyStep extends ConsumerWidget {
  const _AcademyStep({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wizard = ref.watch(enrollmentWizardProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Academy', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const Text('This enrollment is scoped to your current academy session.'),
        const SizedBox(height: 24),
        _StepFooter(
          isSubmitting: wizard.isSubmitting,
          onNext: () async {
            final ok = await ref.read(enrollmentWizardProvider.notifier).submitSelectionStages(targetStage: 2);
            if (ok) onNext();
          },
        ),
      ],
    );
  }
}

// ---- Stages 3-4: Category / Subcategory --------------------------------

class _CategoryStep extends ConsumerStatefulWidget {
  const _CategoryStep({required this.onNext});
  final VoidCallback onNext;

  @override
  ConsumerState<_CategoryStep> createState() => _CategoryStepState();
}

class _CategoryStepState extends ConsumerState<_CategoryStep> {
  final _controller = TextEditingController(text: 'Medical');

  @override
  Widget build(BuildContext context) {
    final wizard = ref.watch(enrollmentWizardProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(controller: _controller, decoration: const InputDecoration(labelText: 'Category (e.g. Medical, Engineering)')),
        const SizedBox(height: 24),
        _StepFooter(
          isSubmitting: wizard.isSubmitting,
          onNext: () async {
            final ok = await ref.read(enrollmentWizardProvider.notifier).submitSelectionStages(
                  targetStage: 3,
                  category: _controller.text.trim(),
                );
            if (ok) widget.onNext();
          },
        ),
      ],
    );
  }
}

class _SubcategoryStep extends ConsumerStatefulWidget {
  const _SubcategoryStep({required this.onNext});
  final VoidCallback onNext;

  @override
  ConsumerState<_SubcategoryStep> createState() => _SubcategoryStepState();
}

class _SubcategoryStepState extends ConsumerState<_SubcategoryStep> {
  final _controller = TextEditingController(text: 'Foundation');

  @override
  Widget build(BuildContext context) {
    final wizard = ref.watch(enrollmentWizardProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Subcategory', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(controller: _controller, decoration: const InputDecoration(labelText: 'Subcategory (e.g. Foundation, Dropper)')),
        const SizedBox(height: 24),
        _StepFooter(
          isSubmitting: wizard.isSubmitting,
          onNext: () async {
            final ok = await ref.read(enrollmentWizardProvider.notifier).submitSelectionStages(
                  targetStage: 4,
                  subcategory: _controller.text.trim(),
                );
            if (ok) widget.onNext();
          },
        ),
      ],
    );
  }
}

// ---- Stage 5: Course ----------------------------------------------------

class _CourseStep extends ConsumerWidget {
  const _CourseStep({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wizard = ref.watch(enrollmentWizardProvider);
    final coursesAsync = ref.watch(courseOptionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Course', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        coursesAsync.when(
          data: (courses) => DropdownButtonFormField<int>(
            initialValue: wizard.courseId,
            decoration: const InputDecoration(labelText: 'Select a course'),
            items: [
              for (final course in courses) DropdownMenuItem(value: course.id, child: Text(course.name)),
            ],
            onChanged: (courseId) {
              if (courseId != null) {
                ref.read(enrollmentWizardProvider.notifier).submitSelectionStages(targetStage: 5, courseId: courseId);
              }
            },
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Could not load courses: $e'),
        ),
        const SizedBox(height: 24),
        _StepFooter(
          isSubmitting: wizard.isSubmitting,
          onNext: onNext,
        ),
      ],
    );
  }
}

// ---- Stage 6: Batch -------------------------------------------------------

class _BatchStep extends ConsumerWidget {
  const _BatchStep({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wizard = ref.watch(enrollmentWizardProvider);
    final batchesAsync = ref.watch(batchOptionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Batch', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        batchesAsync.when(
          data: (batches) {
            final filtered = wizard.courseId == null
                ? batches
                : batches.where((b) => b.courseId == wizard.courseId).toList();
            return DropdownButtonFormField<int>(
              value: wizard.batchId,
              decoration: const InputDecoration(labelText: 'Select a batch'),
              items: [
                for (final batch in filtered) DropdownMenuItem(value: batch.id, child: Text(batch.name)),
              ],
              onChanged: (batchId) {
                if (batchId != null) {
                  ref.read(enrollmentWizardProvider.notifier).submitSelectionStages(targetStage: 6, batchId: batchId);
                }
              },
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Could not load batches: $e'),
        ),
        const SizedBox(height: 24),
        _StepFooter(isSubmitting: wizard.isSubmitting, onNext: onNext),
      ],
    );
  }
}

// ---- Stage 7: Configure Fees ---------------------------------------------

class _FeeConfigStep extends ConsumerStatefulWidget {
  const _FeeConfigStep({required this.onNext});
  final VoidCallback onNext;

  @override
  ConsumerState<_FeeConfigStep> createState() => _FeeConfigStepState();
}

class _FeeConfigStepState extends ConsumerState<_FeeConfigStep> {
  final _labelController = TextEditingController();
  final _amountController = TextEditingController();
  final _scholarshipController = TextEditingController(text: '0');

  @override
  Widget build(BuildContext context) {
    final wizard = ref.watch(enrollmentWizardProvider);
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fee Configuration Engine', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        for (int i = 0; i < wizard.feeComponents.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(wizard.feeComponents[i].label),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formatCurrency(wizard.feeComponents[i].amount)),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => ref.read(enrollmentWizardProvider.notifier).removeFeeComponent(i),
                ),
              ],
            ),
          ),
        const Divider(),
        Row(
          children: [
            Expanded(
              child: TextField(controller: _labelController, decoration: const InputDecoration(labelText: 'Component label')),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 140,
              child: TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () {
                final amount = double.tryParse(_amountController.text);
                if (_labelController.text.trim().isEmpty || amount == null) return;
                ref.read(enrollmentWizardProvider.notifier).addFeeComponent(
                      FeeComponentDraft(label: _labelController.text.trim(), amount: amount),
                    );
                _labelController.clear();
                _amountController.clear();
              },
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _scholarshipController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Scholarship / merit voucher discount'),
          onChanged: (value) {
            final amount = double.tryParse(value) ?? 0;
            ref.read(enrollmentWizardProvider.notifier).setScholarshipAmount(amount);
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: colors.canvas, borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Gross Subtotal: ${formatCurrency(wizard.feeGrossTotal)}'),
              Text(
                'Net Payable: ${formatCurrency(wizard.feeNetTotal)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _StepFooter(
          isSubmitting: wizard.isSubmitting,
          onNext: () async {
            final ok = await ref.read(enrollmentWizardProvider.notifier).submitFeePlan();
            if (ok) widget.onNext();
          },
        ),
      ],
    );
  }
}

// ---- Stage 8: Installment Structure Plan Builder --------------------------

class _InstallmentStep extends ConsumerStatefulWidget {
  const _InstallmentStep({required this.onNext});
  final VoidCallback onNext;

  @override
  ConsumerState<_InstallmentStep> createState() => _InstallmentStepState();
}

class _InstallmentStepState extends ConsumerState<_InstallmentStep> {
  String _frequency = 'quarterly';
  int _trancheCount = 4;
  int _graceDays = 5;
  double _penaltyFeePerWeek = 25;

  @override
  Widget build(BuildContext context) {
    final wizard = ref.watch(enrollmentWizardProvider);
    final plan = wizard.installmentPlan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Installment Structure Plan Builder', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        if (plan == null) ...[
          DropdownButtonFormField<String>(
            value: _frequency,
            decoration: const InputDecoration(labelText: 'Installment frequency'),
            items: const [
              DropdownMenuItem(value: 'one_time', child: Text('One-time')),
              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
              DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
              DropdownMenuItem(value: 'trimester', child: Text('Trimester')),
            ],
            onChanged: (value) => setState(() => _frequency = value ?? 'quarterly'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _trancheCount.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Number of tranches'),
                  onChanged: (v) => _trancheCount = int.tryParse(v) ?? _trancheCount,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: _graceDays.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Grace window (days)'),
                  onChanged: (v) => _graceDays = int.tryParse(v) ?? _graceDays,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: _penaltyFeePerWeek.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Penalty fee / week'),
                  onChanged: (v) => _penaltyFeePerWeek = double.tryParse(v) ?? _penaltyFeePerWeek,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _StepFooter(
            label: 'Build Installments',
            isSubmitting: wizard.isSubmitting,
            onNext: () => ref.read(enrollmentWizardProvider.notifier).submitInstallmentPlan(
                  frequency: _frequency,
                  graceDays: _graceDays,
                  penaltyFeePerWeek: _penaltyFeePerWeek,
                  trancheCount: _trancheCount,
                ),
          ),
        ] else ...[
          Card(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('TRANCHE')),
                DataColumn(label: Text('DUE DATE')),
                DataColumn(label: Text('MILESTONE')),
                DataColumn(label: Text('AMOUNT')),
                DataColumn(label: Text('STATUS')),
              ],
              rows: [
                for (final installment in plan.installments)
                  DataRow(cells: [
                    DataCell(Text('#${installment.trancheNo}')),
                    DataCell(Text(formatDate(installment.dueDate))),
                    DataCell(Text(installment.milestoneGate ?? '—')),
                    DataCell(Text(formatCurrency(installment.amount))),
                    DataCell(Text(installment.status.toUpperCase())),
                  ]),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _StepFooter(isSubmitting: wizard.isSubmitting, onNext: widget.onNext),
        ],
      ],
    );
  }
}

// ---- Stage 9: Gateway & Receipt -------------------------------------------

class _PaymentStep extends ConsumerStatefulWidget {
  const _PaymentStep({required this.onNext});
  final VoidCallback onNext;

  @override
  ConsumerState<_PaymentStep> createState() => _PaymentStepState();
}

class _PaymentStepState extends ConsumerState<_PaymentStep> {
  String _gateway = 'razorpay_upi';

  @override
  Widget build(BuildContext context) {
    final wizard = ref.watch(enrollmentWizardProvider);
    final installments = wizard.installmentPlan?.installments ?? const [];
    final dueInstallment = installments.isNotEmpty ? installments.first : null;

    if (wizard.lastPayment != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Recorded', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text('Receipt ${wizard.lastPayment!.receiptNo} — ${formatCurrency(wizard.lastPayment!.amountPaid)}'),
          const SizedBox(height: 24),
          _StepFooter(isSubmitting: wizard.isSubmitting, onNext: widget.onNext),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment Channel Selection', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        if (dueInstallment != null)
          Text('Amount Payable Today: ${formatCurrency(dueInstallment.amount)} (Tranche 1)'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final option in const [
              ('razorpay_upi', 'Razorpay / UPI'),
              ('card', 'Card Payment'),
              ('net_banking', 'Net Banking'),
              ('cash_pos', 'Cash / POS Desk'),
            ])
              ChoiceChip(
                label: Text(option.$2),
                selected: _gateway == option.$1,
                onSelected: (_) => setState(() => _gateway = option.$1),
              ),
          ],
        ),
        const SizedBox(height: 24),
        _StepFooter(
          label: 'Proceed to Payment',
          isSubmitting: wizard.isSubmitting,
          onNext: () async {
            if (dueInstallment == null) return;
            await ref.read(enrollmentWizardProvider.notifier).payInstallment(
                  installmentId: dueInstallment.id,
                  gateway: _gateway,
                  amount: dueInstallment.amount,
                );
          },
        ),
      ],
    );
  }
}

// ---- Stage 10: Activate ----------------------------------------------------

class _ActivateStep extends ConsumerWidget {
  const _ActivateStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wizard = ref.watch(enrollmentWizardProvider);
    final colors = context.colors;

    if (wizard.isActivated) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: colors.success, size: 40),
          const SizedBox(height: 12),
          Text('Enrollment Activated', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('${wizard.studentName} is now an active student. Enrollment #${wizard.enrollmentId}.'),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => ref.read(enrollmentWizardProvider.notifier).reset(),
            child: const Text('Start a new enrollment'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Final Review & Activation', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text('Student: ${wizard.studentName ?? '—'}'),
        Text('Net Payable: ${formatCurrency(wizard.feePlan?.netPayable ?? 0)}'),
        Text('Latest Receipt: ${wizard.lastPayment?.receiptNo ?? '—'}'),
        const SizedBox(height: 24),
        _StepFooter(
          label: 'Activate Enrollment',
          isSubmitting: wizard.isSubmitting,
          onNext: () => ref.read(enrollmentWizardProvider.notifier).activate(),
        ),
      ],
    );
  }
}
