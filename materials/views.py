from django.shortcuts import get_object_or_404
from django.db.models import Q
from django.core.files.storage import default_storage
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
from .serializers import (LearningMaterialSerializer,
    LearningMaterialUpdateSerializer, )
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
        
        
class LearningMaterialDetailView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get_object(
        self,
        request,
        material_uuid,
    ):
        return get_object_or_404(
            LearningMaterial.objects.select_related(
                "course",
                "subject",
                "chapter",
                "lesson",
                "live_class",
            ),
            uuid=material_uuid,
            firm=request.user.firm,
        )

    def get(
        self,
        request,
        material_uuid,
    ):
        material = self.get_object(
            request,
            material_uuid,
        )

        return success_response(
            message="Material retrieved successfully",
            data=LearningMaterialSerializer(
                material
            ).data,
        )

    def patch(
        self,
        request,
        material_uuid,
    ):
        material = self.get_object(
            request,
            material_uuid,
        )

        serializer = LearningMaterialUpdateSerializer(
            material,
            data=request.data,
            partial=True,
        )

        if not serializer.is_valid():
            return error_response(
                message="Material update failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        material = serializer.save()

        return success_response(
            message="Material updated successfully",
            data=LearningMaterialSerializer(
                material
            ).data,
        )

    def delete(
        self,
        request,
        material_uuid,
    ):
        material = self.get_object(
            request,
            material_uuid,
        )

        if material.student_progress.exists():
            return error_response(
                message="Material deletion failed",
                errors={
                    "material": [
                        (
                            "This material cannot be deleted "
                            "because students have progress "
                            "records for it."
                        )
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        file_key = material.file_key

        material.delete()

        if file_key:
            try:
                default_storage.delete(file_key)
            except Exception:
                pass

        return success_response(
            message="Material deleted successfully",
            data={},
        )
        
        
