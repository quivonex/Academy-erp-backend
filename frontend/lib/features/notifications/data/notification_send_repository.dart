import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';

class NotificationDeliveryUnknown implements Exception {
  const NotificationDeliveryUnknown();
}

class NotificationSendRepository {
  NotificationSendRepository(this.dio);

  final Dio dio;

  static const types = <String, String>{
    'GENERAL': 'General',
    'COURSE_ACCESS': 'Course access',
    'ASSIGNMENT': 'Assignment',
    'LIVE_CLASS': 'Live class',
    'MATERIAL': 'Material',
    'PAYMENT': 'Payment',
    'RESULT': 'Result',
  };

  static final uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  static List<String> recipients(String text) {
    final values = text
        .trim()
        .split(RegExp(r'[\s,;]+'))
        .where((value) => value.isNotEmpty)
        .map((value) => value.toLowerCase())
        .toList();

    if (values.isEmpty || values.length > 500) {
      throw const ApiException(
        'Enter between 1 and 500 recipient user UUIDs.',
      );
    }

    if (values.any((value) => !uuidPattern.hasMatch(value))) {
      throw const ApiException(
        'Enter complete user UUIDs separated by commas or new lines.',
      );
    }

    if (values.toSet().length != values.length) {
      throw const ApiException(
        'Duplicate recipient UUIDs are not allowed.',
      );
    }

    return values;
  }

  Future<int> send({
    required List<String> userUuids,
    required String type,
    required String title,
    required String body,
  }) async {
    final ids = recipients(userUuids.join('\n'));
    final heading = title.trim();
    final content = body.trim();

    if (!types.containsKey(type) ||
        heading.isEmpty ||
        heading.runes.length > 255 ||
        content.isEmpty) {
      throw const ApiException(
        'Select a type and enter a title of up to 255 characters '
        'and a message.',
      );
    }

    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/notifications/send/',
        data: {
          'recipient_user_uuids': ids,
          'notification_type': type,
          'title': heading,
          'body': content,
        },
      );

      final envelope = response.data;
      final value = envelope?['data'];

      if (envelope == null ||
          envelope['success'] != true ||
          value is! Map ||
          value['recipient_count'] is! int ||
          value['recipient_count'] != ids.length ||
          value['invalid_user_uuids'] is! List ||
          (value['invalid_user_uuids'] as List).isNotEmpty) {
        throw const NotificationDeliveryUnknown();
      }

      return value['recipient_count'] as int;
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      if (status == null || status >= 500 || status == 408) {
        throw const NotificationDeliveryUnknown();
      }

      throw ApiException.fromDioException(e);
    }
  }
}

final notificationSendRepositoryProvider =
    Provider<NotificationSendRepository>(
  (ref) => NotificationSendRepository(ref.watch(dioProvider)),
);
