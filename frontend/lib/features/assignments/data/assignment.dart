class Assignment {
  const Assignment({
    required this.uuid,
    required this.courseName,
    required this.title,
    required this.description,
    required this.instructions,
    required this.maxMarks,
    required this.allowLateSubmission,
    required this.isPublished,
    required this.isActive,
    this.subjectName,
    this.chapterTitle,
    this.lessonTitle,
    this.createdByName,
    this.dueAt,
  });

  final String uuid;
  final String courseName;
  final String? subjectName;
  final String? chapterTitle;
  final String? lessonTitle;
  final String title;
  final String description;
  final String instructions;
  final double maxMarks;
  final DateTime? dueAt;
  final bool allowLateSubmission;
  final bool isPublished;
  final bool isActive;
  final String? createdByName;

  factory Assignment.fromJson(Map<String, dynamic> json) {
    final course = json['course'];
    final courseName = json['course_name']?.toString() ??
        (course is Map ? course['name']?.toString() : null) ?? '';

    return Assignment(
      uuid: json['uuid']?.toString() ?? json['id']?.toString() ?? '',
      courseName: courseName.isNotEmpty ? courseName : 'Course',
      subjectName: json['subject_name']?.toString(),
      chapterTitle: json['chapter_title']?.toString(),
      lessonTitle: json['lesson_title']?.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      instructions: json['instructions']?.toString() ?? '',
      maxMarks: double.tryParse(json['max_marks']?.toString() ?? '0') ?? 0,
      dueAt: json['due_at'] == null
          ? null
          : DateTime.tryParse(json['due_at'].toString()),
      allowLateSubmission: json['allow_late_submission'] as bool? ?? false,
      isPublished: json['is_published'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      createdByName: json['created_by_name']?.toString(),
    );
  }
}

class AssignmentPage {
  const AssignmentPage({
    required this.count,
    required this.results,
  });

  final int count;
  final List<Assignment> results;

  factory AssignmentPage.fromJson(Map<String, dynamic> json) {
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

    return AssignmentPage(
      count: count,
      results: list
          .map((item) => Assignment.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}
