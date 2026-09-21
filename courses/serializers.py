from rest_framework import serializers

from .models import (
    Chapter,
    Course,
    CourseCategory,
    Enrollment,
    Lesson,
    Subject,
)


class CourseCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = CourseCategory
        fields = (
            "uuid",
            "name",
            "description",
            "is_active",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "uuid",
            "created_at",
            "updated_at",
        )


class CourseSerializer(serializers.ModelSerializer):
    category_uuid = serializers.UUIDField(
        write_only=True,
        required=False,
        allow_null=True,
    )

    category = CourseCategorySerializer(
        read_only=True,
    )

    class Meta:
        model = Course
        fields = (
            "uuid",
            "name",
            "code",
            "description",
            "duration_months",
            "category_uuid",
            "category",
            "is_active",
            "created_at",
            "updated_at",
            
            "price",
            "delivery_mode",
            "is_published",
            "is_purchasable_online",
            "access_duration_days",
        )
        read_only_fields = (
            "uuid",
            "created_at",
            "updated_at",
        )


class SubjectSerializer(serializers.ModelSerializer):
    course_uuid = serializers.UUIDField(
        write_only=True,
    )

    teacher_uuid = serializers.UUIDField(
        write_only=True,
        required=False,
        allow_null=True,
    )

    course_name = serializers.CharField(
        source="course.name",
        read_only=True,
    )

    teacher_name = serializers.CharField(
        source="teacher.full_name",
        read_only=True,
        allow_null=True,
    )

    class Meta:
        model = Subject
        fields = (
            "uuid",
            "course_uuid",
            "course_name",
            "teacher_uuid",
            "teacher_name",
            "name",
            "code",
            "description",
            "is_active",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "uuid",
            "created_at",
            "updated_at",
        )


class ChapterSerializer(serializers.ModelSerializer):
    subject_uuid = serializers.UUIDField(
        write_only=True,
    )

    subject_name = serializers.CharField(
        source="subject.name",
        read_only=True,
    )

    class Meta:
        model = Chapter
        fields = (
            "uuid",
            "subject_uuid",
            "subject_name",
            "title",
            "description",
            "sequence",
            "is_active",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "uuid",
            "created_at",
            "updated_at",
        )


class LessonSerializer(serializers.ModelSerializer):
    chapter_uuid = serializers.UUIDField(
        write_only=True,
    )

    chapter_title = serializers.CharField(
        source="chapter.title",
        read_only=True,
    )

    class Meta:
        model = Lesson
        fields = (
            "uuid",
            "chapter_uuid",
            "chapter_title",
            "title",
            "description",
            "sequence",
            "is_active",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "uuid",
            "created_at",
            "updated_at",
        )


class EnrollmentSerializer(serializers.ModelSerializer):
    student_uuid = serializers.UUIDField(
        write_only=True,
    )

    course_uuid = serializers.UUIDField(
        write_only=True,
    )

    student_name = serializers.CharField(
        source="student.full_name",
        read_only=True,
    )

    admission_number = serializers.CharField(
        source="student.admission_number",
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

    class Meta:
        model = Enrollment

        fields = (
            "uuid",
            "student_uuid",
            "student_name",
            "admission_number",
            "course_uuid",
            "course_name",
            "course_code",
            "status",
            "enrolled_at",
            "access_start_at",
            "access_end_at",
            "created_at",
            "updated_at",
        )

        read_only_fields = (
            "uuid",
            "enrolled_at",
            "created_at",
            "updated_at",
        )

    def validate(self, attrs):
        start = attrs.get("access_start_at")
        end = attrs.get("access_end_at")

        if start and end and end <= start:
            raise serializers.ValidationError({
                "access_end_at": (
                    "Access end time must be after access start time."
                )
            })

        return attrs
    


class PublicCourseSerializer(serializers.ModelSerializer):
    firm_uuid = serializers.UUIDField(
        source="firm.uuid",
        read_only=True,
    )

    firm_name = serializers.CharField(
        source="firm.name",
        read_only=True,
    )

    category_name = serializers.CharField(
        source="category.name",
        read_only=True,
        allow_null=True,
    )

    class Meta:
        model = Course

        fields = (
            "uuid",
            "firm_uuid",
            "firm_name",
            "category_name",
            "name",
            "code",
            "description",
            "duration_months",
            "price",
            "delivery_mode",
            "access_duration_days",
        )

        read_only_fields = fields
        
        
        
        
        