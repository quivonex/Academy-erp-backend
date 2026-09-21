from rest_framework import serializers

from courses.models import Enrollment


class StudentCourseSerializer(serializers.ModelSerializer):
    course_uuid = serializers.UUIDField(
        source="course.uuid",
        read_only=True,
    )

    course_name = serializers.CharField(
        source="course.name",
        read_only=True,
    )

    course_code = serializers.CharField(
        source="course.code",
        read_only=True,
    )

    course_description = serializers.CharField(
        source="course.description",
        read_only=True,
    )

    category_name = serializers.CharField(
        source="course.category.name",
        read_only=True,
        allow_null=True,
    )

    class Meta:
        model = Enrollment

        fields = (
            "uuid",
            "course_uuid",
            "course_name",
            "course_code",
            "course_description",
            "category_name",
            "status",
            "enrolled_at",
            "access_start_at",
            "access_end_at",
        )