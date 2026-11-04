from rest_framework import serializers

from .models import (
    StudentMaterialProgress,
    StudentVideoWatchSession,
)


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
        
        
class VideoWatchHeartbeatSerializer(serializers.Serializer):
    player_position_seconds = serializers.IntegerField(
        min_value=0,
    )


class StudentVideoWatchSessionSerializer(
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

    resume_position_seconds = serializers.IntegerField(
        source="progress.verified_watched_seconds",
        read_only=True,
    )

    verified_watched_seconds = serializers.IntegerField(
        source="progress.verified_watched_seconds",
        read_only=True,
    )

    verified_completion_percentage = serializers.DecimalField(
        source="progress.verified_completion_percentage",
        max_digits=5,
        decimal_places=2,
        read_only=True,
    )

    is_verified_completed = serializers.BooleanField(
        source="progress.is_verified_completed",
        read_only=True,
    )

    class Meta:
        model = StudentVideoWatchSession

        fields = (
            "uuid",
            "material_uuid",
            "material_title",
            "resume_position_seconds",
            "verified_watched_seconds",
            "verified_completion_percentage",
            "is_verified_completed",
            "started_at",
            "last_heartbeat_at",
            "ended_at",
            "is_active",
        )

        read_only_fields = fields
        
        
