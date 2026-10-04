import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_urls.dart';
import '../../../core/network/dio_provider.dart';
import '../../courses/data/course.dart';
import '../../students/data/student.dart';
import '../../subjects/data/chapter.dart';
import '../../subjects/data/subject.dart';

class ChapterVideoAccessResult {
  const ChapterVideoAccessResult({
    required this.courseName,
    required this.studentsCount,
    required this.chaptersCount,
    required this.createdCount,
    required this.renewedCount,
    required this.students,
    required this.chapters,
    this.startsAt,
    this.endsAt,
  });

  final String courseName;
  final int studentsCount;
  final int chaptersCount;
  final int createdCount;
  final int renewedCount;
  final List<String> students;
  final List<String> chapters;
  final DateTime? startsAt;
  final DateTime? endsAt;

  factory ChapterVideoAccessResult.fromJson(
    Map<String, dynamic> json,
  ) =>
      ChapterVideoAccessResult(
        courseName: json['course_name'].toString(),
        studentsCount:
            (json['selected_students_count'] as num).toInt(),
        chaptersCount:
            (json['selected_chapters_count'] as num).toInt(),
        createdCount:
            (json['created_permissions_count'] as num).toInt(),
        renewedCount:
            (json['renewed_permissions_count'] as num).toInt(),
        startsAt: DateTime.tryParse(
          json['access_start_at']?.toString() ?? '',
        ),
        endsAt: DateTime.tryParse(
          json['access_end_at']?.toString() ?? '',
        ),
        students: (json['students'] as List).map((value) {
          final item = Map<String, dynamic>.from(value as Map);
          return '${item['student_name']} '
              '(${item['admission_number']})';
        }).toList(),
        chapters: (json['chapters'] as List).map((value) {
          final item = Map<String, dynamic>.from(value as Map);
          return '${item['subject_name']} — '
              '${item['chapter_title']}';
        }).toList(),
      );
}

class ChapterVideoAccessRepository {
  ChapterVideoAccessRepository(this.dio);

  final Dio dio;

  Future<T> request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Map<String, dynamic> data(Map<String, dynamic>? body) {
    if (body == null || body['success'] == false) {
      throw const FormatException('Invalid access response.');
    }

    final value = body['data'] ?? body;
    if (value is! Map) {
      throw const FormatException('Expected an object response.');
    }

    return Map<String, dynamic>.from(value);
  }

  Future<List<Map<String, dynamic>>> all(
    String path, {
    Map<String, dynamic> filters = const {},
  }) =>
      request(() async {
        final rows = <Map<String, dynamic>>[];

        for (var page = 1; ; page++) {
          final response = await dio.get<Map<String, dynamic>>(
            path,
            queryParameters: {
              ...filters,
              'page': page,
              'page_size': 20,
            },
          );

          final body = data(response.data);
          final results = body['results'];
          final count = body['count'];

          if (results is! List || count is! num || count < 0) {
            throw const FormatException(
              'Invalid paginated response.',
            );
          }

          rows.addAll(
            results.map(
              (item) => Map<String, dynamic>.from(item as Map),
            ),
          );

          if (page * 20 >= count) break;
        }

        return rows;
      });

  Future<List<Course>> courses() async {
    final items =
        (await all(ApiUrls.courses)).map(Course.fromJson);

    return {
      for (final item in items)
        if (item.isActive) item.uuid: item,
    }.values.toList();
  }

  Future<List<Student>> students() async {
    final items =
        (await all(ApiUrls.students)).map(Student.fromJson);

    return {
      for (final item in items)
        if (item.isActive) item.uuid: item,
    }.values.toList();
  }

  Future<List<Chapter>> chapters(
    String courseUuid, {
    bool Function()? stillCurrent,
  }) async {
    final raw = await all(
      ApiUrls.subjects,
      filters: {'course_uuid': courseUuid},
    );

    final subjects = {
      for (final row in raw)
        Subject.fromJson(row).uuid: Subject.fromJson(row),
    };

    final chapters = <String, Chapter>{};

    for (final subject in subjects.values) {
      if (stillCurrent != null && !stillCurrent()) return [];

      final rows = await all(
        ApiUrls.chapters,
        filters: {'subject_uuid': subject.uuid},
      );

      if (stillCurrent != null && !stillCurrent()) return [];

      for (final row in rows) {
        final chapter = Chapter.fromJson(row);
        if (chapter.isActive) {
          chapters[chapter.uuid] = chapter;
        }
      }
    }

    return chapters.values.toList()
      ..sort((a, b) {
        final subject =
            a.subjectName.compareTo(b.subjectName);
        return subject == 0
            ? a.sequence.compareTo(b.sequence)
            : subject;
      });
  }

  Future<ChapterVideoAccessResult> grant({
    required String courseUuid,
    required Set<String> studentUuids,
    required Set<String> chapterUuids,
    DateTime? startsAt,
    DateTime? endsAt,
  }) =>
      request(() async {
        if (studentUuids.isEmpty ||
            studentUuids.length > 500 ||
            chapterUuids.isEmpty ||
            chapterUuids.length > 100) {
          throw const ApiException(
            'Select 1–500 students and 1–100 chapters.',
          );
        }

        final response = await dio.post<Map<String, dynamic>>(
          '/enrollments/chapter-video-access/bulk-grant/',
          data: {
            'course_uuid': courseUuid,
            'student_uuids': studentUuids.toList(),
            'chapter_uuids': chapterUuids.toList(),
            if (startsAt != null)
              'access_start_at':
                  startsAt.toUtc().toIso8601String(),
            if (endsAt != null)
              'access_end_at':
                  endsAt.toUtc().toIso8601String(),
          },
        );

        return ChapterVideoAccessResult.fromJson(
          data(response.data),
        );
      });
}

final chapterVideoAccessRepositoryProvider =
    Provider<ChapterVideoAccessRepository>(
  (ref) => ChapterVideoAccessRepository(
    ref.watch(dioProvider),
  ),
);
