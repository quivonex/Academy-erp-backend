"""Student-initiated enrollment requests. Activation remains an academy action."""
from django.db import transaction
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from common.permissions import IsStudent
from common.responses import error_response, success_response
from courses.access import student_has_course_access
from courses.models import Course, Enrollment
from students.models import Student


def _course(request, course_uuid):
    return get_object_or_404(
        Course, uuid=course_uuid, firm=request.user.firm,
        is_active=True, is_published=True, is_purchasable_online=True,
        firm__is_active=True, firm__status="ACTIVE",
    )


def _data(enrollment):
    return {
        "uuid": str(enrollment.uuid),
        "course_uuid": str(enrollment.course.uuid),
        "course_name": enrollment.course.name,
        "status": enrollment.status,
        "has_access": (
            enrollment.status == Enrollment.Status.ACTIVE
            and enrollment.student.is_active
            and enrollment.course.is_active
            and student_has_course_access(
                student=enrollment.student, course=enrollment.course,
            )
        ),
    }


class StudentCourseEnrollmentView(APIView):
    permission_classes = [IsAuthenticated, IsStudent]

    def get(self, request, course_uuid):
        course = _course(request, course_uuid)
        enrollment = Enrollment.objects.select_related("course", "student").filter(
            firm=request.user.firm, student=request.user.student_profile,
            course=course,
        ).first()
        return success_response(
            message="Enrollment status retrieved",
            data=_data(enrollment) if enrollment else {
                "course_uuid": str(course.uuid),
                "course_name": course.name,
                "status": "NOT_ENROLLED",
                "has_access": False,
            },
        )

    @transaction.atomic
    def post(self, request, course_uuid):
        # Identity, academy, fees, and access status are never client controlled.
        if request.data:
            return error_response(
                "Enrollment does not accept student, fee, or access overrides.",
                {}, status.HTTP_400_BAD_REQUEST,
            )
        student = get_object_or_404(
            Student.objects.select_for_update(),
            pk=request.user.student_profile.pk,
            firm=request.user.firm, is_active=True,
        )
        course = _course(request, course_uuid)
        enrollment, created = Enrollment.objects.get_or_create(
            student=student, course=course,
            defaults={
                "firm": request.user.firm,
                "status": Enrollment.Status.PENDING,
                "source": Enrollment.Source.FIRM_GRANTED,
            },
        )
        if enrollment.firm_id != request.user.firm_id:
            return error_response("Enrollment not available.", {}, status.HTTP_404_NOT_FOUND)
        return success_response(
            message="Enrollment request submitted for academy approval"
            if created else "Enrollment already exists",
            data=_data(enrollment),
            status_code=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class StudentEnrollmentRequestsView(APIView):
    permission_classes = [IsAuthenticated, IsStudent]

    def get(self, request):
        enrollments = Enrollment.objects.filter(
            firm=request.user.firm, student=request.user.student_profile,
            status=Enrollment.Status.PENDING,
        ).select_related("course", "student").order_by("-created_at")
        from common.pagination import StandardResultsSetPagination
        paginator = StandardResultsSetPagination()
        page = paginator.paginate_queryset(enrollments, request)
        return paginator.get_paginated_response([_data(item) for item in page])
