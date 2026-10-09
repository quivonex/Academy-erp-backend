import 'package:dio/dio.dart';

/// Normalizes Dio errors into something the presentation layer can show
/// directly, e.g. in an inline form error or a SnackBar.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiException.fromDioException(DioException e) {
    final response = e.response;
    if (response != null) {
      final data = response.data;
      String detail;
      if (data is Map && data['message'] != null) {
        detail = data['message'].toString();
        if (data['errors'] is Map && (data['errors'] as Map).isNotEmpty) {
          final first = (data['errors'] as Map).values.first;
          if (first is List && first.isNotEmpty) detail = first.first.toString();
        }
      } else if (data is Map && data['detail'] != null) {
        detail = data['detail'].toString();
      } else {
        detail = response.statusMessage ?? 'Request failed';
      }
      return ApiException(detail, statusCode: response.statusCode);
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException('The request timed out. Check your connection and try again.');
      case DioExceptionType.connectionError:
        return const ApiException('Could not reach the EduSphere server.');
      default:
        return ApiException(e.message ?? 'Something went wrong.');
    }
  }

  @override
  String toString() => message;
}
