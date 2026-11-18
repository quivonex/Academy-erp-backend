/// One row in the attendance sheet: a student + their status for today.
class AttendanceMark {
  AttendanceMark({required this.studentUuid, required this.studentName, this.status = 'present'});
  final String studentUuid;
  final String studentName;
  String status; // present | absent | late | excused

  Map<String, dynamic> toJson() => {'student_uuid': studentUuid, 'status': status};
}
