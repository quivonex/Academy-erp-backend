from django.shortcuts import get_object_or_404
from django.db.models import Q
from django.utils import timezone

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from common.permissions import IsStudent
from common.responses import (
    error_response,
    success_response,
)

from courses.models import (
    Course,
    Enrollment,
)

from courses.access import (
    get_student_active_enrollment,
)

from classes.models import LiveClass

from .portal_serializers import (
    StudentCourseSerializer,
    StudentLiveClassSerializer,
)

class StudentMyCoursesView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsStudent,
    ]

    def get(self, request):
        student = request.user.student_profile
        now = timezone.now()

        enrollments = (
            Enrollment.objects
            .filter(
                firm=request.user.firm,
                student=student,
                status=Enrollment.Status.ACTIVE,
                course__is_active=True,
            )
            .filter(
                Q(access_start_at__isnull=True)
                | Q(access_start_at__lte=now)
            )
            .filter(
                Q(access_end_at__isnull=True)
                | Q(access_end_at__gte=now)
            )
            .select_related(
                "course",
                "course__category",
            )
            .order_by("-enrolled_at")
        )

        serializer = StudentCourseSerializer(
            enrollments,
            many=True,
        )

        return success_response(
            message="My courses retrieved successfully",
            data=serializer.data,
        )
        
        
class StudentCourseDetailView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsStudent,
    ]

    def get(self, request, course_uuid):
        student = request.user.student_profile
        now = timezone.now()

        enrollment = (
            Enrollment.objects
            .filter(
                firm=request.user.firm,
                student=student,
                course__uuid=course_uuid,
                status=Enrollment.Status.ACTIVE,
                course__is_active=True,
            )
            .filter(
                Q(access_start_at__isnull=True)
                | Q(access_start_at__lte=now)
            )
            .filter(
                Q(access_end_at__isnull=True)
                | Q(access_end_at__gte=now)
            )
            .select_related(
                "course",
                "course__category",
            )
            .first()
        )

        if not enrollment:
            return error_response(
                message="You do not have access to this course.",
                errors={},
                status_code=404,
            )

        return success_response(
            message="Course retrieved successfully",
            data=StudentCourseSerializer(
                enrollment
            ).data,
        )        

class StudentLiveClassListView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsStudent,
    ]

    def get(self, request):
        student = request.user.student_profile
        now = timezone.now()

        active_enrollments = (
            Enrollment.objects
            .filter(
                firm=request.user.firm,
                student=student,
                status=Enrollment.Status.ACTIVE,
                course__is_active=True,
            )
            .filter(
                Q(access_start_at__isnull=True)
                | Q(access_start_at__lte=now)
            )
            .filter(
                Q(access_end_at__isnull=True)
                | Q(access_end_at__gte=now)
            )
        )

        course_ids = active_enrollments.values_list(
            "course_id",
            flat=True,
        )

        live_classes = (
            LiveClass.objects
            .filter(
                firm=request.user.firm,
                course_id__in=course_ids,
                is_active=True,
            )
            .exclude(
                status=LiveClass.Status.CANCELLED
            )
            .select_related(
                "course",
                "subject",
                "chapter",
                "lesson",
                "teacher",
            )
            .order_by("scheduled_start_at")
        )

        status_value = request.query_params.get(
            "status"
        )

        if status_value:
            valid_statuses = [
                LiveClass.Status.SCHEDULED,
                LiveClass.Status.LIVE,
                LiveClass.Status.COMPLETED,
            ]

            if status_value not in valid_statuses:
                return error_response(
                    message="Invalid live class status.",
                    errors={
                        "status": [
                            "Use SCHEDULED, LIVE, or COMPLETED."
                        ]
                    },
                    status_code=status.HTTP_400_BAD_REQUEST,
                )

            live_classes = live_classes.filter(
                status=status_value
            )

        serializer = StudentLiveClassSerializer(
            live_classes,
            many=True,
        )

        return success_response(
            message="Live classes retrieved successfully",
            data=serializer.data,
        )
        
        
class StudentCourseLiveClassListView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsStudent,
    ]

    def get(self, request, course_uuid):
        student = request.user.student_profile

        course = get_object_or_404(
            Course,
            uuid=course_uuid,
            firm=request.user.firm,
            is_active=True,
        )

        enrollment = get_student_active_enrollment(
            student=student,
            course=course,
        )

        if not enrollment:
            return error_response(
                message="You do not have access to this course.",
                errors={},
                status_code=status.HTTP_403_FORBIDDEN,
            )

        live_classes = (
            LiveClass.objects
            .filter(
                firm=request.user.firm,
                course=course,
                is_active=True,
            )
            .exclude(
                status=LiveClass.Status.CANCELLED
            )
            .select_related(
                "course",
                "subject",
                "chapter",
                "lesson",
                "teacher",
            )
            .order_by("scheduled_start_at")
        )

        serializer = StudentLiveClassSerializer(
            live_classes,
            many=True,
        )

        return success_response(
            message="Course live classes retrieved successfully",
            data=serializer.data,
        )
        
        
        
