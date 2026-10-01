class AssignmentSubmission {
  const AssignmentSubmission({
    required this.uuid,
    required this.studentName,
    required this.admissionNumber,
    required this.status,
    this.totalMarksObtained,
    this.submittedAt,
    this.gradedAt,
  });

  final String uuid;
  final String studentName;
  final String admissionNumber;
  final String status;

  final double? totalMarksObtained;

  final DateTime? submittedAt;
  final DateTime? gradedAt;

  factory AssignmentSubmission.fromJson(
    Map<String, dynamic> json,
  ) {
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

    return AssignmentSubmission(
      uuid: json['uuid']?.toString() ?? json['id']?.toString() ?? '',
      studentName: studentName.isNotEmpty ? studentName : 'Student',
      admissionNumber: admissionNumber,
      status: json['status']?.toString() ?? '',
      totalMarksObtained: double.tryParse(
        json['total_marks_obtained']?.toString() ?? '',
      ),
      submittedAt: _date(
        json['submitted_at'],
      ),
      gradedAt: _date(
        json['graded_at'],
      ),
    );
  }
}

class AssignmentSubmissionPage {
  const AssignmentSubmissionPage({
    required this.count,
    required this.results,
  });

  final int count;

  final List<AssignmentSubmission> results;

  factory AssignmentSubmissionPage.fromJson(
    Map<String, dynamic> json,
  ) {
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

    return AssignmentSubmissionPage(
      count: count,
      results: list
          .map((item) => AssignmentSubmission.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}

class SubmissionAnswer {
  const SubmissionAnswer({
    required this.uuid,
    required this.questionText,
    required this.answerType,
    required this.maxMarks,
    required this.textAnswer,
    required this.fileKey,
    required this.selectedOption,
    required this.feedback,
    this.marksObtained,
  });

  final String uuid;

  final String questionText;
  final String answerType;

  final double maxMarks;

  final String textAnswer;
  final String fileKey;
  final String selectedOption;

  final double? marksObtained;

  final String feedback;

  factory SubmissionAnswer.fromJson(
    Map<String, dynamic> json,
  ) {
    return SubmissionAnswer(
      uuid: json['uuid']?.toString() ?? '',
      questionText: json['question_text']?.toString() ?? '',
      answerType: json['answer_type']?.toString() ?? '',
      maxMarks: double.tryParse(
            json['max_marks']?.toString() ?? '0',
          ) ??
          0,
      textAnswer: json['text_answer']?.toString() ?? '',
      fileKey: json['file_key']?.toString() ?? '',
      selectedOption: json['selected_option']?.toString() ?? '',
      marksObtained: double.tryParse(
        json['marks_obtained']?.toString() ?? '',
      ),
      feedback: json['feedback']?.toString() ?? '',
    );
  }
}

class AssignmentSubmissionReview {
  const AssignmentSubmissionReview({
    required this.uuid,
    required this.assignmentTitle,
    required this.assignmentMaxMarks,
    required this.studentName,
    required this.admissionNumber,
    required this.status,
    required this.feedback,
    required this.answers,
    this.totalMarksObtained,
    this.submittedAt,
    this.gradedAt,
    this.gradedByName,
  });

  final String uuid;

  final String assignmentTitle;

  final double assignmentMaxMarks;

  final String studentName;
  final String admissionNumber;

  final String status;

  final double? totalMarksObtained;

  final String feedback;

  final DateTime? submittedAt;
  final DateTime? gradedAt;

  final String? gradedByName;

  final List<SubmissionAnswer> answers;

  factory AssignmentSubmissionReview.fromJson(
    Map<String, dynamic> json,
  ) {
    final answerList = json['answers'] as List<dynamic>? ?? [];

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

    return AssignmentSubmissionReview(
      uuid: json['uuid']?.toString() ?? json['id']?.toString() ?? '',
      assignmentTitle: json['assignment_title']?.toString() ?? '',
      assignmentMaxMarks: double.tryParse(
            json['assignment_max_marks']?.toString() ?? '0',
          ) ??
          0,
      studentName: studentName.isNotEmpty ? studentName : 'Student',
      admissionNumber: admissionNumber,
      status: json['status']?.toString() ?? '',
      totalMarksObtained: double.tryParse(
        json['total_marks_obtained']?.toString() ?? '',
      ),
      feedback: json['feedback']?.toString() ?? '',
      submittedAt: _date(json['submitted_at']),
      gradedAt: _date(json['graded_at']),
      gradedByName: json['graded_by_name']?.toString(),
      answers: answerList
          .map(
            (item) => SubmissionAnswer.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

DateTime? _date(dynamic value) {
  if (value == null) {
    return null;
  }

  return DateTime.tryParse(
    value.toString(),
  );
}
