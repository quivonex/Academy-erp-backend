import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';

class DeviceRegistration {
  const DeviceRegistration(
    this.uuid,
    this.platform,
    this.lastSeenAt,
  );

  final String uuid;
  final String platform;
  final DateTime? lastSeenAt;
}

class DeviceNotificationRepository {
  DeviceNotificationRepository(this.dio);

  final Dio dio;
  static const platforms = ['ANDROID', 'WEB', 'IOS'];

  static String validatedToken(String raw) {
    final token = raw.trim();

    if (token.isEmpty || token.runes.length > 8192) {
      throw const ApiException(
        'Enter a device token of up to 8192 characters.',
      );
    }

    return token;
  }

  Future<T> request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Map<String, dynamic> data(Map<String, dynamic>? body) {
    if (body == null ||
        body['success'] != true ||
        body['data'] is! Map) {
      throw const FormatException('Invalid device response.');
    }

    return Map<String, dynamic>.from(body['data'] as Map);
  }

  Future<DeviceRegistration> register({
    required String token,
    required String platform,
    String deviceId = '',
  }) =>
      request(() async {
        final value = validatedToken(token);
        final id = deviceId.trim();

        if (!platforms.contains(platform) ||
            id.runes.length > 255) {
          throw const ApiException(
            'Choose a platform and use a device ID '
            'of up to 255 characters.',
          );
        }

        final response = await dio.post<Map<String, dynamic>>(
          '/notifications/devices/register/',
          data: {
            'token': value,
            'platform': platform,
            if (id.isNotEmpty) 'device_id': id,
          },
        );

        final body = data(response.data);

        if (body['uuid'] is! String ||
            (body['uuid'] as String).isEmpty ||
            body['platform'] != platform ||
            body['is_active'] != true) {
          throw const FormatException(
            'Invalid registration response.',
          );
        }

        return DeviceRegistration(
          body['uuid'] as String,
          body['platform'] as String,
          DateTime.tryParse(
            body['last_seen_at']?.toString() ?? '',
          ),
        );
      });

  Future<int> unregister(String token) => request(() async {
        final response = await dio.post<Map<String, dynamic>>(
          '/notifications/devices/unregister/',
          data: {
            'token': validatedToken(token),
          },
        );

        final count = data(response.data)['updated_count'];

        if (count is! int || count < 0) {
          throw const FormatException(
            'Invalid unregistration response.',
          );
        }

        return count;
      });
}

final deviceNotificationRepositoryProvider =
    Provider<DeviceNotificationRepository>(
  (ref) => DeviceNotificationRepository(
    ref.watch(dioProvider),
  ),
);
