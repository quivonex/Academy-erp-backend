import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_urls.dart';
import '../../../core/network/dio_provider.dart';

import 'material.dart';

class MaterialRepository {
  MaterialRepository(this._dio);

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

  Future<LearningMaterialPage> list({
    String search = '',
    String? materialType,
    String? courseUuid,
    int page = 1,
  }) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.materials,
          queryParameters: {
            'page': page,
            'page_size': 20,
            if (search.trim().isNotEmpty) 'search': search.trim(),
            if (materialType != null && materialType.isNotEmpty)
              'material_type': materialType,
            if (courseUuid != null && courseUuid.isNotEmpty)
              'course_uuid': courseUuid,
          },
        );

        return LearningMaterialPage.fromJson(
          response.data ?? {},
        );
      });

  Future<LearningMaterial> detail(
    String uuid,
  ) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.materialDetail(uuid),
        );

        return LearningMaterial.fromJson(
          Map<String, dynamic>.from(
            response.data!['data'] as Map,
          ),
        );
      });

  Future<LearningMaterial> create({
    required String courseUuid,
    required String title,
    required String materialType,
    required String source,
    String description = '',
    String externalUrl = '',
    Uint8List? fileBytes,
    String? fileName,
    String? subjectUuid,
    String? chapterUuid,
    String? lessonUuid,
    String? liveClassUuid,
    int? durationSeconds,
    int sequence = 1,
    DateTime? availableFrom,
    DateTime? availableUntil,
    bool isRequired = true,
    bool countsTowardProgress = true,
  }) =>
      _request(() async {
        final data = <String, dynamic>{
          'course_uuid': courseUuid,
          'title': title.trim(),
          'description': description.trim(),
          'material_type': materialType,
          'source': source,
          'external_url': externalUrl.trim(),
          'sequence': sequence,
          'is_required': isRequired,
          'counts_toward_progress': countsTowardProgress,
          if (subjectUuid != null) 'subject_uuid': subjectUuid,
          if (chapterUuid != null) 'chapter_uuid': chapterUuid,
          if (lessonUuid != null) 'lesson_uuid': lessonUuid,
          if (liveClassUuid != null) 'live_class_uuid': liveClassUuid,
          if (durationSeconds != null) 'duration_seconds': durationSeconds,
          if (availableFrom != null)
            'available_from': availableFrom.toUtc().toIso8601String(),
          if (availableUntil != null)
            'available_until': availableUntil.toUtc().toIso8601String(),
        };

        if (fileBytes != null && fileName != null) {
          data['file'] = MultipartFile.fromBytes(
            fileBytes,
            filename: fileName,
          );
        }

        final formData = FormData.fromMap(data);

        final response = await _dio.post<Map<String, dynamic>>(
          ApiUrls.materials,
          data: formData,
        );

        return LearningMaterial.fromJson(
          Map<String, dynamic>.from(
            response.data!['data'] as Map,
          ),
        );
      });

  Future<LearningMaterial> update({
    required String uuid,
    required String title,
    required String description,
    required String externalUrl,
    int? durationSeconds,
    int sequence = 1,
    DateTime? availableFrom,
    DateTime? availableUntil,
    bool isRequired = true,
    bool countsTowardProgress = true,
  }) =>
      _request(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          ApiUrls.materialDetail(uuid),
          data: {
            'title': title.trim(),
            'description': description.trim(),
            'external_url': externalUrl.trim(),
            'duration_seconds': durationSeconds,
            'sequence': sequence,
            'available_from': availableFrom?.toUtc().toIso8601String(),
            'available_until': availableUntil?.toUtc().toIso8601String(),
            'is_required': isRequired,
            'counts_toward_progress': countsTowardProgress,
          },
        );

        return LearningMaterial.fromJson(
          Map<String, dynamic>.from(
            response.data!['data'] as Map,
          ),
        );
      });

  Future<void> delete(
    String uuid,
  ) =>
      _request(() async {
        await _dio.delete(
          ApiUrls.materialDetail(uuid),
        );
      });
}

final materialRepositoryProvider = Provider<MaterialRepository>((ref) {
  return MaterialRepository(
    ref.watch(dioProvider),
  );
});
