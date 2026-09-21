from django.db.models import Q

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

from .models import LearningMaterial
from .serializers import LearningMaterialSerializer
from .services import create_material


class LearningMaterialListCreateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get(self, request):
        queryset = (
            LearningMaterial.objects
            .filter(
                firm=request.user.firm
            )
            .select_related(
                "course",
                "subject",
                "chapter",
                "lesson",
                "live_class",
            )
        )

        course_uuid = request.query_params.get(
            "course_uuid"
        )

        material_type = request.query_params.get(
            "material_type"
        )

        search = request.query_params.get(
            "search"
        )

        if course_uuid:
            queryset = queryset.filter(
                course__uuid=course_uuid
            )

        if material_type:
            queryset = queryset.filter(
                material_type=material_type
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

        serializer = LearningMaterialSerializer(
            page,
            many=True,
        )

        return paginator.get_paginated_response(
            serializer.data
        )

    def post(self, request):
        serializer = LearningMaterialSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                message="Material creation failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        try:
            material = create_material(
                firm=request.user.firm,
                validated_data=serializer.validated_data,
            )

        except ValidationError as exc:
            return error_response(
                message="Material creation failed",
                errors=exc.detail,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        return success_response(
            message="Material created successfully",
            data=LearningMaterialSerializer(
                material
            ).data,
            status_code=status.HTTP_201_CREATED,
        )
        
        
