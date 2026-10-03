import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_urls.dart';
import '../../../core/network/dio_provider.dart';

import 'chapter.dart';

class ChapterRepository {
  ChapterRepository(this._dio);

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

  Future<ChapterPage> list({
    required String subjectUuid,
    int page = 1,
  }) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.chapters,
          queryParameters: {
            'subject_uuid': subjectUuid,
            'page': page,
            'page_size': 20,
          },
        );

        return ChapterPage.fromJson(
          response.data ?? {},
        );
      });

  Future<Chapter> detail(
    String uuid,
  ) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.chapterDetail(uuid),
        );

        final resData = response.data?['data'] ?? response.data ?? {};
        return Chapter.fromJson(
          Map<String, dynamic>.from(resData as Map),
        );
      });

  Future<Chapter> create({
    required String subjectUuid,
    required String title,
    String description = '',
    int sequence = 1,
  }) =>
      _request(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          ApiUrls.chapters,
          data: {
            'subject_uuid': subjectUuid,
            'title': title.trim(),
            'description': description.trim(),
            'sequence': sequence,
          },
        );

        final resData = response.data?['data'] ?? response.data ?? {};
        return Chapter.fromJson(
          Map<String, dynamic>.from(resData as Map),
        );
      });

  Future<Chapter> update({
    required String uuid,
    required String title,
    String description = '',
    int sequence = 1,
  }) =>
      _request(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          ApiUrls.chapterDetail(uuid),
          data: {
            'title': title.trim(),
            'description': description.trim(),
            'sequence': sequence,
          },
        );

        final resData = response.data?['data'] ?? response.data ?? {};
        return Chapter.fromJson(
          Map<String, dynamic>.from(resData as Map),
        );
      });
}

final chapterRepositoryProvider = Provider<ChapterRepository>((ref) {
  return ChapterRepository(
    ref.watch(dioProvider),
  );
});
