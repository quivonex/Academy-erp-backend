from django.db.models import Q
from django.shortcuts import get_object_or_404

from rest_framework import status
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from common.pagination import StandardResultsSetPagination
from common.permissions import IsFirmAdminOrStaff
from common.responses import (
    error_response,
    success_response,
)

from .models import Assignment
from .serializers import (
    AssignmentSerializer,
    AssignmentQuestionSerializer,
    AssignmentPDFImportSerializer,
)
from .services import (
    create_assignment,
    create_assignment_question,
    import_assignment_from_pdf,
)


class AssignmentListCreateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get(self, request):
        queryset = (
            Assignment.objects
            .filter(
                firm=request.user.firm
            )
            .select_related(
                "course",
                "subject",
                "chapter",
                "lesson",
                "created_by",
            )
        )

        course_uuid = request.query_params.get(
            "course_uuid"
        )

        search = request.query_params.get(
            "search"
        )

        if course_uuid:
            queryset = queryset.filter(
                course__uuid=course_uuid
            )

        if search:
            queryset = queryset.filter(
                Q(title__icontains=search)
                | Q(description__icontains=search)
            )

        paginator = StandardResultsSetPagination()

        page = paginator.paginate_queryset(
            queryset,
            request,
        )

        serializer = AssignmentSerializer(
            page,
            many=True,
        )

        return paginator.get_paginated_response(
            serializer.data
        )

    def post(self, request):
        serializer = AssignmentSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                message="Assignment creation failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        try:
            assignment = create_assignment(
                firm=request.user.firm,
                created_by=request.user,
                validated_data=serializer.validated_data,
            )

        except ValidationError as exc:
            return error_response(
                message="Assignment creation failed",
                errors=exc.detail,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        return success_response(
            message="Assignment created successfully",
            data=AssignmentSerializer(
                assignment
            ).data,
            status_code=status.HTTP_201_CREATED,
        )


class AssignmentDetailView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get(self, request, assignment_uuid):
        assignment = get_object_or_404(
            Assignment.objects.select_related(
                "course",
                "subject",
                "chapter",
                "lesson",
                "created_by",
            ),
            uuid=assignment_uuid,
            firm=request.user.firm,
        )

        return success_response(
            message="Assignment retrieved successfully",
            data=AssignmentSerializer(
                assignment
            ).data,
        )


class AssignmentQuestionListCreateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get(self, request, assignment_uuid):
        assignment = get_object_or_404(
            Assignment,
            uuid=assignment_uuid,
            firm=request.user.firm,
        )

        questions = assignment.questions.all()

        return success_response(
            message="Assignment questions retrieved successfully",
            data=AssignmentQuestionSerializer(
                questions,
                many=True,
            ).data,
        )

    def post(self, request, assignment_uuid):
        assignment = get_object_or_404(
            Assignment,
            uuid=assignment_uuid,
            firm=request.user.firm,
        )

        serializer = AssignmentQuestionSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                message="Question creation failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        question = create_assignment_question(
            assignment=assignment,
            validated_data=serializer.validated_data,
        )

        return success_response(
            message="Question created successfully",
            data=AssignmentQuestionSerializer(
                question
            ).data,
            status_code=status.HTTP_201_CREATED,
        )
        


class AssignmentPDFImportView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def post(self, request):
        serializer = AssignmentPDFImportSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                message="PDF import failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        try:
            assignment = import_assignment_from_pdf(
                firm=request.user.firm,
                created_by=request.user,
                validated_data=serializer.validated_data,
            )

        except ValidationError as exc:
            return error_response(
                message="PDF import failed",
                errors=exc.detail,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        questions = assignment.questions.all()

        return success_response(
            message=(
                "PDF imported successfully. "
                "Please review questions before publishing."
            ),
            data={
                "assignment": AssignmentSerializer(
                    assignment
                ).data,
                "questions": (
                    AssignmentQuestionSerializer(
                        questions,
                        many=True,
                    ).data
                ),
                "question_count": questions.count(),
            },
            status_code=status.HTTP_201_CREATED,
        )
        
        
