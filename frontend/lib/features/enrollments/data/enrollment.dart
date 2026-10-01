class Enrollment {
  const Enrollment({
    required this.uuid,
    required this.studentName,
    required this.admissionNumber,
    required this.courseName,
    required this.courseCode,
    required this.status,
    this.enrolledAt,
    this.accessStartAt,
    this.accessEndAt,
    this.createdAt,
    this.updatedAt,
  });

  final String uuid;
  final String studentName;
  final String admissionNumber;
  final String courseName;
  final String courseCode;
  final String status;

  final DateTime? enrolledAt;
  final DateTime? accessStartAt;
  final DateTime? accessEndAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Enrollment.fromJson(Map<String, dynamic> json) {
    final student = json['student'];
    final studentName = json['student_name']?.toString() ??
        (student is Map
            ? (student['full_name'] ??
                    '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}')
                .toString()
                .trim()
            : null) ??
        '';

    final admissionNumber = json['admission_number']?.toString() ??
        (student is Map ? student['admission_number']?.toString() : null) ??
        '';

    final course = json['course'];
    final courseName = json['course_name']?.toString() ??
        (course is Map ? course['name']?.toString() : null) ??
        '';

    final courseCode = json['course_code']?.toString() ??
        (course is Map ? course['code']?.toString() : null) ??
        '';

    return Enrollment(
      uuid: json['uuid']?.toString() ?? json['id']?.toString() ?? '',
      studentName: studentName.isNotEmpty ? studentName : 'Student',
      admissionNumber: admissionNumber,
      courseName: courseName.isNotEmpty ? courseName : 'Course',
      courseCode: courseCode,
      status: json['status']?.toString() ?? 'ACTIVE',
      enrolledAt: _parseDate(json['enrolled_at']),
      accessStartAt: _parseDate(json['access_start_at']),
      accessEndAt: _parseDate(json['access_end_at']),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }
}

class EnrollmentPage {
  const EnrollmentPage({
    required this.count,
    required this.results,
  });

  final int count;
  final List<Enrollment> results;

  factory EnrollmentPage.fromJson(Map<String, dynamic> json) {
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

    return EnrollmentPage(
      count: count,
      results: list
          .map((item) => Enrollment.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}
