/// Lightweight Course model for enrollment pickers.
class CourseOption {
  const CourseOption({required this.uuid, required this.name, this.category});
  final String uuid;
  final String name;
  final String? category;

  factory CourseOption.fromJson(Map<String, dynamic> json) => CourseOption(
        uuid: json['uuid'] as String,
        name: json['name'] as String,
        category: json['category_name'] as String?,
      );
}

/// Mirrors the backend EnrollmentSerializer response.
class EnrollmentRecord {
  const EnrollmentRecord({
    required this.uuid,
    required this.studentUuid,
    required this.courseUuid,
    required this.status,
    this.startDate,
    this.endDate,
    this.studentName,
    this.courseName,
  });

  final String uuid;
  final String studentUuid;
  final String courseUuid;
  final String status;
  final String? startDate;
  final String? endDate;
  final String? studentName;
  final String? courseName;

  factory EnrollmentRecord.fromJson(Map<String, dynamic> json) =>
      EnrollmentRecord(
        uuid: json['uuid'] as String,
        studentUuid: json['student_uuid'] as String,
        courseUuid: json['course_uuid'] as String,
        status: json['status'] as String,
        startDate: json['start_date'] as String?,
        endDate: json['end_date'] as String?,
        studentName: json['student_name'] as String?,
        courseName: json['course_name'] as String?,
      );
}
