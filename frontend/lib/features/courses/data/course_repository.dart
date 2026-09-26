import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_urls.dart';
import '../../../core/network/dio_provider.dart';
import 'course.dart';

class CourseRepository {
  CourseRepository(this._dio);
  final Dio _dio;

  Future<T> _request<T>(Future<T> Function() operation) async {
    try { return await operation(); }
    on DioException catch (e) { throw ApiException.fromDioException(e); }
  }

  Future<CoursePage> list({String search = '', int page = 1}) => _request(() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiUrls.courses, queryParameters: {
      'page': page, 'page_size': 20,
      if (search.trim().isNotEmpty) 'search': search.trim(),
    });
    return CoursePage.fromJson(response.data ?? {});
  });

  Future<Course> detail(String uuid) => _request(() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiUrls.courseDetail(uuid));
    return Course.fromJson(Map<String, dynamic>.from(response.data!['data'] as Map));
  });

  Future<Course> create({required String name, required String code,
    required String description, required String price,
    required String deliveryMode}) => _request(() async {
    final response = await _dio.post<Map<String, dynamic>>(ApiUrls.courses, data: {
      'name': name.trim(), 'code': code.trim(), 'description': description.trim(),
      'price': price, 'delivery_mode': deliveryMode,
    });
    return Course.fromJson(Map<String, dynamic>.from(response.data!['data'] as Map));
  });

  Future<Course> setPublished(String uuid, bool published) => _request(() async {
    final response = await _dio.patch<Map<String, dynamic>>(ApiUrls.courseDetail(uuid),
      data: {'is_published': published});
    return Course.fromJson(Map<String, dynamic>.from(response.data!['data'] as Map));
  });
}

final courseRepositoryProvider = Provider<CourseRepository>((ref) =>
  CourseRepository(ref.watch(dioProvider)));
