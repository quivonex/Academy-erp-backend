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
    StudentChapterVideoAccess,
)

from courses.access import (
    get_student_active_enrollment,
    student_has_chapter_video_access,
)

from classes.models import LiveClass

from .portal_serializers import (
    StudentChapterVideoCourseSerializer,
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
        full_course_ids = list(
            enrollments.values_list(
                "course_id",
                flat=True,
            )
        )
        chapter_accesses = (
            StudentChapterVideoAccess.objects
            .filter(
                firm=request.user.firm,
                student=student,
                is_active=True,
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
            .exclude(course_id__in=full_course_ids)
            .select_related(
                "course",
                "course__category",
                "chapter",
            )
            .order_by(
                "course__name",
                "chapter__sequence",
            )
        )
        chapters_by_course_id = {}
        first_access_by_course_id = {}
        for access in chapter_accesses:
            if access.course_id not in first_access_by_course_id:
                first_access_by_course_id[
                    access.course_id
                ] = access
            chapters_by_course_id.setdefault(
                access.course_id,
                [],
            ).append(
                {
                    "uuid": str(access.chapter.uuid),
                    "title": access.chapter.title,
                    "sequence": access.chapter.sequence,
                }
            )
        full_course_data = StudentCourseSerializer(
            enrollments,
            many=True,
        ).data
        chapter_only_course_data = (
            StudentChapterVideoCourseSerializer(
                list(first_access_by_course_id.values()),
                many=True,
                context={
                    "chapters_by_course_id": (
                        chapters_by_course_id
                    ),
                },
            ).data
        )
        courses = (
            full_course_data
            + chapter_only_course_data
        )
        paginator = StandardResultsSetPagination()
        page = paginator.paginate_queryset(
            courses,
            request,
        )
        return paginator.get_paginated_response(
            page
        )    
        
class StudentCourseDetailView(APIView):
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
        enrollment = (
            Enrollment.objects
            .filter(
                firm=request.user.firm,
                student=student,
                course=course,
                status=Enrollment.Status.ACTIVE,
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
        if enrollment:
            return success_response(
                message="Course retrieved successfully",
                data=StudentCourseSerializer(
                    enrollment
                ).data,
            )
        chapter_accesses = (
            StudentChapterVideoAccess.objects
            .filter(
                firm=request.user.firm,
                student=student,
                course=course,
                is_active=True,
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
                "chapter",
            )
            .order_by("chapter__sequence")
        )
        first_access = chapter_accesses.first()
        if not first_access:
            return error_response(
                message="You do not have access to this course.",
                errors={},
                status_code=status.HTTP_403_FORBIDDEN,
            )
        accessible_chapters = [
            {
                "uuid": str(access.chapter.uuid),
                "title": access.chapter.title,
                "sequence": access.chapter.sequence,
            }
            for access in chapter_accesses
        ]
        return success_response(
            message=(
                "Chapter video course retrieved successfully"
            ),
            data=StudentChapterVideoCourseSerializer(
                first_access,
                context={
                    "chapters_by_course_id": {
                        course.id: accessible_chapters,
                    },
                },
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

        full_course_enrollment = (
            get_student_active_enrollment(
                student=student,
                course=course,
            )
        )

        granted_chapter_ids = list(
            StudentChapterVideoAccess.objects
            .filter(
                firm=request.user.firm,
                student=student,
                course=course,
                is_active=True,
            )
            .filter(
                Q(access_start_at__isnull=True)
                | Q(access_start_at__lte=now)
            )
            .filter(
                Q(access_end_at__isnull=True)
                | Q(access_end_at__gte=now)
            )
            .values_list("chapter_id", flat=True)
        )

        if not full_course_enrollment and not granted_chapter_ids:
            return error_response(
                message=(
                    "You do not have access to this course "
                    "or its chapter videos."
                ),
                errors={},
                status_code=status.HTTP_403_FORBIDDEN,
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

        # Full course enrollment: all available materials.
        # Chapter-only access: only VIDEO materials in granted chapters.
        if not full_course_enrollment:
            materials = materials.filter(
                material_type=LearningMaterial.MaterialType.VIDEO,
                chapter_id__in=granted_chapter_ids,
            )

        material_type = request.query_params.get(
            "material_type"
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
                    status_code=status.HTTP_400_BAD_REQUEST,
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

    def get(self, request, material_uuid):
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
                message="Material not found or unavailable.",
                errors={},
                status_code=status.HTTP_404_NOT_FOUND,
            )

        full_course_enrollment = (
            get_student_active_enrollment(
                student=student,
                course=material.course,
            )
        )

        if not full_course_enrollment:
            # Chapter-only permission never exposes PDFs,
            # documents, links, or materials without a chapter.
            if (
                material.material_type
                != LearningMaterial.MaterialType.VIDEO
                or not material.chapter
            ):
                return error_response(
                    message=(
                        "You do not have access to this material."
                    ),
                    errors={},
                    status_code=status.HTTP_403_FORBIDDEN,
                )

            has_chapter_access = (
                student_has_chapter_video_access(
                    student=student,
                    course=material.course,
                    chapter=material.chapter,
                )
            )

            if not has_chapter_access:
                return error_response(
                    message=(
                        "You do not have access to this chapter video."
                    ),
                    errors={},
                    status_code=status.HTTP_403_FORBIDDEN,
                )

        serializer = StudentLearningMaterialSerializer(
            material,
            context={
                "request": request,
            },
        )

        return success_response(
            message="Material retrieved successfully",
            data=serializer.data,
        )
        
        
        
