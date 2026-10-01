import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_urls.dart';
import '../../../core/network/dio_provider.dart';

import 'lesson.dart';

class LessonRepository {
  LessonRepository(this._dio);

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

  Future<LessonPage> list({
    required String chapterUuid,
    int page = 1,
  }) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.lessons,
          queryParameters: {
            'chapter_uuid': chapterUuid,
            'page': page,
            'page_size': 20,
          },
        );

        return LessonPage.fromJson(
          response.data ?? {},
        );
      });

  Future<Lesson> detail(
    String uuid,
  ) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.lessonDetail(uuid),
        );

        final resData = response.data?['data'] ?? response.data ?? {};
        return Lesson.fromJson(
          Map<String, dynamic>.from(resData as Map),
        );
      });

  Future<Lesson> create({
    required String chapterUuid,
    required String title,
    String description = '',
    int sequence = 1,
  }) =>
      _request(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          ApiUrls.lessons,
          data: {
            'chapter_uuid': chapterUuid,
            'title': title.trim(),
            'description': description.trim(),
            'sequence': sequence,
          },
        );

        final resData = response.data?['data'] ?? response.data ?? {};
        return Lesson.fromJson(
          Map<String, dynamic>.from(resData as Map),
        );
      });

  Future<Lesson> update({
    required String uuid,
    required String title,
    String description = '',
    int sequence = 1,
  }) =>
      _request(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          ApiUrls.lessonDetail(uuid),
          data: {
            'title': title.trim(),
            'description': description.trim(),
            'sequence': sequence,
          },
        );

        final resData = response.data?['data'] ?? response.data ?? {};
        return Lesson.fromJson(
          Map<String, dynamic>.from(resData as Map),
        );
      });
}

final lessonRepositoryProvider = Provider<LessonRepository>((ref) {
  return LessonRepository(
    ref.watch(dioProvider),
  );
});
