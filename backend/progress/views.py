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

from .models import (
    StudentMaterialProgress,
    StudentVideoWatchSession,
)
from .serializers import (
    ProgressUpdateSerializer,
    StudentMaterialProgressSerializer,
    StudentVideoWatchSessionSerializer,
    VideoWatchHeartbeatSerializer,
)
from .services import (
    end_video_watch_session,
    record_verified_video_heartbeat,
    start_video_watch_session,
    update_material_progress,
)


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
        
        
class StudentVideoWatchSessionStartView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsStudent,
    ]

    def post(self, request, material_uuid):
        student = request.user.student_profile

        material = get_student_available_material(
            request=request,
            material_uuid=material_uuid,
        )

        if not material:
            return error_response(
                message="Video not found or unavailable.",
                errors={},
                status_code=status.HTTP_404_NOT_FOUND,
            )

        enrollment = get_student_active_enrollment(
            student=student,
            course=material.course,
        )

        if not enrollment:
            return error_response(
                message="You do not have access to this video.",
                errors={},
                status_code=status.HTTP_403_FORBIDDEN,
            )

        if (
            material.material_type
            != LearningMaterial.MaterialType.VIDEO
        ):
            return error_response(
                message=(
                    "Watch sessions are available only for videos."
                ),
                errors={},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        if not material.duration_seconds:
            return error_response(
                message=(
                    "Video duration is required before secure "
                    "watch tracking can start."
                ),
                errors={},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        session = start_video_watch_session(
            student=student,
            material=material,
        )

        return success_response(
            message="Video watch session started successfully",
            data=StudentVideoWatchSessionSerializer(
                session
            ).data,
            status_code=status.HTTP_201_CREATED,
        )


class StudentVideoWatchHeartbeatView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsStudent,
    ]

    def post(self, request, session_uuid):
        student = request.user.student_profile

        session = (
            StudentVideoWatchSession.objects
            .filter(
                uuid=session_uuid,
                firm=request.user.firm,
                student=student,
            )
            .select_related(
                "progress",
                "material",
            )
            .first()
        )

        if not session:
            return error_response(
                message="Video watch session not found.",
                errors={},
                status_code=status.HTTP_404_NOT_FOUND,
            )

        serializer = VideoWatchHeartbeatSerializer(
            data=request.data,
        )

        if not serializer.is_valid():
            return error_response(
                message="Video progress update failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        try:
            session = record_verified_video_heartbeat(
                session=session,
                player_position_seconds=(
                    serializer.validated_data[
                        "player_position_seconds"
                    ]
                ),
            )
        except ValueError as exc:
            return error_response(
                message="Video progress update failed",
                errors={
                    "session": [str(exc)],
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        return success_response(
            message="Verified video progress updated successfully",
            data=StudentVideoWatchSessionSerializer(
                session
            ).data,
        )


class StudentVideoWatchSessionEndView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsStudent,
    ]

    def post(self, request, session_uuid):
        student = request.user.student_profile

        session = (
            StudentVideoWatchSession.objects
            .filter(
                uuid=session_uuid,
                firm=request.user.firm,
                student=student,
            )
            .first()
        )

        if not session:
            return error_response(
                message="Video watch session not found.",
                errors={},
                status_code=status.HTTP_404_NOT_FOUND,
            )

        session = end_video_watch_session(
            session=session,
        )

        return success_response(
            message="Video watch session ended successfully",
            data=StudentVideoWatchSessionSerializer(
                session
            ).data,
        )

