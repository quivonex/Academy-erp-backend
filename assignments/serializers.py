from rest_framework import serializers

from .models import (
    Assignment,
    AssignmentQuestion,
)


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

            attrs["correct_option"] = (
                correct_option
            )

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
        many=True
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
    
    
