import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';

class StudentEnrollment {
  const StudentEnrollment({
    required this.courseUuid,
    required this.courseName,
    required this.status,
    required this.hasAccess,
  });

  final String courseUuid;
  final String courseName;
  final String status;
  final bool hasAccess;
  bool get isPending => status == 'PENDING';
  bool get canRequest => status == 'NOT_ENROLLED';

  factory StudentEnrollment.fromJson(Map<String, dynamic> json) =>
      StudentEnrollment(
        courseUuid: json['course_uuid'].toString(),
        courseName: json['course_name']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        hasAccess: json['has_access'] == true,
      );
}

class StudentEnrollmentPage {
  const StudentEnrollmentPage(this.items, this.hasNext);
  final List<StudentEnrollment> items;
  final bool hasNext;
}

class StudentEnrollmentRepository {
  StudentEnrollmentRepository(this.dio);
  final Dio dio;

  Future<StudentEnrollment> status(String courseUuid) =>
      _enrollment(courseUuid);

  Future<StudentEnrollment> request(String courseUuid) => Future.error(
    const ApiException('Only the Firm Admin can enroll students after verifying payment.'),
  );

  Future<StudentEnrollment> _enrollment(
    String courseUuid,
  ) async {
    try {
      final path = '/student/courses/$courseUuid/enrollment/';
      final response = await dio.get(path);
      return StudentEnrollment.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map),
      );
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<StudentEnrollmentPage> pending({int page = 1}) async {
    try {
      final response = await dio.get('/student/enrollments/',
        queryParameters: {'page': page, 'page_size': 20});
      final data = response.data['data'] as Map;
      return StudentEnrollmentPage(
        (data['results'] as List).map((item) => StudentEnrollment.fromJson(
          Map<String, dynamic>.from(item as Map),
        )).toList(),
        data['next'] != null && data['next'].toString().isNotEmpty,
      );
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }
}

final studentEnrollmentRepositoryProvider = Provider<StudentEnrollmentRepository>(
  (ref) => StudentEnrollmentRepository(ref.watch(dioProvider)),
);
