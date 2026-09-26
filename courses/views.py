from django.db.models import Count, Q
from django.shortcuts import get_object_or_404

from rest_framework import status
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny
from common.pagination import StandardResultsSetPagination
from common.permissions import IsFirmAdminOrStaff
from common.responses import (
    error_response,
    success_response,
)

from .models import (
    Chapter,
    Course,
    CourseCategory,
    Enrollment,
    Lesson,
    Subject,
)
from .serializers import (
    ChapterSerializer,
    CourseCategorySerializer,
    CourseSerializer,
    EnrollmentSerializer,
    LessonSerializer,
    SubjectSerializer,
    PublicCourseSerializer,
    PublicCourseCategoryQuerySerializer,
    PublicCourseCategorySerializer,
    PublicCourseQuerySerializer,
)
from .services import (
    create_category,
    create_chapter,
    create_course,
    create_enrollment,
    create_lesson,
    create_subject,
    get_category,
    get_chapter,
    get_course,
    get_subject,
    get_teacher,
    update_instance,
)


def validation_error_response(exc):
    return error_response(
        message="Validation failed",
        errors=exc.detail,
        status_code=status.HTTP_400_BAD_REQUEST,
    )


def paginated_response(
    request,
    queryset,
    serializer_class,
):
    paginator = StandardResultsSetPagination()

    page = paginator.paginate_queryset(
        queryset,
        request,
    )

    serializer = serializer_class(
        page,
        many=True,
    )

    return paginator.get_paginated_response(
        serializer.data
    )


class CourseCategoryListCreateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get(self, request):
        queryset = CourseCategory.objects.filter(
            firm=request.user.firm
        )

        search = request.query_params.get("search")

        if search:
            queryset = queryset.filter(
                name__icontains=search
            )

        return paginated_response(
            request,
            queryset,
            CourseCategorySerializer,
        )

    def post(self, request):
        serializer = CourseCategorySerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                "Category creation failed",
                serializer.errors,
                status.HTTP_400_BAD_REQUEST,
            )

        if CourseCategory.objects.filter(
            firm=request.user.firm,
            name__iexact=serializer.validated_data[
                "name"
            ],
        ).exists():
            return error_response(
                "Category creation failed",
                {
                    "name": [
                        "Category already exists."
                    ]
                },
                status.HTTP_400_BAD_REQUEST,
            )

        category = create_category(
            request.user.firm,
            serializer.validated_data,
        )

        return success_response(
            data=CourseCategorySerializer(
                category
            ).data,
            message="Category created successfully",
            status_code=status.HTTP_201_CREATED,
        )


class CourseListCreateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get(self, request):
        queryset = Course.objects.filter(
            firm=request.user.firm
        ).select_related("category")

        search = request.query_params.get("search")

        if search:
            queryset = queryset.filter(
                Q(name__icontains=search)
                | Q(code__icontains=search)
            )

        return paginated_response(
            request,
            queryset,
            CourseSerializer,
        )

    def post(self, request):
        serializer = CourseSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                "Course creation failed",
                serializer.errors,
                status.HTTP_400_BAD_REQUEST,
            )

        code = serializer.validated_data["code"]

        if Course.objects.filter(
            firm=request.user.firm,
            code__iexact=code,
        ).exists():
            return error_response(
                "Course creation failed",
                {
                    "code": [
                        "Course code already exists."
                    ]
                },
                status.HTTP_400_BAD_REQUEST,
            )

        try:
            course = create_course(
                request.user.firm,
                serializer.validated_data,
            )
        except ValidationError as exc:
            return validation_error_response(exc)

        return success_response(
            data=CourseSerializer(course).data,
            message="Course created successfully",
            status_code=status.HTTP_201_CREATED,
        )


class SubjectListCreateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get(self, request):
        queryset = Subject.objects.filter(
            firm=request.user.firm
        ).select_related(
            "course",
            "teacher",
        )

        course_uuid = request.query_params.get(
            "course_uuid"
        )

        if course_uuid:
            queryset = queryset.filter(
                course__uuid=course_uuid
            )

        return paginated_response(
            request,
            queryset,
            SubjectSerializer,
        )

    def post(self, request):
        serializer = SubjectSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                "Subject creation failed",
                serializer.errors,
                status.HTTP_400_BAD_REQUEST,
            )

        try:
            subject = create_subject(
                request.user.firm,
                serializer.validated_data,
            )
        except ValidationError as exc:
            return validation_error_response(exc)

        return success_response(
            data=SubjectSerializer(subject).data,
            message="Subject created successfully",
            status_code=status.HTTP_201_CREATED,
        )


class ChapterListCreateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get(self, request):
        queryset = Chapter.objects.filter(
            firm=request.user.firm
        ).select_related("subject")

        subject_uuid = request.query_params.get(
            "subject_uuid"
        )

        if subject_uuid:
            queryset = queryset.filter(
                subject__uuid=subject_uuid
            )

        return paginated_response(
            request,
            queryset,
            ChapterSerializer,
        )

    def post(self, request):
        serializer = ChapterSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                "Chapter creation failed",
                serializer.errors,
                status.HTTP_400_BAD_REQUEST,
            )

        try:
            chapter = create_chapter(
                request.user.firm,
                serializer.validated_data,
            )
        except ValidationError as exc:
            return validation_error_response(exc)

        return success_response(
            data=ChapterSerializer(chapter).data,
            message="Chapter created successfully",
            status_code=status.HTTP_201_CREATED,
        )


class LessonListCreateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get(self, request):
        queryset = Lesson.objects.filter(
            firm=request.user.firm
        ).select_related("chapter")

        chapter_uuid = request.query_params.get(
            "chapter_uuid"
        )

        if chapter_uuid:
            queryset = queryset.filter(
                chapter__uuid=chapter_uuid
            )

        return paginated_response(
            request,
            queryset,
            LessonSerializer,
        )

    def post(self, request):
        serializer = LessonSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                "Lesson creation failed",
                serializer.errors,
                status.HTTP_400_BAD_REQUEST,
            )

        try:
            lesson = create_lesson(
                request.user.firm,
                serializer.validated_data,
            )
        except ValidationError as exc:
            return validation_error_response(exc)

        return success_response(
            data=LessonSerializer(lesson).data,
            message="Lesson created successfully",
            status_code=status.HTTP_201_CREATED,
        )


class EnrollmentListCreateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get(self, request):
        queryset = Enrollment.objects.filter(
            firm=request.user.firm
        ).select_related(
            "student",
            "course",
        )

        student_uuid = request.query_params.get(
            "student_uuid"
        )

        course_uuid = request.query_params.get(
            "course_uuid"
        )

        if student_uuid:
            queryset = queryset.filter(
                student__uuid=student_uuid
            )

        if course_uuid:
            queryset = queryset.filter(
                course__uuid=course_uuid
            )

        return paginated_response(
            request,
            queryset,
            EnrollmentSerializer,
        )

    def post(self, request):
        serializer = EnrollmentSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                "Enrollment creation failed",
                serializer.errors,
                status.HTTP_400_BAD_REQUEST,
            )

        try:
            enrollment = create_enrollment(
                firm=request.user.firm,
                granted_by=request.user,
                validated_data=serializer.validated_data,
            )
        except ValidationError as exc:
            return validation_error_response(exc)

        return success_response(
            data=EnrollmentSerializer(
                enrollment
            ).data,
            message="Student enrolled successfully",
            status_code=status.HTTP_201_CREATED,
        )
        
        
        
class TenantDetailView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    model = None
    serializer_class = None
    lookup_kwarg = None
    success_name = "Record"

    def get_object(self, request, object_uuid):
        return get_object_or_404(
            self.model,
            uuid=object_uuid,
            firm=request.user.firm,
        )

    def get(self, request, **kwargs):
        obj = self.get_object(
            request,
            kwargs[self.lookup_kwarg],
        )

        return success_response(
            message=f"{self.success_name} retrieved successfully",
            data=self.serializer_class(obj).data,
        )

    def patch(self, request, **kwargs):
        obj = self.get_object(
            request,
            kwargs[self.lookup_kwarg],
        )

        serializer = self.serializer_class(
            obj,
            data=request.data,
            partial=True,
        )

        if not serializer.is_valid():
            return error_response(
                message=f"{self.success_name} update failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        data = dict(serializer.validated_data)

        try:
            self.resolve_relationships(
                request,
                obj,
                data,
            )
        except ValidationError as exc:
            return validation_error_response(exc)

        obj = update_instance(
            obj,
            data,
        )

        return success_response(
            message=f"{self.success_name} updated successfully",
            data=self.serializer_class(obj).data,
        )

    def resolve_relationships(
        self,
        request,
        obj,
        data,
    ):
        pass


class CourseCategoryDetailView(TenantDetailView):
    model = CourseCategory
    serializer_class = CourseCategorySerializer
    lookup_kwarg = "category_uuid"
    success_name = "Category"


class CourseDetailView(TenantDetailView):
    model = Course
    serializer_class = CourseSerializer
    lookup_kwarg = "course_uuid"
    success_name = "Course"

    def resolve_relationships(
        self,
        request,
        obj,
        data,
    ):
        if "category_uuid" in data:
            category_uuid = data.pop(
                "category_uuid"
            )

            obj.category = (
                get_category(
                    request.user.firm,
                    category_uuid,
                )
                if category_uuid
                else None
            )


class SubjectDetailView(TenantDetailView):
    model = Subject
    serializer_class = SubjectSerializer
    lookup_kwarg = "subject_uuid"
    success_name = "Subject"

    def resolve_relationships(
        self,
        request,
        obj,
        data,
    ):
        if "course_uuid" in data:
            obj.course = get_course(
                request.user.firm,
                data.pop("course_uuid"),
            )

        if "teacher_uuid" in data:
            teacher_uuid = data.pop(
                "teacher_uuid"
            )

            obj.teacher = (
                get_teacher(
                    request.user.firm,
                    teacher_uuid,
                )
                if teacher_uuid
                else None
            )


class ChapterDetailView(TenantDetailView):
    model = Chapter
    serializer_class = ChapterSerializer
    lookup_kwarg = "chapter_uuid"
    success_name = "Chapter"

    def resolve_relationships(
        self,
        request,
        obj,
        data,
    ):
        if "subject_uuid" in data:
            obj.subject = get_subject(
                request.user.firm,
                data.pop("subject_uuid"),
            )


class LessonDetailView(TenantDetailView):
    model = Lesson
    serializer_class = LessonSerializer
    lookup_kwarg = "lesson_uuid"
    success_name = "Lesson"

    def resolve_relationships(
        self,
        request,
        obj,
        data,
    ):
        if "chapter_uuid" in data:
            obj.chapter = get_chapter(
                request.user.firm,
                data.pop("chapter_uuid"),
            )


class EnrollmentDetailView(TenantDetailView):
    model = Enrollment
    serializer_class = EnrollmentSerializer
    lookup_kwarg = "enrollment_uuid"
    success_name = "Enrollment"

    def resolve_relationships(
        self,
        request,
        obj,
        data,
    ):
        # Student/course are intentionally immutable
        # after enrollment creation.
        data.pop("student_uuid", None)
        data.pop("course_uuid", None)
        
        
        
class PublicCourseCategoryListView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        query_serializer = PublicCourseCategoryQuerySerializer(
            data=request.query_params
        )

        if not query_serializer.is_valid():
            return error_response(
                message="Invalid category filters",
                errors=query_serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        filters = query_serializer.validated_data

        queryset = (
            CourseCategory.objects
            .filter(
                is_active=True,
                firm__is_active=True,
            )
            .select_related("firm")
            .annotate(
                course_count=Count(
                    "courses",
                    filter=Q(
                        courses__is_active=True,
                        courses__is_published=True,
                        courses__is_purchasable_online=True,
                    ),
                )
            )
            .filter(course_count__gt=0)
            .order_by("name")
        )

        firm_uuid = filters.get("firm_uuid")

        if firm_uuid:
            queryset = queryset.filter(
                firm__uuid=firm_uuid
            )

        return success_response(
            message="Public course categories retrieved successfully",
            data=PublicCourseCategorySerializer(
                queryset,
                many=True,
            ).data,
        )


class PublicCourseListView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        query_serializer = PublicCourseQuerySerializer(
            data=request.query_params
        )

        if not query_serializer.is_valid():
            return error_response(
                message="Invalid course filters",
                errors=query_serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        filters = query_serializer.validated_data

        queryset = (
            Course.objects
            .filter(
                is_active=True,
                is_published=True,
                is_purchasable_online=True,
                firm__is_active=True,
            )
            .select_related(
                "firm",
                "category",
            )
        )

        search = filters.get("search")

        if search:
            queryset = queryset.filter(
                Q(name__icontains=search)
                | Q(code__icontains=search)
                | Q(description__icontains=search)
            )

        category_uuid = filters.get("category_uuid")

        if category_uuid:
            queryset = queryset.filter(
                category__uuid=category_uuid
            )

        firm_uuid = filters.get("firm_uuid")

        if firm_uuid:
            queryset = queryset.filter(
                firm__uuid=firm_uuid
            )

        if filters.get("featured") is True:
            queryset = queryset.filter(
                is_featured=True
            )

        if filters.get("is_free") is True:
            queryset = queryset.filter(
                price=0
            )

        queryset = queryset.order_by(
            "-is_featured",
            "featured_order",
            "-created_at",
        )

        paginator = StandardResultsSetPagination()

        page = paginator.paginate_queryset(
            queryset,
            request,
        )

        serializer = PublicCourseSerializer(
            page,
            many=True,
        )

        return paginator.get_paginated_response(
            serializer.data
        )


class PublicCourseDetailView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request, course_uuid):
        course = get_object_or_404(
            Course.objects.select_related(
                "firm",
                "category",
            ),
            uuid=course_uuid,
            is_active=True,
            is_published=True,
            is_purchasable_online=True,
            firm__is_active=True,
        )

        return success_response(
            message="Course retrieved successfully",
            data=PublicCourseSerializer(course).data,
        )        
        
        
class PublicCourseDetailView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request, course_uuid):
        course = get_object_or_404(
            Course.objects.select_related(
                "firm",
                "category",
            ),
            uuid=course_uuid,
            is_active=True,
            is_published=True,
            is_purchasable_online=True,
            firm__is_active=True,
        )

        return success_response(
            message="Course retrieved successfully",
            data=PublicCourseSerializer(course).data,
        )
        
        



        