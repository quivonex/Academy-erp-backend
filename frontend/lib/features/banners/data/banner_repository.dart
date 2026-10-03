import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_urls.dart';
import '../../../core/network/dio_provider.dart';

import 'banner.dart';
export 'banner.dart';

class BannerRepository {
  BannerRepository(this._dio);

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

  Future<HomeBannerPage> list({
    int page = 1,
  }) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.banners,
          queryParameters: {
            'page': page,
            'page_size': 20,
          },
        );

        return HomeBannerPage.fromJson(
          response.data ?? {},
        );
      });

  Future<HomeBanner> detail(
    String uuid,
  ) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.bannerDetail(uuid),
        );

        final data = response.data?['data'] ?? response.data ?? {};

        return HomeBanner.fromJson(
          Map<String, dynamic>.from(
            data as Map,
          ),
        );
      });

  Future<HomeBanner> create({
    required String title,
    String subtitle = '',
    required Uint8List imageBytes,
    required String imageName,
    String actionLabel = '',
    String actionUrl = '',
    String? courseUuid,
    int displayOrder = 0,
    DateTime? startsAt,
    DateTime? endsAt,
    bool isActive = true,
  }) =>
      _request(() async {
        final formData = FormData.fromMap({
          'title': title.trim(),
          'subtitle': subtitle.trim(),
          'image': MultipartFile.fromBytes(
            imageBytes,
            filename: imageName,
          ),
          'action_label': actionLabel.trim(),
          'action_url': actionUrl.trim(),
          if (courseUuid != null && courseUuid.isNotEmpty)
            'course_uuid': courseUuid,
          'display_order': displayOrder,
          if (startsAt != null) 'starts_at': startsAt.toUtc().toIso8601String(),
          if (endsAt != null) 'ends_at': endsAt.toUtc().toIso8601String(),
          'is_active': isActive,
        });

        final response = await _dio.post<Map<String, dynamic>>(
          ApiUrls.banners,
          data: formData,
        );

        final data = response.data?['data'] ?? response.data ?? {};

        return HomeBanner.fromJson(
          Map<String, dynamic>.from(
            data as Map,
          ),
        );
      });

  Future<HomeBanner> update({
    required String uuid,
    required String title,
    String subtitle = '',
    String actionLabel = '',
    String? actionUrl,
    String? courseUuid,
    bool updateCourse = false,
    int displayOrder = 0,
    DateTime? startsAt,
    DateTime? endsAt,
    bool isActive = true,
    Uint8List? imageBytes,
    String? imageName,
  }) =>
      _request(() async {
        final data = <String, dynamic>{
          'title': title.trim(),
          'subtitle': subtitle.trim(),
          'action_label': actionLabel.trim(),
          'display_order': displayOrder,
          'is_active': isActive,
          if (actionUrl != null) 'action_url': actionUrl.trim(),
          if (updateCourse) 'course_uuid': courseUuid,
          'starts_at': startsAt?.toUtc().toIso8601String(),
          'ends_at': endsAt?.toUtc().toIso8601String(),
        };

        if (imageBytes != null && imageName != null) {
          data['image'] = MultipartFile.fromBytes(
            imageBytes,
            filename: imageName,
          );
        }

        final response = await _dio.patch<Map<String, dynamic>>(
          ApiUrls.bannerDetail(uuid),
          data: FormData.fromMap(data),
        );

        final responseData = response.data?['data'] ?? response.data ?? {};

        return HomeBanner.fromJson(
          Map<String, dynamic>.from(
            responseData as Map,
          ),
        );
      });

  Future<void> delete(
    String uuid,
  ) =>
      _request(() async {
        await _dio.delete(
          ApiUrls.bannerDetail(uuid),
        );
      });
}

final bannerRepositoryProvider = Provider<BannerRepository>((ref) {
  return BannerRepository(
    ref.watch(dioProvider),
  );
});
