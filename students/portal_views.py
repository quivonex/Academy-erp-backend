from django.db.models import Q
from django.utils import timezone

from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from common.permissions import IsStudent
from common.responses import success_response

from courses.models import Enrollment

from .portal_serializers import StudentCourseSerializer


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