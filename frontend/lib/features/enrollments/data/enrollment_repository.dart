import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_urls.dart';
import '../../../core/network/dio_provider.dart';

import 'enrollment.dart';

class EnrollmentRepository {
  EnrollmentRepository(this._dio);

  final Dio _dio;

  Future<T> _request<T>(
    Future<T> Function() operation,
  ) async {
    try {
      return await operation();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<EnrollmentPage> list({
    int page = 1,
    String? studentUuid,
    String? courseUuid,
  }) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.enrollments,
          queryParameters: {
            'page': page,
            'page_size': 20,
            if (studentUuid != null && studentUuid.isNotEmpty)
              'student_uuid': studentUuid,
            if (courseUuid != null && courseUuid.isNotEmpty)
              'course_uuid': courseUuid,
          },
        );

        return EnrollmentPage.fromJson(
          response.data ?? {},
        );
      });

  Future<Enrollment> detail(
    String uuid,
  ) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.enrollmentDetail(uuid),
        );

        final resData = response.data?['data'] ?? response.data ?? {};
        return Enrollment.fromJson(
          Map<String, dynamic>.from(resData as Map),
        );
      });

  Future<Enrollment> create({
    required String studentUuid,
    required String courseUuid,
    String status = 'ACTIVE',
    DateTime? accessStartAt,
    DateTime? accessEndAt,
  }) =>
      _request(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          ApiUrls.enrollments,
          data: {
            'student_uuid': studentUuid,
            'course_uuid': courseUuid,
            'status': status,
            if (accessStartAt != null)
              'access_start_at': accessStartAt.toUtc().toIso8601String(),
            if (accessEndAt != null)
              'access_end_at': accessEndAt.toUtc().toIso8601String(),
          },
        );

        final resData = response.data?['data'] ?? response.data ?? {};
        return Enrollment.fromJson(
          Map<String, dynamic>.from(resData as Map),
        );
      });

  Future<Enrollment> update({
    required String uuid,
    required String status,
    DateTime? accessStartAt,
    DateTime? accessEndAt,
  }) =>
      _request(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          ApiUrls.enrollmentDetail(uuid),
          data: {
            'status': status,
            'access_start_at': accessStartAt?.toUtc().toIso8601String(),
            'access_end_at': accessEndAt?.toUtc().toIso8601String(),
          },
        );

        final resData = response.data?['data'] ?? response.data ?? {};
        return Enrollment.fromJson(
          Map<String, dynamic>.from(resData as Map),
        );
      });
}

final enrollmentManagementRepositoryProvider =
    Provider<EnrollmentRepository>((ref) {
  return EnrollmentRepository(
    ref.watch(dioProvider),
  );
});
