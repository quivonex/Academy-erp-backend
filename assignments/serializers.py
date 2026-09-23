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
            "sequence",
            "is_required",
            "created_at",
        )

        read_only_fields = (
            "uuid",
            "created_at",
        )
        
        