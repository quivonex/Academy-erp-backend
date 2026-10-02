class CoursePayment {
  const CoursePayment({
    required this.uuid,
    required this.courseUuid,
    required this.courseName,
    required this.courseCode,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.utrNumber,
    required this.studentNote,
    required this.adminNote,
    this.createdAt,
    this.reviewedAt,
  });

  final String uuid;

  final String courseUuid;
  final String courseName;
  final String courseCode;

  final String amount;
  final String paymentMethod;
  final String status;

  final String utrNumber;
  final String studentNote;
  final String adminNote;

  final DateTime? createdAt;
  final DateTime? reviewedAt;

  factory CoursePayment.fromJson(
    Map<String, dynamic> json,
  ) {
    return CoursePayment(
      uuid: json['uuid']?.toString() ?? '',
      courseUuid: json['course_uuid']?.toString() ?? '',
      courseName: json['course_name']?.toString() ?? '',
      courseCode: json['course_code']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0.00',
      paymentMethod: json['payment_method']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      utrNumber: json['utr_number']?.toString() ?? '',
      studentNote: json['student_note']?.toString() ?? '',
      adminNote: json['admin_note']?.toString() ?? '',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(
              json['created_at'].toString(),
            ),
      reviewedAt: json['reviewed_at'] == null
          ? null
          : DateTime.tryParse(
              json['reviewed_at'].toString(),
            ),
    );
  }
}
