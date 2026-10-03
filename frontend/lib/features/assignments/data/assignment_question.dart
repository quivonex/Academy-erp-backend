class AssignmentQuestion {
  const AssignmentQuestion({
    required this.uuid,
    required this.questionText,
    required this.answerType,
    required this.marks,
    required this.sequence,
    required this.isRequired,
    required this.answerText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
  });

  final String uuid;
  final String questionText;
  final String answerType;
  final double marks;
  final int sequence;
  final bool isRequired;

  final String answerText;

  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;

  final String correctOption;

  factory AssignmentQuestion.fromJson(
    Map<String, dynamic> json,
  ) {
    return AssignmentQuestion(
      uuid: json['uuid']?.toString() ?? '',
      questionText: json['question_text']?.toString() ?? '',
      answerType: json['answer_type']?.toString() ?? 'TEXT',
      marks: double.tryParse(
            json['marks']?.toString() ?? '0',
          ) ??
          0,
      sequence: int.tryParse(
            json['sequence']?.toString() ?? '1',
          ) ??
          1,
      isRequired: json['is_required'] as bool? ?? true,
      answerText: json['answer_text']?.toString() ?? '',
      optionA: json['option_a']?.toString() ?? '',
      optionB: json['option_b']?.toString() ?? '',
      optionC: json['option_c']?.toString() ?? '',
      optionD: json['option_d']?.toString() ?? '',
      correctOption: json['correct_option']?.toString() ?? '',
    );
  }
}
