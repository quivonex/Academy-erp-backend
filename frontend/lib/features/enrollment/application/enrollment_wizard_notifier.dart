import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/enrollment_models.dart';
import '../data/enrollment_repository.dart';

class EnrollmentWizardState {
  const EnrollmentWizardState({
    this.enrollmentUuid,
    this.studentUuid,
    this.studentName,
    this.courseUuid,
    this.startDate,
    this.endDate,
    this.isSubmitting = false,
    this.errorMessage,
    this.isComplete = false,
  });

  final String? enrollmentUuid;
  final String? studentUuid;
  final String? studentName;
  final String? courseUuid;
  final String? startDate;
  final String? endDate;
  final bool isSubmitting;
  final String? errorMessage;
  final bool isComplete;

  EnrollmentWizardState copyWith({
    String? enrollmentUuid,
    String? studentUuid,
    String? studentName,
    String? courseUuid,
    String? startDate,
    String? endDate,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    bool? isComplete,
  }) {
    return EnrollmentWizardState(
      enrollmentUuid: enrollmentUuid ?? this.enrollmentUuid,
      studentUuid: studentUuid ?? this.studentUuid,
      studentName: studentName ?? this.studentName,
      courseUuid: courseUuid ?? this.courseUuid,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

class EnrollmentWizardNotifier extends Notifier<EnrollmentWizardState> {
  late EnrollmentRepository _repo;

  @override
  EnrollmentWizardState build() {
    _repo = ref.watch(enrollmentRepositoryProvider);
    return const EnrollmentWizardState();
  }

  void setStudent({required String uuid, required String name}) {
    state = state.copyWith(studentUuid: uuid, studentName: name, clearError: true);
  }

  void setCourse(String courseUuid) {
    state = state.copyWith(courseUuid: courseUuid, clearError: true);
  }

  void setDates({String? startDate, String? endDate}) {
    state = state.copyWith(startDate: startDate, endDate: endDate, clearError: true);
  }

  Future<bool> submit() async {
    if (state.studentUuid == null || state.courseUuid == null) {
      state = state.copyWith(errorMessage: 'Select a student and course.');
      return false;
    }
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final record = await _repo.createEnrollment(
        studentUuid: state.studentUuid!,
        courseUuid: state.courseUuid!,
        startDate: state.startDate,
        endDate: state.endDate,
      );
      state = state.copyWith(
        enrollmentUuid: record.uuid,
        isSubmitting: false,
        isComplete: true,
      );
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

final enrollmentWizardProvider =
    NotifierProvider<EnrollmentWizardNotifier, EnrollmentWizardState>(
  EnrollmentWizardNotifier.new,
);
