import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_urls.dart';
import '../../../core/network/dio_provider.dart';

import 'course_category.dart';

class CourseCategoryRepository {
  CourseCategoryRepository(this._dio);

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

  Future<AdminCourseCategoryPage> list({
    String search = '',
    int page = 1,
  }) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.courseCategories,
          queryParameters: {
            'page': page,
            'page_size': 20,
            if (search.trim().isNotEmpty) 'search': search.trim(),
          },
        );

        return AdminCourseCategoryPage.fromJson(
          response.data ?? {},
        );
      });

  Future<AdminCourseCategory> detail(
    String uuid,
  ) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.courseCategoryDetail(uuid),
        );

        final data = response.data?['data'] ?? response.data ?? {};

        return AdminCourseCategory.fromJson(
          Map<String, dynamic>.from(
            data as Map,
          ),
        );
      });

  Future<AdminCourseCategory> create({
    required String name,
    String description = '',
    bool isActive = true,
  }) =>
      _request(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          ApiUrls.courseCategories,
          data: {
            'name': name.trim(),
            'description': description.trim(),
            'is_active': isActive,
          },
        );

        final data = response.data?['data'] ?? response.data ?? {};

        return AdminCourseCategory.fromJson(
          Map<String, dynamic>.from(
            data as Map,
          ),
        );
      });

  Future<AdminCourseCategory> update({
    required String uuid,
    String? name,
    String? description,
    bool? isActive,
  }) =>
      _request(() async {
        final payload = <String, dynamic>{};

        if (name != null) {
          payload['name'] = name.trim();
        }

        if (description != null) {
          payload['description'] = description.trim();
        }

        if (isActive != null) {
          payload['is_active'] = isActive;
        }

        final response = await _dio.patch<Map<String, dynamic>>(
          ApiUrls.courseCategoryDetail(
            uuid,
          ),
          data: payload,
        );

        final data = response.data?['data'] ?? response.data ?? {};

        return AdminCourseCategory.fromJson(
          Map<String, dynamic>.from(
            data as Map,
          ),
        );
      });
}

final courseCategoryRepositoryProvider = Provider<CourseCategoryRepository>(
  (ref) => CourseCategoryRepository(
    ref.watch(dioProvider),
  ),
);
