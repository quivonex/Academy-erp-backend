/// Mirrors app.schemas.academic.BatchOut — reused here for the batch picker.
class BatchSummary {
  const BatchSummary({required this.id, required this.name, required this.capacity});
  final int id;
  final String name;
  final int capacity;

  factory BatchSummary.fromJson(Map<String, dynamic> json) => BatchSummary(
        id: json['id'] as int,
        name: json['name'] as String,
        capacity: json['capacity'] as int? ?? 0,
      );
}

/// One row in the attendance sheet: a student + their status for today.
class AttendanceMark {
  AttendanceMark({required this.studentId, required this.studentName, this.status = 'present'});
  final int studentId;
  final String studentName;
  String status; // present | absent | late | excused

  Map<String, dynamic> toJson() => {'student_id': studentId, 'status': status};
}
