import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_urls.dart';
import '../../../core/network/dio_provider.dart';

import 'assignment.dart';
import 'assignment_question.dart';
import 'assignment_submission.dart';

class AssignmentRepository {
  AssignmentRepository(this._dio);

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

  Future<AssignmentPage> list({
    String search = '',
    String? courseUuid,
    int page = 1,
  }) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.assignments,
          queryParameters: {
            'page': page,
            'page_size': 20,
            if (search.trim().isNotEmpty) 'search': search.trim(),
            if (courseUuid != null && courseUuid.isNotEmpty)
              'course_uuid': courseUuid,
          },
        );

        return AssignmentPage.fromJson(
          response.data ?? {},
        );
      });

  Future<Assignment> detail(
    String uuid,
  ) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.adminAssignmentDetail(uuid),
        );

        final resData = response.data?['data'] ?? response.data ?? {};
        return Assignment.fromJson(
          Map<String, dynamic>.from(resData as Map),
        );
      });

  Future<Assignment> create({
    required String courseUuid,
    required String title,
    String description = '',
    String instructions = '',
    double maxMarks = 0,
    DateTime? dueAt,
    bool allowLateSubmission = false,
    String? subjectUuid,
    String? chapterUuid,
    String? lessonUuid,
  }) =>
      _request(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          ApiUrls.assignments,
          data: {
            'course_uuid': courseUuid,
            if (subjectUuid != null && subjectUuid.isNotEmpty)
              'subject_uuid': subjectUuid,
            if (chapterUuid != null && chapterUuid.isNotEmpty)
              'chapter_uuid': chapterUuid,
            if (lessonUuid != null && lessonUuid.isNotEmpty)
              'lesson_uuid': lessonUuid,
            'title': title.trim(),
            'description': description.trim(),
            'instructions': instructions.trim(),
            'max_marks': maxMarks,
            if (dueAt != null) 'due_at': dueAt.toUtc().toIso8601String(),
            'allow_late_submission': allowLateSubmission,
          },
        );

        final resData = response.data?['data'] ?? response.data ?? {};
        return Assignment.fromJson(
          Map<String, dynamic>.from(resData as Map),
        );
      });

  Future<Assignment> publish(
    String uuid,
  ) =>
      _request(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          ApiUrls.assignmentPublish(uuid),
        );

        final resData = response.data?['data'] ?? response.data ?? {};
        return Assignment.fromJson(
          Map<String, dynamic>.from(resData as Map),
        );
      });

  Future<Assignment> unpublish(
    String uuid,
  ) =>
      _request(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          ApiUrls.assignmentUnpublish(uuid),
        );

        final resData = response.data?['data'] ?? response.data ?? {};
        return Assignment.fromJson(
          Map<String, dynamic>.from(resData as Map),
        );
      });

  Future<List<AssignmentQuestion>> questions(
    String assignmentUuid,
  ) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.assignmentQuestions(
            assignmentUuid,
          ),
        );

        final resData = response.data?['data'] ?? response.data;
        final data = (resData is List) ? resData : (resData?['results'] as List<dynamic>? ?? []);

        return data
            .map(
              (item) => AssignmentQuestion.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      });

  Future<AssignmentQuestion> createQuestion({
    required String assignmentUuid,
    required String questionText,
    required String answerType,
    required double marks,
    required int sequence,
    required bool isRequired,
    String answerText = '',
    String optionA = '',
    String optionB = '',
    String optionC = '',
    String optionD = '',
    String correctOption = '',
  }) =>
      _request(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          ApiUrls.assignmentQuestions(
            assignmentUuid,
          ),
          data: {
            'question_text': questionText.trim(),
            'answer_type': answerType,
            'marks': marks,
            'sequence': sequence,
            'is_required': isRequired,
            'answer_text': answerText.trim(),
            'option_a': optionA.trim(),
            'option_b': optionB.trim(),
            'option_c': optionC.trim(),
            'option_d': optionD.trim(),
            'correct_option': correctOption.trim().toUpperCase(),
          },
        );

        final resData = response.data?['data'] ?? response.data ?? {};
        return AssignmentQuestion.fromJson(
          Map<String, dynamic>.from(resData as Map),
        );
      });

  Future<AssignmentQuestion> updateQuestion({
    required String assignmentUuid,
    required String questionUuid,
    required String questionText,
    required String answerType,
    required double marks,
    required int sequence,
    required bool isRequired,
    String answerText = '',
    String optionA = '',
    String optionB = '',
    String optionC = '',
    String optionD = '',
    String correctOption = '',
  }) =>
      _request(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          ApiUrls.assignmentQuestionDetail(
            assignmentUuid,
            questionUuid,
          ),
          data: {
            'question_text': questionText.trim(),
            'answer_type': answerType,
            'marks': marks,
            'sequence': sequence,
            'is_required': isRequired,
            'answer_text': answerText.trim(),
            'option_a': optionA.trim(),
            'option_b': optionB.trim(),
            'option_c': optionC.trim(),
            'option_d': optionD.trim(),
            'correct_option': correctOption.trim().toUpperCase(),
          },
        );

        final resData = response.data?['data'] ?? response.data ?? {};
        return AssignmentQuestion.fromJson(
          Map<String, dynamic>.from(resData as Map),
        );
      });

  Future<void> deleteQuestion({
    required String assignmentUuid,
    required String questionUuid,
  }) =>
      _request(() async {
        await _dio.delete(
          ApiUrls.assignmentQuestionDetail(
            assignmentUuid,
            questionUuid,
          ),
        );
      });

  Future<AssignmentSubmissionPage> submissions({
    required String assignmentUuid,
    String? status,
    int page = 1,
  }) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.assignmentSubmissions(
            assignmentUuid,
          ),
          queryParameters: {
            'page': page,
            'page_size': 20,
            if (status != null && status.isNotEmpty) 'status': status,
          },
        );

        return AssignmentSubmissionPage.fromJson(
          response.data ?? {},
        );
      });

  Future<AssignmentSubmissionReview> submissionDetail(
    String submissionUuid,
  ) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.assignmentSubmissionDetail(
            submissionUuid,
          ),
        );

        final resData = response.data?['data'] ?? response.data ?? {};
        return AssignmentSubmissionReview.fromJson(
          Map<String, dynamic>.from(resData as Map),
        );
      });

  Future<AssignmentSubmissionReview> gradeSubmission({
    required String submissionUuid,
    required String feedback,
    required List<Map<String, dynamic>> answers,
  }) =>
      _request(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          ApiUrls.assignmentSubmissionGrade(
            submissionUuid,
          ),
          data: {
            'feedback': feedback.trim(),
            'answers': answers,
          },
        );

        final resData = response.data?['data'] ?? response.data ?? {};
        return AssignmentSubmissionReview.fromJson(
          Map<String, dynamic>.from(resData as Map),
        );
      });

  Future<Map<String, dynamic>> importPdf({
    required String courseUuid,
    required String title,
    required Uint8List pdfBytes,
    required String pdfFileName,
    String description = '',
    String instructions = '',
    String? subjectUuid,
    String? chapterUuid,
    String? lessonUuid,
  }) =>
      _request(() async {
        final formData = FormData.fromMap({
          'course_uuid': courseUuid,
          'title': title.trim(),
          'description': description.trim(),
          'instructions': instructions.trim(),
          if (subjectUuid != null) 'subject_uuid': subjectUuid,
          if (chapterUuid != null) 'chapter_uuid': chapterUuid,
          if (lessonUuid != null) 'lesson_uuid': lessonUuid,
          'pdf': MultipartFile.fromBytes(
            pdfBytes,
            filename: pdfFileName,
          ),
        });

        final response = await _dio.post<Map<String, dynamic>>(
          ApiUrls.assignmentPdfImport,
          data: formData,
        );

        final resData = response.data?['data'] ?? response.data ?? {};
        return Map<String, dynamic>.from(resData as Map);
      });
}

final assignmentRepositoryProvider = Provider<AssignmentRepository>((ref) {
  return AssignmentRepository(
    ref.watch(dioProvider),
  );
});
