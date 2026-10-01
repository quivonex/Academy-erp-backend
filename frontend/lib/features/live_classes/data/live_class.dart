class LiveClass {
  const LiveClass({
    required this.uuid,
    required this.courseName,
    required this.teacherName,
    required this.title,
    required this.description,
    required this.status,
    required this.isActive,
    this.subjectName,
    this.chapterUuid,
    this.lessonUuid,
    this.scheduledStartAt,
    this.scheduledEndAt,
    this.actualStartAt,
    this.actualEndAt,
    this.meetingUrl,
    this.meetingId,
    this.meetingPassword,
  });

  final String uuid;

  final String courseName;

  final String? subjectName;

  final String? chapterUuid;

  final String? lessonUuid;

  final String teacherName;

  final String title;

  final String description;

  final DateTime? scheduledStartAt;

  final DateTime? scheduledEndAt;

  final DateTime? actualStartAt;

  final DateTime? actualEndAt;

  final String? meetingUrl;

  final String? meetingId;

  final String? meetingPassword;

  final String status;

  final bool isActive;

  factory LiveClass.fromJson(
    Map<String, dynamic> json,
  ) {
    return LiveClass(
      uuid: json['uuid']?.toString() ?? '',
      courseName: json['course_name']?.toString() ?? '',
      subjectName: json['subject_name']?.toString(),
      chapterUuid: json['chapter_uuid']?.toString(),
      lessonUuid: json['lesson_uuid']?.toString(),
      teacherName: json['teacher_name']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      scheduledStartAt: _parseDate(
        json['scheduled_start_at'],
      ),
      scheduledEndAt: _parseDate(
        json['scheduled_end_at'],
      ),
      actualStartAt: _parseDate(
        json['actual_start_at'],
      ),
      actualEndAt: _parseDate(
        json['actual_end_at'],
      ),
      meetingUrl: json['meeting_url']?.toString(),
      meetingId: json['meeting_id']?.toString(),
      meetingPassword: json['meeting_password']?.toString(),
      status: json['status']?.toString() ?? 'SCHEDULED',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class LiveClassPage {
  const LiveClassPage({
    required this.count,
    required this.results,
  });

  final int count;

  final List<LiveClass> results;

  factory LiveClassPage.fromJson(
    Map<String, dynamic> json,
  ) {
    final list = json['results'] as List<dynamic>? ?? [];

    return LiveClassPage(
      count: json['count'] as int? ?? list.length,
      results: list
          .map(
            (item) => LiveClass.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) {
    return null;
  }

  return DateTime.tryParse(
    value.toString(),
  );
}
