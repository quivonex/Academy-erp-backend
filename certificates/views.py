from django.core.files.storage import default_storage
from django.utils import timezone

from rest_framework import status
from rest_framework.permissions import (
    AllowAny,
    IsAuthenticated,
)
from rest_framework.views import APIView

from common.pagination import StandardResultsSetPagination
from common.permissions import (
    IsFirmAdmin,
    IsFirmAdminOrStaff,
    IsStudent,
)
from common.responses import (
    error_response,
    success_response,
)
from courses.models import Enrollment

from .models import CourseCompletionCertificate
from .serializers import (
    CertificateRevokeSerializer,
    CourseCompletionCertificateSerializer,
    PublicCertificateVerificationSerializer,
)
from .services import get_certificate_eligibility


class StudentCertificateListView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsStudent,
    ]

    def get(self, request):
        student = request.user.student_profile

        certificates = (
            CourseCompletionCertificate.objects
            .filter(
                firm=request.user.firm,
                student=student,
            )
            .select_related(
                "course",
                "student",
            )
            .order_by("-issued_at")
        )

        paginator = StandardResultsSetPagination()

        page = paginator.paginate_queryset(
            certificates,
            request,
        )

        return paginator.get_paginated_response(
            CourseCompletionCertificateSerializer(
                page,
                many=True,
            ).data
        )


class StudentCertificateStatusView(APIView):
    """
    Lets the student check progress and certificate eligibility
    before a certificate is issued.
    """
    permission_classes = [
        IsAuthenticated,
        IsStudent,
    ]

    def get(self, request, course_uuid):
        student = request.user.student_profile

        enrollment = (
            Enrollment.objects
            .filter(
                firm=request.user.firm,
                student=student,
                course__uuid=course_uuid,
            )
            .select_related(
                "course",
                "completion_certificate",
            )
            .first()
        )

        if not enrollment:
            return error_response(
                message=(
                    "Course enrollment was not found."
                ),
                errors={},
                status_code=status.HTTP_404_NOT_FOUND,
            )

        eligibility = get_certificate_eligibility(
            enrollment=enrollment,
        )

        try:
            certificate = enrollment.completion_certificate
        except CourseCompletionCertificate.DoesNotExist:
            certificate = None

        return success_response(
            message=(
                "Certificate status retrieved successfully"
            ),
            data={
                "enrollment_uuid": str(enrollment.uuid),
                "course_uuid": str(enrollment.course.uuid),
                "course_name": enrollment.course.name,
                **eligibility,
                "certificate": (
                    CourseCompletionCertificateSerializer(
                        certificate
                    ).data
                    if certificate
                    else None
                ),
            },
        )


class StudentCertificateDownloadView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsStudent,
    ]

    def get(self, request, certificate_uuid):
        student = request.user.student_profile

        certificate = (
            CourseCompletionCertificate.objects
            .filter(
                uuid=certificate_uuid,
                firm=request.user.firm,
                student=student,
            )
            .first()
        )

        if not certificate:
            return error_response(
                message="Certificate not found.",
                errors={},
                status_code=status.HTTP_404_NOT_FOUND,
            )

        if certificate.is_revoked:
            return error_response(
                message=(
                    "This certificate has been revoked "
                    "and cannot be downloaded."
                ),
                errors={},
                status_code=status.HTTP_410_GONE,
            )

        if not certificate.file_key:
            return error_response(
                message=(
                    "Certificate PDF is not available."
                ),
                errors={},
                status_code=status.HTTP_404_NOT_FOUND,
            )

        return success_response(
            message=(
                "Certificate download URL generated "
                "successfully"
            ),
            data={
                "certificate_uuid": str(
                    certificate.uuid
                ),
                "certificate_number": (
                    certificate.certificate_number
                ),
                "download_url": default_storage.url(
                    certificate.file_key
                ),
            },
        )


class FirmCertificateListView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get(self, request):
        certificates = (
            CourseCompletionCertificate.objects
            .filter(firm=request.user.firm)
            .select_related(
                "student",
                "course",
            )
            .order_by("-issued_at")
        )

        student_uuid = request.query_params.get(
            "student_uuid"
        )

        course_uuid = request.query_params.get(
            "course_uuid"
        )

        is_revoked = request.query_params.get(
            "is_revoked"
        )

        if student_uuid:
            certificates = certificates.filter(
                student__uuid=student_uuid
            )

        if course_uuid:
            certificates = certificates.filter(
                course__uuid=course_uuid
            )

        if is_revoked in ["true", "false"]:
            certificates = certificates.filter(
                is_revoked=(is_revoked == "true")
            )

        paginator = StandardResultsSetPagination()

        page = paginator.paginate_queryset(
            certificates,
            request,
        )

        return paginator.get_paginated_response(
            CourseCompletionCertificateSerializer(
                page,
                many=True,
            ).data
        )


class FirmCertificateRevokeView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdmin,
    ]

    def patch(self, request, certificate_uuid):
        serializer = CertificateRevokeSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                message="Certificate revoke failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        certificate = (
            CourseCompletionCertificate.objects
            .filter(
                uuid=certificate_uuid,
                firm=request.user.firm,
            )
            .first()
        )

        if not certificate:
            return error_response(
                message="Certificate not found.",
                errors={},
                status_code=status.HTTP_404_NOT_FOUND,
            )

        if certificate.is_revoked:
            return error_response(
                message=(
                    "This certificate is already revoked."
                ),
                errors={},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        certificate.is_revoked = True
        certificate.revoked_at = timezone.now()
        certificate.revoked_reason = (
            serializer.validated_data["revoked_reason"]
        )

        certificate.save(
            update_fields=[
                "is_revoked",
                "revoked_at",
                "revoked_reason",
            ]
        )

        return success_response(
            message="Certificate revoked successfully",
            data=CourseCompletionCertificateSerializer(
                certificate
            ).data,
        )


class PublicCertificateVerificationView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, verification_code):
        certificate = (
            CourseCompletionCertificate.objects
            .filter(
                verification_code=verification_code
            )
            .first()
        )

        if not certificate:
            return error_response(
                message="Certificate verification failed.",
                errors={},
                status_code=status.HTTP_404_NOT_FOUND,
            )

        return success_response(
            message=(
                "Certificate verification retrieved "
                "successfully"
            ),
            data=PublicCertificateVerificationSerializer(
                certificate
            ).data,
        )