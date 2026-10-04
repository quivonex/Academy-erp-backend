import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';

class AssignmentFileUploadRepository {
  AssignmentFileUploadRepository(this.dio);

  final Dio dio;

  Future<String> upload({
    required String assignmentUuid,
    required String questionUuid,
    required String fileName,
    required Uint8List bytes,
    ProgressCallback? onProgress,
  }) async {
    if (bytes.isEmpty || bytes.length > 25 * 1024 * 1024) {
      throw const ApiException(
        'Choose a non-empty file up to 25 MB.',
      );
    }

    final extension = fileName.split('.').last.toLowerCase();

    if (![
      'pdf',
      'doc',
      'docx',
      'jpg',
      'jpeg',
      'png',
    ].contains(extension)) {
      throw const ApiException(
        'Use PDF, DOC, DOCX, JPG, JPEG or PNG.',
      );
    }

    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/student/assignments/$assignmentUuid/file-upload/',
        data: FormData.fromMap({
          'question_uuid': questionUuid,
          'file': MultipartFile.fromBytes(
            bytes,
            filename: fileName,
          ),
        }),
        onSendProgress: onProgress,
      );

      final body = response.data;
      final data = body?['data'];

      if (body?['success'] != true ||
          data is! Map ||
          data['assignment_uuid'] != assignmentUuid ||
          data['question_uuid'] != questionUuid ||
          data['file_key'] is! String ||
          (data['file_key'] as String).trim().isEmpty) {
        throw const ApiException(
          'Could not confirm the upload. Please upload again.',
        );
      }

      return data['file_key'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final assignmentFileUploadRepositoryProvider =
    Provider<AssignmentFileUploadRepository>(
  (ref) => AssignmentFileUploadRepository(
    ref.watch(dioProvider),
  ),
);
