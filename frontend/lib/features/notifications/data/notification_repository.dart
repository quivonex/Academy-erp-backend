import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';

class InboxNotification {
  const InboxNotification({
    required this.uuid,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    this.createdAt,
    this.readAt,
  });

  final String uuid;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime? createdAt;
  final DateTime? readAt;

  factory InboxNotification.fromJson(Map<String, dynamic> json) {
    if (json['uuid'] is! String ||
        (json['uuid'] as String).isEmpty ||
        json['is_read'] is! bool) {
      throw const FormatException('Invalid notification response.');
    }

    return InboxNotification(
      uuid: json['uuid'] as String,
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: json['notification_type']?.toString() ?? 'GENERAL',
      isRead: json['is_read'] as bool,
      createdAt: DateTime.tryParse(
        json['created_at']?.toString() ?? '',
      ),
      readAt: DateTime.tryParse(
        json['read_at']?.toString() ?? '',
      ),
    );
  }
}

class NotificationPage {
  const NotificationPage(this.items, this.count, this.page);

  final List<InboxNotification> items;
  final int count;
  final int page;
}

class NotificationRepository {
  NotificationRepository(this.dio);

  final Dio dio;
  static const path = '/notifications/';

  Future<T> request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Map<String, dynamic> data(Map<String, dynamic>? body) {
    if (body == null || body['success'] == false) {
      throw const FormatException('Invalid notification response.');
    }

    final value = body['data'] ?? body;

    if (value is! Map) {
      throw const FormatException('Expected an object response.');
    }

    return Map<String, dynamic>.from(value);
  }

  int count(dynamic value) {
    if (value is! int || value < 0) {
      throw const FormatException('Invalid notification count.');
    }
    return value;
  }

  Future<NotificationPage> list({
    required int page,
    bool unread = false,
    String? type,
  }) =>
      request(() async {
        Future<Response<Map<String, dynamic>>> fetch(int value) =>
            dio.get<Map<String, dynamic>>(
              path,
              queryParameters: {
                'page': value,
                'page_size': 20,
                if (unread) 'unread': 'true',
                if (type != null) 'notification_type': type,
              },
            );

        var actualPage = page;
        late Response<Map<String, dynamic>> response;

        try {
          response = await fetch(actualPage);
        } on DioException catch (e) {
          if (actualPage <= 1 || e.response?.statusCode != 404) {
            rethrow;
          }

          actualPage = 1;
          response = await fetch(actualPage);
        }

        final body = data(response.data);

        if (body['results'] is! List) {
          throw const FormatException('Invalid notification list.');
        }

        return NotificationPage(
          (body['results'] as List)
              .map(
                (item) => InboxNotification.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList(),
          count(body['count']),
          actualPage,
        );
      });

  Future<int> unreadCount() => request(() async {
        final response = await dio.get<Map<String, dynamic>>(
          '${path}unread-count/',
        );

        return count(data(response.data)['unread_count']);
      });

  Future<void> markRead(String uuid) => request(() async {
        final response = await dio.patch<Map<String, dynamic>>(
          '${path}$uuid/read/',
        );

        InboxNotification.fromJson(data(response.data));
      });

  Future<int> markAllRead() => request(() async {
        final response = await dio.post<Map<String, dynamic>>(
          '${path}mark-all-read/',
        );

        return count(data(response.data)['updated_count']);
      });
}

final notificationRepositoryProvider =
    Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(dioProvider)),
);
