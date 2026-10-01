class Subject {
  const Subject({
    required this.uuid,
    required this.courseName,
    required this.name,
    required this.code,
    required this.description,
    required this.isActive,
    this.teacherName,
  });

  final String uuid;
  final String courseName;
  final String? teacherName;

  final String name;
  final String code;
  final String description;

  final bool isActive;

  factory Subject.fromJson(Map<String, dynamic> json) {
    final course = json['course'];
    final courseName = json['course_name']?.toString() ??
        (course is Map ? course['name']?.toString() : null) ?? '';

    final teacher = json['teacher'];
    final teacherName = json['teacher_name']?.toString() ??
        (teacher is Map
            ? (teacher['full_name'] ??
                    '${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}')
                .toString()
                .trim()
            : null);

    return Subject(
      uuid: json['uuid']?.toString() ?? json['id']?.toString() ?? '',
      courseName: courseName,
      teacherName: teacherName,
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class SubjectPage {
  const SubjectPage({
    required this.count,
    required this.results,
  });

  final int count;
  final List<Subject> results;

  factory SubjectPage.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> data = json;
    if (json['data'] is Map<String, dynamic>) {
      data = json['data'] as Map<String, dynamic>;
    }

    List<dynamic> list = [];
    if (data['results'] is List) {
      list = data['results'] as List<dynamic>;
    } else if (json['results'] is List) {
      list = json['results'] as List<dynamic>;
    } else if (json['data'] is List) {
      list = json['data'] as List<dynamic>;
    }

    final count = data['count'] as int? ?? json['count'] as int? ?? list.length;

    return SubjectPage(
      count: count,
      results: list
          .map((item) => Subject.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}
