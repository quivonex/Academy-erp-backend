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

    price = serializers.DecimalField(
        source="course.price",
        max_digits=10,
        decimal_places=2,
        read_only=True,
    )

    delivery_mode = serializers.CharField(
        source="course.delivery_mode",
        read_only=True,
    )

    access_duration_days = serializers.IntegerField(
        source="course.access_duration_days",
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
            "price",
            "delivery_mode",
            "access_duration_days",
            "status",
            "source",
            "enrolled_at",
            "access_start_at",
            "access_end_at",
        )
        
        
from classes.models import LiveClass


class StudentLiveClassSerializer(serializers.ModelSerializer):
    course_uuid = serializers.UUIDField(
        source="course.uuid",
        read_only=True,
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

    teacher_name = serializers.CharField(
        source="teacher.full_name",
        read_only=True,
    )

    meeting_url = serializers.SerializerMethodField()
    meeting_id = serializers.SerializerMethodField()
    meeting_password = serializers.SerializerMethodField()

    class Meta:
        model = LiveClass

        fields = (
            "uuid",
            "course_uuid",
            "course_name",
            "subject_name",
            "chapter_title",
            "lesson_title",
            "teacher_name",
            "title",
            "description",
            "scheduled_start_at",
            "scheduled_end_at",
            "actual_start_at",
            "actual_end_at",
            "status",
            "meeting_url",
            "meeting_id",
            "meeting_password",
        )

        read_only_fields = fields

    def get_meeting_url(self, obj):
        if obj.status == LiveClass.Status.LIVE:
            return obj.meeting_url

        return None

    def get_meeting_id(self, obj):
        if obj.status == LiveClass.Status.LIVE:
            return obj.meeting_id

        return None

    def get_meeting_password(self, obj):
        if obj.status == LiveClass.Status.LIVE:
            return obj.meeting_password

        return None
    
    
