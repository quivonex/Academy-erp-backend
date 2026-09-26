import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/enrollment_models.dart';
import '../data/enrollment_repository.dart';

class EnrollmentWizardState {
  const EnrollmentWizardState({
    this.enrollmentId,
    this.currentStage = 1,
    this.studentId,
    this.studentName,
    this.courseId,
    this.batchId,
    this.category,
    this.subcategory,
    this.feeComponents = const [],
    this.scholarshipAmount = 0,
    this.feePlan,
    this.installmentPlan,
    this.lastPayment,
    this.isSubmitting = false,
    this.errorMessage,
    this.isActivated = false,
  });

  final int? enrollmentId;
  final int currentStage; // 1-10, mirrors the backend's `stage`
  final int? studentId;
  final String? studentName;
  final int? courseId;
  final int? batchId;
  final String? category;
  final String? subcategory;
  final List<FeeComponentDraft> feeComponents;
  final double scholarshipAmount;
  final FeePlanRecord? feePlan;
  final InstallmentPlanRecord? installmentPlan;
  final PaymentRecord? lastPayment;
  final bool isSubmitting;
  final String? errorMessage;
  final bool isActivated;

  double get feeGrossTotal => feeComponents.fold(0.0, (sum, c) => sum + c.amount);
  double get feeNetTotal => (feeGrossTotal - scholarshipAmount).clamp(0, double.infinity);

  EnrollmentWizardState copyWith({
    int? enrollmentId,
    int? currentStage,
    int? studentId,
    String? studentName,
    int? courseId,
    int? batchId,
    String? category,
    String? subcategory,
    List<FeeComponentDraft>? feeComponents,
    double? scholarshipAmount,
    FeePlanRecord? feePlan,
    InstallmentPlanRecord? installmentPlan,
    PaymentRecord? lastPayment,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    bool? isActivated,
  }) {
    return EnrollmentWizardState(
      enrollmentId: enrollmentId ?? this.enrollmentId,
      currentStage: currentStage ?? this.currentStage,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      courseId: courseId ?? this.courseId,
      batchId: batchId ?? this.batchId,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      feeComponents: feeComponents ?? this.feeComponents,
      scholarshipAmount: scholarshipAmount ?? this.scholarshipAmount,
      feePlan: feePlan ?? this.feePlan,
      installmentPlan: installmentPlan ?? this.installmentPlan,
      lastPayment: lastPayment ?? this.lastPayment,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isActivated: isActivated ?? this.isActivated,
    );
  }
}

/// Owns the whole 10-step pipeline. Each stage's "Next" button calls exactly
/// one of the methods below, mapping 1:1 to a backend endpoint — see the
/// mapping table in edusphere_backend/README.md.
class EnrollmentWizardNotifier extends Notifier<EnrollmentWizardState> {
  late EnrollmentRepository _repo;

  @override
  EnrollmentWizardState build() {
    _repo = ref.watch(enrollmentRepositoryProvider);
    return const EnrollmentWizardState();
  }

  /// Resumes an in-progress enrollment (e.g. from `/enrollment/:id`).
  Future<void> resume(int enrollmentId) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final record = await _repo.getEnrollment(enrollmentId);
      state = state.copyWith(
        enrollmentId: record.id,
        currentStage: record.stage,
        studentId: record.studentId,
        courseId: record.courseId,
        batchId: record.batchId,
        isSubmitting: false,
      );
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
    }
  }

  Future<bool> submitStage1({
    required String fullName,
    String? guardianName,
    String? guardianPhone,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final studentId = await _repo.createStudent(
        fullName: fullName,
        guardianName: guardianName,
        guardianPhone: guardianPhone,
      );
      final enrollment = await _repo.startEnrollment(studentId: studentId);
      state = state.copyWith(
        studentId: studentId,
        studentName: fullName,
        enrollmentId: enrollment.id,
        currentStage: enrollment.stage,
        isSubmitting: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Handles stages 2-6 (academy/category/subcategory/course/batch) in one
  /// flexible call, matching the backend's single PATCH /stage endpoint.
  Future<bool> submitSelectionStages({
    required int targetStage,
    String? category,
    String? subcategory,
    int? courseId,
    int? batchId,
  }) async {
    if (state.enrollmentId == null) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final enrollment = await _repo.advanceStage(
        enrollmentId: state.enrollmentId!,
        stage: targetStage,
        category: category,
        subcategory: subcategory,
        courseId: courseId,
        batchId: batchId,
      );
      state = state.copyWith(
        currentStage: enrollment.stage,
        category: category ?? state.category,
        subcategory: subcategory ?? state.subcategory,
        courseId: courseId ?? state.courseId,
        batchId: batchId ?? state.batchId,
        isSubmitting: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  void addFeeComponent(FeeComponentDraft component) {
    state = state.copyWith(feeComponents: [...state.feeComponents, component]);
  }

  void removeFeeComponent(int index) {
    final updated = [...state.feeComponents]..removeAt(index);
    state = state.copyWith(feeComponents: updated);
  }

  void setScholarshipAmount(double amount) {
    state = state.copyWith(scholarshipAmount: amount);
  }

  /// Stage 7.
  Future<bool> submitFeePlan({String? scholarshipCode}) async {
    if (state.enrollmentId == null || state.feeComponents.isEmpty) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final feePlan = await _repo.submitFeePlan(
        enrollmentId: state.enrollmentId!,
        components: state.feeComponents,
        scholarshipCode: scholarshipCode,
        scholarshipAmount: state.scholarshipAmount,
      );
      state = state.copyWith(feePlan: feePlan, currentStage: 7, isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Stage 8.
  Future<bool> submitInstallmentPlan({
    required String frequency,
    int graceDays = 5,
    double penaltyFeePerWeek = 0,
    required int trancheCount,
  }) async {
    if (state.enrollmentId == null) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final plan = await _repo.submitInstallmentPlan(
        enrollmentId: state.enrollmentId!,
        frequency: frequency,
        graceDays: graceDays,
        penaltyFeePerWeek: penaltyFeePerWeek,
        trancheCount: trancheCount,
      );
      state = state.copyWith(installmentPlan: plan, currentStage: 8, isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Stage 9.
  Future<bool> payInstallment({required int installmentId, required String gateway, required double amount}) async {
    if (state.enrollmentId == null) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final payment = await _repo.recordPayment(
        enrollmentId: state.enrollmentId!,
        installmentId: installmentId,
        gateway: gateway,
        amountPaid: amount,
      );
      state = state.copyWith(lastPayment: payment, currentStage: 9, isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Stage 10.
  Future<bool> activate() async {
    if (state.enrollmentId == null) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final enrollment = await _repo.activate(state.enrollmentId!);
      state = state.copyWith(currentStage: enrollment.stage, isSubmitting: false, isActivated: true);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  void reset() {
    state = const EnrollmentWizardState();
  }
}

final enrollmentWizardProvider = NotifierProvider<EnrollmentWizardNotifier, EnrollmentWizardState>(
  EnrollmentWizardNotifier.new,
);
