from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.utils import timezone

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from common.permissions import IsStudent
from common.responses import (
    error_response,
    success_response,
)

from courses.models import Course
from courses.access import get_student_active_enrollment
from materials.models import LearningMaterial

from .models import StudentMaterialProgress
from .serializers import (
    ProgressUpdateSerializer,
    StudentMaterialProgressSerializer,
)
from .services import update_material_progress


def get_student_available_material(
    *,
    request,
    material_uuid,
):
    now = timezone.now()

    return (
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
        )
        .first()
    )


class StudentMaterialProgressView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsStudent,
    ]

    def get(self, request, material_uuid):
        student = request.user.student_profile

        material = get_student_available_material(
            request=request,
            material_uuid=material_uuid,
        )

        if not material:
            return error_response(
                message="Material not found or unavailable.",
                errors={},
                status_code=status.HTTP_404_NOT_FOUND,
            )

        enrollment = get_student_active_enrollment(
            student=student,
            course=material.course,
        )

        if not enrollment:
            return error_response(
                message="You do not have access to this material.",
                errors={},
                status_code=status.HTTP_403_FORBIDDEN,
            )

        progress = (
            StudentMaterialProgress.objects
            .filter(
                firm=request.user.firm,
                student=student,
                material=material,
            )
            .select_related(
                "material",
                "course",
            )
            .first()
        )

        if not progress:
            return success_response(
                message="No progress recorded yet.",
                data={
                    "material_uuid": str(material.uuid),
                    "watched_seconds": 0,
                    "last_position_seconds": 0,
                    "completion_percentage": "0.00",
                    "is_completed": False,
                },
            )

        return success_response(
            message="Material progress retrieved successfully",
            data=StudentMaterialProgressSerializer(
                progress
            ).data,
        )

    def post(self, request, material_uuid):
        student = request.user.student_profile

        material = get_student_available_material(
            request=request,
            material_uuid=material_uuid,
        )

        if not material:
            return error_response(
                message="Material not found or unavailable.",
                errors={},
                status_code=status.HTTP_404_NOT_FOUND,
            )

        enrollment = get_student_active_enrollment(
            student=student,
            course=material.course,
        )

        if not enrollment:
            return error_response(
                message="You do not have access to this material.",
                errors={},
                status_code=status.HTTP_403_FORBIDDEN,
            )

        serializer = ProgressUpdateSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                message="Progress update failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        progress = update_material_progress(
            student=student,
            material=material,
            validated_data=serializer.validated_data,
        )

        return success_response(
            message="Progress updated successfully",
            data=StudentMaterialProgressSerializer(
                progress
            ).data,
        )
        
        
class StudentCourseProgressView(APIView):
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

        total_materials = (
            LearningMaterial.objects
            .filter(
                firm=request.user.firm,
                course=course,
                is_active=True,
                counts_toward_progress=True,
            )
            .count()
        )

        completed_materials = (
            StudentMaterialProgress.objects
            .filter(
                firm=request.user.firm,
                student=student,
                course=course,
                material__counts_toward_progress=True,
                material__is_active=True,
                is_completed=True,
            )
            .count()
        )

        percentage = 0

        if total_materials > 0:
            percentage = round(
                (
                    completed_materials
                    / total_materials
                ) * 100,
                2,
            )

        return success_response(
            message="Course progress retrieved successfully",
            data={
                "course_uuid": str(course.uuid),
                "course_name": course.name,
                "total_materials": total_materials,
                "completed_materials": completed_materials,
                "completion_percentage": percentage,
            },
        )
        
        


