class LiveClass {
  const LiveClass({
    required this.uuid,
    required this.courseName,
    required this.title,
    required this.description,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.status,
    required this.isActive,
    this.subjectName,
    this.teacherName,
    this.meetingUrl,
    this.meetingId,
    this.meetingPassword,
  });

  final String uuid;

  final String courseName;
  final String? subjectName;
  final String? teacherName;

  final String title;
  final String description;

  final DateTime scheduledAt;
  final int durationMinutes;

  final String? meetingUrl;
  final String? meetingId;
  final String? meetingPassword;

  final String status;
  final bool isActive;

  factory LiveClass.fromJson(
    Map<String, dynamic> json,
  ) {
    final course = json['course'];
    final courseName = json['course_name']?.toString() ??
        (course is Map ? course['name']?.toString() : null) ??
        '';

    final subject = json['subject'];
    final subjectName = json['subject_name']?.toString() ??
        (subject is Map ? subject['name']?.toString() : null);

    final teacher = json['teacher'];
    final teacherName = json['teacher_name']?.toString() ??
        (teacher is Map
            ? (teacher['full_name'] ??
                    '${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}')
                .toString()
                .trim()
            : null);

    return LiveClass(
      uuid: json['uuid']?.toString() ?? '',
      courseName: courseName,
      subjectName: subjectName,
      teacherName: teacherName,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      scheduledAt: _parseDate(json['scheduled_at']) ?? DateTime.now(),
      durationMinutes: int.tryParse(
            json['duration_minutes']?.toString() ?? '60',
          ) ??
          60,
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
    Map<String, dynamic> data = json;
    if (json['data'] is Map<String, dynamic>) {
      data = json['data'] as Map<String, dynamic>;
    } else if (json['data'] is Map) {
      data = Map<String, dynamic>.from(json['data'] as Map);
    }

    List<dynamic> list = [];
    if (data['results'] is List) {
      list = data['results'] as List<dynamic>;
    } else if (json['results'] is List) {
      list = json['results'] as List<dynamic>;
    } else if (json['data'] is List) {
      list = json['data'] as List<dynamic>;
    }

    final count = (data['count'] as num?)?.toInt() ??
        (json['count'] as num?)?.toInt() ??
        list.length;

    return LiveClassPage(
      count: count,
      results: list
          .map(
            (item) => LiveClass.fromJson(
              Map<String, dynamic>.from(item as Map),
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
