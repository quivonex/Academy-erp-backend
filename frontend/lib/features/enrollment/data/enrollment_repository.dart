import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_urls.dart';
import '../../../core/network/dio_provider.dart';
import 'enrollment_models.dart';

class EnrollmentRepository {
  EnrollmentRepository(this._dio);
  final Dio _dio;

  Future<List<CourseOption>> listCourses() async {
    try {
      final response = await _dio.get(ApiUrls.courses);
      final data = response.data;
      final results = data is Map ? (data['results'] as List? ?? []) : (data as List);
      return results.map((e) => CourseOption.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<EnrollmentRecord> createEnrollment({
    required String studentUuid,
    required String courseUuid,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final response = await _dio.post(ApiUrls.enrollments, data: {
        'student_uuid': studentUuid,
        'course_uuid': courseUuid,
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
      });
      final data = response.data is Map && response.data['data'] != null
          ? response.data['data']
          : response.data;
      return EnrollmentRecord.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<EnrollmentRecord> getEnrollment(String uuid) async {
    try {
      final response = await _dio.get(ApiUrls.enrollmentDetail(uuid));
      final data = response.data is Map && response.data['data'] != null
          ? response.data['data']
          : response.data;
      return EnrollmentRecord.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<EnrollmentRecord> updateEnrollment({
    required String uuid,
    String? status,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final response = await _dio.patch(ApiUrls.enrollmentDetail(uuid), data: {
        if (status != null) 'status': status,
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
      });
      final data = response.data is Map && response.data['data'] != null
          ? response.data['data']
          : response.data;
      return EnrollmentRecord.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deleteEnrollment(String uuid) async {
    try {
      await _dio.delete(ApiUrls.enrollmentDetail(uuid));
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
