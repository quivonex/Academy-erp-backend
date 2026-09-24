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
    StudentLearningMaterialSerializer,
)
from materials.models import LearningMaterial
from common.pagination import StandardResultsSetPagination

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

        paginator = StandardResultsSetPagination()

        page = paginator.paginate_queryset(
            enrollments,
            request,
        )

        serializer = StudentCourseSerializer(
            page,
            many=True,
        )

        return paginator.get_paginated_response(
            serializer.data
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

        paginator = StandardResultsSetPagination()

        page = paginator.paginate_queryset(
            live_classes,
            request,
        )

        serializer = StudentLiveClassSerializer(
            page,
            many=True,
        )

        return paginator.get_paginated_response(
            serializer.data
        )
        
        
class StudentLiveClassDetailView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsStudent,
    ]

    def get(self, request, live_class_uuid):
        student = request.user.student_profile

        live_class = (
            LiveClass.objects
            .filter(
                uuid=live_class_uuid,
                firm=request.user.firm,
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
            .first()
        )

        if not live_class:
            return error_response(
                message=(
                    "Live class not found or unavailable."
                ),
                errors={},
                status_code=status.HTTP_404_NOT_FOUND,
            )

        enrollment = get_student_active_enrollment(
            student=student,
            course=live_class.course,
        )

        if not enrollment:
            return error_response(
                message=(
                    "You do not have access to this "
                    "live class."
                ),
                errors={},
                status_code=status.HTTP_403_FORBIDDEN,
            )

        return success_response(
            message="Live class retrieved successfully",
            data=StudentLiveClassSerializer(
                live_class
            ).data,
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

        paginator = StandardResultsSetPagination()

        page = paginator.paginate_queryset(
            live_classes,
            request,
        )

        serializer = StudentLiveClassSerializer(
            page,
            many=True,
        )

        return paginator.get_paginated_response(
            serializer.data
        )
        
        
        
class StudentCourseMaterialListView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsStudent,
    ]

    def get(self, request, course_uuid):
        student = request.user.student_profile
        now = timezone.now()

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
                message=(
                    "You do not have access "
                    "to this course."
                ),
                errors={},
                status_code=(
                    status.HTTP_403_FORBIDDEN
                ),
            )

        materials = (
            LearningMaterial.objects
            .filter(
                firm=request.user.firm,
                course=course,
                is_active=True,
            )
            .filter(
                Q(available_from__isnull=True)
                | Q(available_from__lte=now)
            )
            .filter(
                Q(available_until__isnull=True)
                | Q(available_until__gte=now)
            )
            .select_related(
                "course",
                "subject",
                "chapter",
                "lesson",
                "live_class",
            )
            .order_by(
                "sequence",
                "created_at",
            )
        )

        material_type = (
            request.query_params.get(
                "material_type"
            )
        )

        if material_type:
            valid_types = [
                LearningMaterial.MaterialType.VIDEO,
                LearningMaterial.MaterialType.PDF,
                LearningMaterial.MaterialType.DOCUMENT,
                LearningMaterial.MaterialType.LINK,
            ]

            if material_type not in valid_types:
                return error_response(
                    message="Invalid material type.",
                    errors={
                        "material_type": [
                            (
                                "Use VIDEO, PDF, "
                                "DOCUMENT, or LINK."
                            )
                        ]
                    },
                    status_code=(
                        status.HTTP_400_BAD_REQUEST
                    ),
                )

            materials = materials.filter(
                material_type=material_type
            )

        paginator = StandardResultsSetPagination()
        
        page = paginator.paginate_queryset(
            materials,
            request,
        )
        
        serializer = StudentLearningMaterialSerializer(
            page,
            many=True,
            context={
                "request": request,
            },
        )
        
        return paginator.get_paginated_response(
            serializer.data
        )
        
        
        
class StudentMaterialDetailView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsStudent,
    ]

    def get(
        self,
        request,
        material_uuid,
    ):
        student = request.user.student_profile
        now = timezone.now()

        material = (
            LearningMaterial.objects
            .filter(
                uuid=material_uuid,
                firm=request.user.firm,
                is_active=True,
            )
            .filter(
                Q(available_from__isnull=True)
                | Q(available_from__lte=now)
            )
            .filter(
                Q(available_until__isnull=True)
                | Q(available_until__gte=now)
            )
            .select_related(
                "course",
                "subject",
                "chapter",
                "lesson",
                "live_class",
            )
            .first()
        )

        if not material:
            return error_response(
                message=(
                    "Material not found "
                    "or unavailable."
                ),
                errors={},
                status_code=(
                    status.HTTP_404_NOT_FOUND
                ),
            )

        enrollment = get_student_active_enrollment(
            student=student,
            course=material.course,
        )

        if not enrollment:
            return error_response(
                message=(
                    "You do not have access "
                    "to this material."
                ),
                errors={},
                status_code=(
                    status.HTTP_403_FORBIDDEN
                ),
            )

        serializer = (
            StudentLearningMaterialSerializer(
                material,
                context={
                    "request": request
                },
            )
        )

        return success_response(
            message=(
                "Material retrieved successfully"
            ),
            data=serializer.data,
        )
        
        
        
