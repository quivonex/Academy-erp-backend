from rest_framework import serializers
from .models import LiveClass


class LiveClassSerializer(serializers.ModelSerializer):

    course_uuid = serializers.UUIDField(
        write_only=True
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

    teacher_uuid = serializers.UUIDField(
        write_only=True
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

    teacher_name = serializers.CharField(
        source="teacher.full_name",
        read_only=True,
    )

    class Meta:
        model = LiveClass

        fields = (
            "uuid",
            "course_uuid",
            "course_name",
            "subject_uuid",
            "subject_name",
            "chapter_uuid",
            "lesson_uuid",
            "teacher_uuid",
            "teacher_name",
            "title",
            "description",
            "scheduled_start_at",
            "scheduled_end_at",
            "actual_start_at",
            "actual_end_at",
            "meeting_url",
            "meeting_id",
            "meeting_password",
            "status",
            "is_active",
            "created_at",
            "updated_at",
        )

        read_only_fields = (
            "uuid",
            "actual_start_at",
            "actual_end_at",
            "status",
            "is_active",
            "created_at",
            "updated_at",
        )

    def validate(self, attrs):
        start = attrs.get("scheduled_start_at")
        end = attrs.get("scheduled_end_at")

        if start and end and end <= start:
            raise serializers.ValidationError({
                "scheduled_end_at":
                    "End time must be after start time."
            })

        return attrs
    
    
    