import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import 'enrollment_models.dart';

class EnrollmentRepository {
  EnrollmentRepository(this._dio);
  final Dio _dio;

  Future<List<CourseOption>> listCourses() async {
    try {
      final response = await _dio.get('/courses');
      return (response.data as List).map((e) => CourseOption.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<BatchOption>> listBatches() async {
    try {
      final response = await _dio.get('/batches');
      return (response.data as List).map((e) => BatchOption.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Stage 1: create the student record.
  Future<int> createStudent({
    required String fullName,
    String? guardianName,
    String? guardianPhone,
  }) async {
    try {
      final response = await _dio.post('/enrollment/students', data: {
        'full_name': fullName,
        if (guardianName != null) 'guardian_name': guardianName,
        if (guardianPhone != null) 'guardian_phone': guardianPhone,
      });
      return response.data['id'] as int;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Stage 1 completion: opens the Enrollment shell that stages 2-10 mutate.
  Future<EnrollmentRecord> startEnrollment({required int studentId, int? courseId, int? batchId}) async {
    try {
      final response = await _dio.post('/enrollment/start', data: {
        'student_id': studentId,
        if (courseId != null) 'course_id': courseId,
        if (batchId != null) 'batch_id': batchId,
      });
      return EnrollmentRecord.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<EnrollmentRecord> getEnrollment(int enrollmentId) async {
    try {
      final response = await _dio.get('/enrollment/$enrollmentId');
      return EnrollmentRecord.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Stages 2-6: academy/category/subcategory/course/batch selection.
  Future<EnrollmentRecord> advanceStage({
    required int enrollmentId,
    required int stage,
    int? courseId,
    int? batchId,
    String? category,
    String? subcategory,
  }) async {
    try {
      final response = await _dio.patch('/enrollment/$enrollmentId/stage', data: {
        'stage': stage,
        if (courseId != null) 'course_id': courseId,
        if (batchId != null) 'batch_id': batchId,
        if (category != null) 'category': category,
        if (subcategory != null) 'subcategory': subcategory,
      });
      return EnrollmentRecord.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Stage 7: Fee Configuration Engine.
  Future<FeePlanRecord> submitFeePlan({
    required int enrollmentId,
    required List<FeeComponentDraft> components,
    String? scholarshipCode,
    double scholarshipAmount = 0,
  }) async {
    try {
      final response = await _dio.post('/enrollment/$enrollmentId/fee-plan', data: {
        'components': components.map((c) => c.toJson()).toList(),
        if (scholarshipCode != null) 'scholarship_code': scholarshipCode,
        'scholarship_amount': scholarshipAmount,
      });
      return FeePlanRecord.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Stage 8: Installment Structure Plan Builder.
  Future<InstallmentPlanRecord> submitInstallmentPlan({
    required int enrollmentId,
    required String frequency, // one_time | monthly | quarterly | trimester
    int graceDays = 5,
    double penaltyFeePerWeek = 0,
    required int trancheCount,
  }) async {
    try {
      final response = await _dio.post('/enrollment/$enrollmentId/installment-plan', data: {
        'frequency': frequency,
        'grace_days': graceDays,
        'penalty_fee_per_week': penaltyFeePerWeek,
        'tranche_count': trancheCount,
      });
      return InstallmentPlanRecord.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Stage 9: Gateway & Receipt.
  Future<PaymentRecord> recordPayment({
    required int enrollmentId,
    required int installmentId,
    required String gateway, // razorpay_upi | card | net_banking | cash_pos
    required double amountPaid,
  }) async {
    try {
      final response = await _dio.post('/enrollment/$enrollmentId/pay', data: {
        'installment_id': installmentId,
        'gateway': gateway,
        'amount_paid': amountPaid,
      });
      return PaymentRecord.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Stage 10: Activate.
  Future<EnrollmentRecord> activate(int enrollmentId) async {
    try {
      final response = await _dio.post('/enrollment/$enrollmentId/activate');
      return EnrollmentRecord.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final enrollmentRepositoryProvider = Provider<EnrollmentRepository>((ref) {
  return EnrollmentRepository(ref.watch(dioProvider));
});

final courseOptionsProvider = FutureProvider<List<CourseOption>>((ref) {
  return ref.watch(enrollmentRepositoryProvider).listCourses();
});

final batchOptionsProvider = FutureProvider<List<BatchOption>>((ref) {
  return ref.watch(enrollmentRepositoryProvider).listBatches();
});
