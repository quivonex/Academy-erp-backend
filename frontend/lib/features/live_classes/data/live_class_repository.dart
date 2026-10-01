import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_urls.dart';
import '../../../core/network/dio_provider.dart';

import 'live_class.dart';

class LiveClassRepository {
  LiveClassRepository(this._dio);

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

  Future<LiveClassPage> list({
    String search = '',
    String? status,
    String? courseUuid,
    int page = 1,
  }) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.liveClasses,
          queryParameters: {
            'page': page,
            'page_size': 20,
            if (search.trim().isNotEmpty) 'search': search.trim(),
            if (status != null && status.isNotEmpty) 'status': status,
            if (courseUuid != null && courseUuid.isNotEmpty)
              'course_uuid': courseUuid,
          },
        );

        return LiveClassPage.fromJson(
          response.data ?? {},
        );
      });

  Future<LiveClass> detail(
    String uuid,
  ) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.liveClassDetail(uuid),
        );

        return LiveClass.fromJson(
          Map<String, dynamic>.from(
            response.data!['data'] as Map,
          ),
        );
      });

  Future<LiveClass> create({
    required String courseUuid,
    required String teacherUuid,
    required String title,
    required DateTime scheduledStartAt,
    required DateTime scheduledEndAt,
    String description = '',
    String? subjectUuid,
    String? chapterUuid,
    String? lessonUuid,
    String meetingUrl = '',
    String meetingId = '',
    String meetingPassword = '',
  }) =>
      _request(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          ApiUrls.liveClasses,
          data: {
            'course_uuid': courseUuid,
            'teacher_uuid': teacherUuid,
            'title': title.trim(),
            'description': description.trim(),
            'scheduled_start_at': scheduledStartAt.toUtc().toIso8601String(),
            'scheduled_end_at': scheduledEndAt.toUtc().toIso8601String(),
            if (subjectUuid != null) 'subject_uuid': subjectUuid,
            if (chapterUuid != null) 'chapter_uuid': chapterUuid,
            if (lessonUuid != null) 'lesson_uuid': lessonUuid,
            'meeting_url': meetingUrl.trim(),
            'meeting_id': meetingId.trim(),
            'meeting_password': meetingPassword.trim(),
          },
        );

        return LiveClass.fromJson(
          Map<String, dynamic>.from(
            response.data!['data'] as Map,
          ),
        );
      });

  Future<LiveClass> update({
    required String uuid,
    required String title,
    required String description,
    required String meetingUrl,
    required String meetingId,
    required String meetingPassword,
    DateTime? scheduledStartAt,
    DateTime? scheduledEndAt,
    bool includeSchedule = true,
  }) =>
      _request(() async {
        final data = <String, dynamic>{
          'title': title.trim(),
          'description': description.trim(),
          'meeting_url': meetingUrl.trim(),
          'meeting_id': meetingId.trim(),
          'meeting_password': meetingPassword.trim(),
        };

        if (includeSchedule) {
          if (scheduledStartAt != null) {
            data['scheduled_start_at'] =
                scheduledStartAt.toUtc().toIso8601String();
          }

          if (scheduledEndAt != null) {
            data['scheduled_end_at'] =
                scheduledEndAt.toUtc().toIso8601String();
          }
        }

        final response = await _dio.patch<Map<String, dynamic>>(
          ApiUrls.liveClassDetail(uuid),
          data: data,
        );

        return LiveClass.fromJson(
          Map<String, dynamic>.from(
            response.data!['data'] as Map,
          ),
        );
      });

  Future<LiveClass> start(
    String uuid,
  ) =>
      _request(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          ApiUrls.liveClassStart(uuid),
        );

        return LiveClass.fromJson(
          Map<String, dynamic>.from(
            response.data!['data'] as Map,
          ),
        );
      });

  Future<LiveClass> complete(
    String uuid,
  ) =>
      _request(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          ApiUrls.liveClassComplete(uuid),
        );

        return LiveClass.fromJson(
          Map<String, dynamic>.from(
            response.data!['data'] as Map,
          ),
        );
      });

  Future<LiveClass> cancel(
    String uuid,
  ) =>
      _request(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          ApiUrls.liveClassCancel(uuid),
        );

        return LiveClass.fromJson(
          Map<String, dynamic>.from(
            response.data!['data'] as Map,
          ),
        );
      });
}

final liveClassRepositoryProvider = Provider<LiveClassRepository>((ref) {
  return LiveClassRepository(
    ref.watch(dioProvider),
  );
});
