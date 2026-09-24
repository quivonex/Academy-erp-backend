from rest_framework import serializers

from .models import LearningMaterial

MAX_MATERIAL_FILE_SIZE = 100 * 1024 * 1024

MATERIAL_FILE_SIZE_LIMITS = {
    LearningMaterial.MaterialType.VIDEO: (
        100 * 1024 * 1024
    ),
    LearningMaterial.MaterialType.PDF: (
        25 * 1024 * 1024
    ),
    LearningMaterial.MaterialType.DOCUMENT: (
        25 * 1024 * 1024
    ),
}

ALLOWED_MATERIAL_EXTENSIONS = {
    LearningMaterial.MaterialType.VIDEO: {
        ".mp4",
        ".webm",
        ".mov",
    },
    LearningMaterial.MaterialType.PDF: {
        ".pdf",
    },
    LearningMaterial.MaterialType.DOCUMENT: {
        ".pdf",
        ".doc",
        ".docx",
    },
}


def is_valid_pdf_file(uploaded_file):
    current_position = uploaded_file.tell()

    uploaded_file.seek(0)
    file_header = uploaded_file.read(5)
    uploaded_file.seek(current_position)

    return file_header == b"%PDF-"

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
    def validate_file(self, value):
        if value.size > MAX_MATERIAL_FILE_SIZE:
            raise serializers.ValidationError(
                "File size must not exceed 100 MB."
            )

        return value


    def validate(self, attrs):
        start = attrs.get("available_from")
        end = attrs.get("available_until")
    
        if start and end and end <= start:
            raise serializers.ValidationError({
                "available_until": [
                    (
                        "Availability end must be after "
                        "availability start."
                    )
                ]
            })
    
        material_type = attrs.get("material_type")
        uploaded_file = attrs.get("file")
        external_url = attrs.get("external_url")
    
        if material_type == LearningMaterial.MaterialType.LINK:
            if not external_url:
                raise serializers.ValidationError({
                    "external_url": [
                        (
                            "External URL is required for "
                            "LINK material."
                        )
                    ]
                })
    
            if uploaded_file:
                raise serializers.ValidationError({
                    "file": [
                        (
                            "Do not upload a file for "
                            "LINK material."
                        )
                    ]
                })
    
            return attrs
    
        if not uploaded_file:
            raise serializers.ValidationError({
                "file": [
                    "Please upload a file."
                ]
            })
    
        file_name = uploaded_file.name.lower()
    
        if "." not in file_name:
            raise serializers.ValidationError({
                "file": [
                    "File must have a valid extension."
                ]
            })
    
        extension = "." + file_name.rsplit(
            ".",
            1,
        )[-1]
    
        allowed_extensions = (
            ALLOWED_MATERIAL_EXTENSIONS.get(
                material_type,
                set(),
            )
        )
    
        if extension not in allowed_extensions:
            raise serializers.ValidationError({
                "file": [
                    (
                        f"Invalid file type for "
                        f"{material_type} material."
                    )
                ]
            })
    
        maximum_size = MATERIAL_FILE_SIZE_LIMITS.get(
            material_type,
            MAX_MATERIAL_FILE_SIZE,
        )
    
        if uploaded_file.size > maximum_size:
            maximum_mb = maximum_size // (
                1024 * 1024
            )
    
            raise serializers.ValidationError({
                "file": [
                    (
                        f"Maximum upload size for "
                        f"{material_type} is "
                        f"{maximum_mb} MB."
                    )
                ]
            })
    
        if (
            extension == ".pdf"
            and not is_valid_pdf_file(uploaded_file)
        ):
            raise serializers.ValidationError({
                "file": [
                    "Uploaded file is not a valid PDF."
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
    
    
