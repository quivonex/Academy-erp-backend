import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_urls.dart';
import '../../../core/network/dio_provider.dart';

import 'course.dart';

class CourseRepository {
  CourseRepository(this._dio);

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

  Future<CoursePage> list({
    String search = '',
    int page = 1,
  }) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.courses,
          queryParameters: {
            'page': page,
            'page_size': 20,
            if (search.trim().isNotEmpty) 'search': search.trim(),
          },
        );

        return CoursePage.fromJson(
          response.data ?? {},
        );
      });

  Future<Course> detail(
    String uuid,
  ) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.courseDetail(uuid),
        );

        final data = response.data?['data'] ?? response.data ?? {};

        return Course.fromJson(
          Map<String, dynamic>.from(
            data as Map,
          ),
        );
      });

  Future<Course> create({
    required String name,
    required String code,
    required String description,
    required String price,
    required String deliveryMode,
    String? categoryUuid,
    int? durationMonths,
    int? accessDurationDays,
    bool isActive = true,
    bool isPublished = false,
    bool isPurchasableOnline = false,
    bool isFeatured = false,
    int featuredOrder = 0,
  }) =>
      _request(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          ApiUrls.courses,
          data: {
            'name': name.trim(),
            'code': code.trim(),
            'description': description.trim(),
            'price': price.trim(),
            'delivery_mode': deliveryMode,
            if (categoryUuid != null && categoryUuid.isNotEmpty)
              'category_uuid': categoryUuid,
            if (durationMonths != null) 'duration_months': durationMonths,
            if (accessDurationDays != null)
              'access_duration_days': accessDurationDays,
            'is_active': isActive,
            'is_published': isPublished,
            'is_purchasable_online': isPurchasableOnline,
            'is_featured': isFeatured,
            'featured_order': featuredOrder,
          },
        );

        final data = response.data?['data'] ?? response.data ?? {};

        return Course.fromJson(
          Map<String, dynamic>.from(
            data as Map,
          ),
        );
      });

  Future<Course> update({
    required String uuid,
    required String name,
    required String code,
    required String description,
    required String price,
    required String deliveryMode,
    String? categoryUuid,
    bool updateCategory = false,
    int? durationMonths,
    int? accessDurationDays,
    required bool isActive,
    required bool isPublished,
    required bool isPurchasableOnline,
    required bool isFeatured,
    required int featuredOrder,
  }) =>
      _request(() async {
        final payload = <String, dynamic>{
          'name': name.trim(),
          'code': code.trim(),
          'description': description.trim(),
          'price': price.trim(),
          'delivery_mode': deliveryMode,
          'duration_months': durationMonths,
          'access_duration_days': accessDurationDays,
          'is_active': isActive,
          'is_published': isPublished,
          'is_purchasable_online': isPurchasableOnline,
          'is_featured': isFeatured,
          'featured_order': featuredOrder,
        };

        if (updateCategory) {
          payload['category_uuid'] = categoryUuid;
        }

        final response = await _dio.patch<Map<String, dynamic>>(
          ApiUrls.courseDetail(uuid),
          data: payload,
        );

        final data = response.data?['data'] ?? response.data ?? {};

        return Course.fromJson(
          Map<String, dynamic>.from(
            data as Map,
          ),
        );
      });

  Future<Course> setPublished(
    String uuid,
    bool published,
  ) =>
      _request(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          ApiUrls.courseDetail(uuid),
          data: {
            'is_published': published,
          },
        );

        final data = response.data?['data'] ?? response.data ?? {};

        return Course.fromJson(
          Map<String, dynamic>.from(
            data as Map,
          ),
        );
      });
}

final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  return CourseRepository(
    ref.watch(dioProvider),
  );
});
