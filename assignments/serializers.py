from rest_framework import serializers

from .models import (
    Assignment,
    AssignmentAnswer,
    AssignmentQuestion,
    AssignmentSubmission,
)
MAX_ASSIGNMENT_PDF_SIZE = 10 * 1024 * 1024

class AssignmentSerializer(serializers.ModelSerializer):
    course_uuid = serializers.UUIDField(
        write_only=True,
    )

    subject_uuid = serializers.UUIDField(
        write_only=True,
        required=False,
        allow_null=True,
    )

    chapter_uuid = serializers.UUIDField(
        write_only=True,
        required=False,
        allow_null=True,
    )

    lesson_uuid = serializers.UUIDField(
        write_only=True,
        required=False,
        allow_null=True,
    )

    course_name = serializers.CharField(
        source="course.name",
        read_only=True,
    )

    subject_name = serializers.CharField(
        source="subject.name",
        read_only=True,
        allow_null=True,
    )

    chapter_title = serializers.CharField(
        source="chapter.title",
        read_only=True,
        allow_null=True,
    )

    lesson_title = serializers.CharField(
        source="lesson.title",
        read_only=True,
        allow_null=True,
    )

    created_by_name = serializers.CharField(
        source="created_by.full_name",
        read_only=True,
        allow_null=True,
    )

    class Meta:
        model = Assignment

        fields = (
            "uuid",
            "course_uuid",
            "course_name",
            "subject_uuid",
            "subject_name",
            "chapter_uuid",
            "chapter_title",
            "lesson_uuid",
            "lesson_title",
            "title",
            "description",
            "instructions",
            "max_marks",
            "due_at",
            "allow_late_submission",
            "is_published",
            "is_active",
            "created_by_name",
            "created_at",
            "updated_at",
        )

        read_only_fields = (
            "uuid",
            "created_by_name",
            "created_at",
            "updated_at",
        )


class AssignmentQuestionSerializer(
    serializers.ModelSerializer
):
    class Meta:
        model = AssignmentQuestion

        fields = (
            "uuid",
            "question_text",
            "answer_type",
            "marks",
            "answer_text",
            "option_a",
            "option_b",
            "option_c",
            "option_d",
            "correct_option",
            "sequence",
            "is_required",
            "created_at",
        )

        read_only_fields = (
            "uuid",
            "created_at",
        )

    def validate(self, attrs):
        answer_type = attrs.get(
            "answer_type",
            AssignmentQuestion.AnswerType.TEXT,
        )

        if (
            answer_type
            == AssignmentQuestion.AnswerType.MCQ
        ):
            required_options = [
                "option_a",
                "option_b",
                "option_c",
                "option_d",
            ]

            errors = {}

            for field in required_options:
                if not attrs.get(field):
                    errors[field] = [
                        "This option is required for MCQ."
                    ]

            correct_option = attrs.get(
                "correct_option",
                "",
            ).upper()

            if correct_option not in [
                "A",
                "B",
                "C",
                "D",
            ]:
                errors["correct_option"] = [
                    "Use A, B, C, or D."
                ]

            if errors:
                raise serializers.ValidationError(
                    errors
                )

            attrs["correct_option"] = correct_option

        return attrs


class AssignmentPDFImportSerializer(
    serializers.Serializer
):
    course_uuid = serializers.UUIDField()

    subject_uuid = serializers.UUIDField(
        required=False,
        allow_null=True,
    )

    chapter_uuid = serializers.UUIDField(
        required=False,
        allow_null=True,
    )

    lesson_uuid = serializers.UUIDField(
        required=False,
        allow_null=True,
    )

    title = serializers.CharField(
        max_length=255,
    )

    description = serializers.CharField(
        required=False,
        allow_blank=True,
    )

    instructions = serializers.CharField(
        required=False,
        allow_blank=True,
    )

    pdf = serializers.FileField()

    def validate_pdf(self, value):
        if not value.name.lower().endswith(".pdf"):
            raise serializers.ValidationError(
                "Only PDF files are allowed."
            )
    
        if value.size > MAX_ASSIGNMENT_PDF_SIZE:
            raise serializers.ValidationError(
                "PDF size must not exceed 10 MB."
            )
    
        current_position = value.tell()
    
        value.seek(0)
        file_header = value.read(5)
        value.seek(current_position)
    
        if file_header != b"%PDF-":
            raise serializers.ValidationError(
                "Uploaded file is not a valid PDF."
            )
    
        return value

class StudentAssignmentQuestionSerializer(
    serializers.ModelSerializer
):
    class Meta:
        model = AssignmentQuestion

        fields = (
            "uuid",
            "question_text",
            "answer_type",
            "marks",
            "option_a",
            "option_b",
            "option_c",
            "option_d",
            "sequence",
            "is_required",
        )

        read_only_fields = fields


class StudentAssignmentAnswerSerializer(
    serializers.Serializer
):
    question_uuid = serializers.UUIDField()

    text_answer = serializers.CharField(
        required=False,
        allow_blank=True,
    )

    selected_option = serializers.CharField(
        required=False,
        allow_blank=True,
        max_length=1,
    )


class StudentAssignmentSubmitSerializer(
    serializers.Serializer
):
    answers = StudentAssignmentAnswerSerializer(
        many=True,
    )


class StudentAssignmentResultSerializer(
    serializers.Serializer
):
    total_questions = serializers.IntegerField()

    correct_answers = serializers.IntegerField()

    wrong_answers = serializers.IntegerField()

    marks_obtained = serializers.DecimalField(
        max_digits=8,
        decimal_places=2,
    )

    max_marks = serializers.DecimalField(
        max_digits=8,
        decimal_places=2,
    )

    percentage = serializers.DecimalField(
        max_digits=5,
        decimal_places=2,
    )

    status = serializers.CharField()


# =========================================================
# ADMIN / TEACHER - SUBMISSION REVIEW
# =========================================================


class AssignmentSubmissionListSerializer(
    serializers.ModelSerializer
):
    student_uuid = serializers.UUIDField(
        source="student.uuid",
        read_only=True,
    )

    student_name = serializers.CharField(
        source="student.full_name",
        read_only=True,
    )

    admission_number = serializers.CharField(
        source="student.admission_number",
        read_only=True,
    )

    class Meta:
        model = AssignmentSubmission

        fields = (
            "uuid",
            "student_uuid",
            "student_name",
            "admission_number",
            "status",
            "total_marks_obtained",
            "submitted_at",
            "graded_at",
            "created_at",
            "updated_at",
        )

        read_only_fields = fields


class AssignmentAnswerReviewSerializer(
    serializers.ModelSerializer
):
    question_uuid = serializers.UUIDField(
        source="question.uuid",
        read_only=True,
    )

    question_text = serializers.CharField(
        source="question.question_text",
        read_only=True,
    )

    answer_type = serializers.CharField(
        source="question.answer_type",
        read_only=True,
    )

    max_marks = serializers.DecimalField(
        source="question.marks",
        max_digits=8,
        decimal_places=2,
        read_only=True,
    )

    class Meta:
        model = AssignmentAnswer

        fields = (
            "uuid",
            "question_uuid",
            "question_text",
            "answer_type",
            "max_marks",
            "text_answer",
            "file_key",
            "selected_option",
            "marks_obtained",
            "feedback",
            "created_at",
            "updated_at",
        )

        read_only_fields = fields


class AssignmentSubmissionReviewSerializer(
    serializers.ModelSerializer
):
    assignment_uuid = serializers.UUIDField(
        source="assignment.uuid",
        read_only=True,
    )

    assignment_title = serializers.CharField(
        source="assignment.title",
        read_only=True,
    )

    assignment_max_marks = serializers.DecimalField(
        source="assignment.max_marks",
        max_digits=8,
        decimal_places=2,
        read_only=True,
    )

    student_uuid = serializers.UUIDField(
        source="student.uuid",
        read_only=True,
    )

    student_name = serializers.CharField(
        source="student.full_name",
        read_only=True,
    )

    admission_number = serializers.CharField(
        source="student.admission_number",
        read_only=True,
    )

    graded_by_name = serializers.CharField(
        source="graded_by.full_name",
        read_only=True,
        allow_null=True,
    )

    answers = AssignmentAnswerReviewSerializer(
        many=True,
        read_only=True,
    )

    class Meta:
        model = AssignmentSubmission

        fields = (
            "uuid",
            "assignment_uuid",
            "assignment_title",
            "assignment_max_marks",
            "student_uuid",
            "student_name",
            "admission_number",
            "status",
            "total_marks_obtained",
            "feedback",
            "submitted_at",
            "graded_at",
            "graded_by_name",
            "answers",
            "created_at",
            "updated_at",
        )

        read_only_fields = fields


class AssignmentAnswerGradeInputSerializer(
    serializers.Serializer
):
    answer_uuid = serializers.UUIDField()

    marks_obtained = serializers.DecimalField(
        max_digits=8,
        decimal_places=2,
        min_value=0,
    )

    feedback = serializers.CharField(
        required=False,
        allow_blank=True,
    )


class AssignmentSubmissionGradeSerializer(
    serializers.Serializer
):
    feedback = serializers.CharField(
        required=False,
        allow_blank=True,
    )

    answers = AssignmentAnswerGradeInputSerializer(
        many=True,
    )    
    
class AssignmentUpdateSerializer(
    serializers.ModelSerializer
):
    due_at = serializers.DateTimeField(
        required=False,
        allow_null=True,
    )

    class Meta:
        model = Assignment

        fields = (
            "title",
            "description",
            "instructions",
            "due_at",
            "allow_late_submission",
        )
        
        
        
