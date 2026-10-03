import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_urls.dart';
import '../../../core/network/dio_provider.dart';

import 'subject.dart';

class SubjectRepository {
  SubjectRepository(this._dio);

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

  Future<SubjectPage> list({
    String? courseUuid,
    int page = 1,
  }) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.subjects,
          queryParameters: {
            'page': page,
            'page_size': 20,
            if (courseUuid != null && courseUuid.isNotEmpty)
              'course_uuid': courseUuid,
          },
        );

        return SubjectPage.fromJson(
          response.data ?? {},
        );
      });

  Future<Subject> detail(
      String uuid,
      ) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.subjectDetail(uuid),
        );

        final resData = response.data?['data'] ?? response.data ?? {};
        return Subject.fromJson(
          Map<String, dynamic>.from(resData as Map),
        );
      });

  Future<Subject> create({
    required String courseUuid,
    required String name,
    String code = '',
    String description = '',
    String? teacherUuid,
  }) =>
      _request(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          ApiUrls.subjects,
          data: {
            'course_uuid': courseUuid,
            'name': name.trim(),
            'code': code.trim(),
            if (description.trim().isNotEmpty) 'description': description.trim(),
            if (teacherUuid != null && teacherUuid.isNotEmpty)
              'teacher_uuid': teacherUuid,
          },
        );

        final resData = response.data?['data'] ?? response.data ?? {};
        return Subject.fromJson(
          Map<String, dynamic>.from(resData as Map),
        );
      });

  Future<Subject> update({
    required String uuid,
    required String name,
    String code = '',
    String description = '',
    String? teacherUuid,
    bool updateTeacher = false,
  }) =>
      _request(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          ApiUrls.subjectDetail(uuid),
          data: {
            'name': name.trim(),
            'code': code.trim(),
            'description': description.trim(),
            if (updateTeacher || (teacherUuid != null && teacherUuid.isNotEmpty))
              'teacher_uuid': teacherUuid,
          },
        );

        final resData = response.data?['data'] ?? response.data ?? {};
        return Subject.fromJson(
          Map<String, dynamic>.from(resData as Map),
        );
      });
}

final subjectRepositoryProvider = Provider<SubjectRepository>((ref) {
  return SubjectRepository(
    ref.watch(dioProvider),
  );
});

