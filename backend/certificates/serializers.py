from rest_framework import serializers

from .models import CourseCompletionCertificate


class CourseCompletionCertificateSerializer(
    serializers.ModelSerializer
):
    course_uuid = serializers.UUIDField(
        source="course.uuid",
        read_only=True,
    )

    student_uuid = serializers.UUIDField(
        source="student.uuid",
        read_only=True,
    )

    file_available = serializers.SerializerMethodField()

    class Meta:
        model = CourseCompletionCertificate

        fields = (
            "uuid",
            "certificate_number",
            "verification_code",
            "student_uuid",
            "student_name",
            "admission_number",
            "course_uuid",
            "course_name",
            "required_watch_percentage",
            "achieved_watch_percentage",
            "file_available",
            "issued_at",
            "is_revoked",
            "revoked_at",
            "revoked_reason",
        )

        read_only_fields = fields

    def get_file_available(self, obj):
        return bool(obj.file_key) and not obj.is_revoked


class CertificateRevokeSerializer(serializers.Serializer):
    revoked_reason = serializers.CharField(
        min_length=3,
        max_length=1000,
    )


class PublicCertificateVerificationSerializer(
    serializers.ModelSerializer
):
    class Meta:
        model = CourseCompletionCertificate

        fields = (
            "certificate_number",
            "verification_code",
            "student_name",
            "course_name",
            "required_watch_percentage",
            "achieved_watch_percentage",
            "issued_at",
            "is_revoked",
        )

        read_only_fields = fields
        
