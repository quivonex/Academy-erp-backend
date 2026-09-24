from rest_framework import serializers

from .models import LearningMaterial


class LearningMaterialSerializer(serializers.ModelSerializer):

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

    live_class_uuid = serializers.UUIDField(
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

    file = serializers.FileField(
        write_only=True,
        required=False,
    )
    
    class Meta:
        model = LearningMaterial

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
            "live_class_uuid",
            "title",
            "description",
            "material_type",
            "source",
            "file",
            "file_key",
            "external_url",
            "duration_seconds",
            "sequence",
            "available_from",
            "available_until",
            "is_required",
            "counts_toward_progress",
            "is_active",
            "created_at",
            "updated_at",
        )

        read_only_fields = (
            "uuid",
            "file_key",
            "is_active",
            "created_at",
            "updated_at",
        )

    def validate(self, attrs):
        start = attrs.get("available_from")
        end = attrs.get("available_until")

        if start and end and end <= start:
            raise serializers.ValidationError({
                "available_until": [
                    "Availability end must be after availability start."
                ]
            })

        material_type = attrs.get(
            "material_type"
        )

        uploaded_file = attrs.get(
            "file"
        )

        external_url = attrs.get(
            "external_url"
        )

        if material_type == LearningMaterial.MaterialType.LINK:
            if not external_url:
                raise serializers.ValidationError({
                    "external_url": [
                        "External URL is required for LINK material."
                    ]
                })

        elif not uploaded_file:
            raise serializers.ValidationError({
                "file": [
                    "Please upload a file."
                ]
            })

        return attrs
    
    
class LearningMaterialUpdateSerializer(
    serializers.ModelSerializer
):
    available_from = serializers.DateTimeField(
        required=False,
        allow_null=True,
    )

    available_until = serializers.DateTimeField(
        required=False,
        allow_null=True,
    )

    class Meta:
        model = LearningMaterial

        fields = (
            "title",
            "description",
            "external_url",
            "duration_seconds",
            "sequence",
            "available_from",
            "available_until",
            "is_required",
            "counts_toward_progress",
        )

    def validate(self, attrs):
        material = self.instance

        available_from = attrs.get(
            "available_from",
            material.available_from,
        )

        available_until = attrs.get(
            "available_until",
            material.available_until,
        )

        if (
            available_from
            and available_until
            and available_until <= available_from
        ):
            raise serializers.ValidationError({
                "available_until": [
                    (
                        "Availability end must be after "
                        "availability start."
                    )
                ]
            })

        external_url = attrs.get(
            "external_url",
            material.external_url,
        )

        if (
            material.material_type
            == LearningMaterial.MaterialType.LINK
            and not external_url
        ):
            raise serializers.ValidationError({
                "external_url": [
                    (
                        "External URL is required for "
                        "LINK material."
                    )
                ]
            })

        return attrs
    
    
