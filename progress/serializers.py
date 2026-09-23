from rest_framework import serializers

from .models import StudentMaterialProgress


class ProgressUpdateSerializer(serializers.Serializer):
    watched_seconds = serializers.IntegerField(
        min_value=0,
        required=False,
    )

    last_position_seconds = serializers.IntegerField(
        min_value=0,
        required=False,
    )

    mark_completed = serializers.BooleanField(
        required=False,
        default=False,
    )


class StudentMaterialProgressSerializer(
    serializers.ModelSerializer
):
    material_uuid = serializers.UUIDField(
        source="material.uuid",
        read_only=True,
    )

    material_title = serializers.CharField(
        source="material.title",
        read_only=True,
    )

    material_type = serializers.CharField(
        source="material.material_type",
        read_only=True,
    )

    course_uuid = serializers.UUIDField(
        source="course.uuid",
        read_only=True,
    )

    course_name = serializers.CharField(
        source="course.name",
        read_only=True,
    )

    class Meta:
        model = StudentMaterialProgress

        fields = (
            "uuid",
            "material_uuid",
            "material_title",
            "material_type",
            "course_uuid",
            "course_name",
            "watched_seconds",
            "last_position_seconds",
            "completion_percentage",
            "is_completed",
            "started_at",
            "completed_at",
            "last_accessed_at",
            "updated_at",
        )

        read_only_fields = fields
        
        