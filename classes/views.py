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

from .models import LiveClass
from .serializers import LiveClassSerializer
from .services import (
    create_live_class,
    start_live_class,
    complete_live_class,
    cancel_live_class,
)


class LiveClassListCreateView(APIView):

    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get(self, request):

        queryset = (
            LiveClass.objects
            .filter(firm=request.user.firm)
            .select_related(
                "course",
                "subject",
                "chapter",
                "lesson",
                "teacher",
            )
        )

        course_uuid = request.query_params.get(
            "course_uuid"
        )

        status_value = request.query_params.get(
            "status"
        )

        search = request.query_params.get("search")

        if course_uuid:
            queryset = queryset.filter(
                course__uuid=course_uuid
            )

        if status_value:
            queryset = queryset.filter(
                status=status_value
            )

        if search:
            queryset = queryset.filter(
                Q(title__icontains=search)
                | Q(course__name__icontains=search)
            )

        paginator = StandardResultsSetPagination()

        page = paginator.paginate_queryset(
            queryset,
            request,
        )

        serializer = LiveClassSerializer(
            page,
            many=True,
        )

        return paginator.get_paginated_response(
            serializer.data
        )

    def post(self, request):

        serializer = LiveClassSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                message="Live class creation failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        try:
            live_class = create_live_class(
                request.user.firm,
                serializer.validated_data,
            )

        except ValidationError as exc:
            return error_response(
                message="Live class creation failed",
                errors=exc.detail,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        return success_response(
            message="Live class created successfully",
            data=LiveClassSerializer(
                live_class
            ).data,
            status_code=status.HTTP_201_CREATED,
        )
        
        
        
from django.shortcuts import get_object_or_404


class LiveClassActionBaseView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get_live_class(self, request, live_class_uuid):
        return get_object_or_404(
            LiveClass,
            uuid=live_class_uuid,
            firm=request.user.firm,
        )


class LiveClassStartView(LiveClassActionBaseView):

    def patch(self, request, live_class_uuid):
        live_class = self.get_live_class(
            request,
            live_class_uuid,
        )

        try:
            live_class = start_live_class(live_class)
        except ValidationError as exc:
            return error_response(
                "Unable to start class",
                exc.detail,
                status.HTTP_400_BAD_REQUEST,
            )

        return success_response(
            message="Live class started successfully",
            data=LiveClassSerializer(live_class).data,
        )


class LiveClassCompleteView(LiveClassActionBaseView):

    def patch(self, request, live_class_uuid):
        live_class = self.get_live_class(
            request,
            live_class_uuid,
        )

        try:
            live_class = complete_live_class(live_class)
        except ValidationError as exc:
            return error_response(
                "Unable to complete class",
                exc.detail,
                status.HTTP_400_BAD_REQUEST,
            )

        return success_response(
            message="Live class completed successfully",
            data=LiveClassSerializer(live_class).data,
        )


class LiveClassCancelView(LiveClassActionBaseView):

    def patch(self, request, live_class_uuid):
        live_class = self.get_live_class(
            request,
            live_class_uuid,
        )

        try:
            live_class = cancel_live_class(live_class)
        except ValidationError as exc:
            return error_response(
                "Unable to cancel class",
                exc.detail,
                status.HTTP_400_BAD_REQUEST,
            )

        return success_response(
            message="Live class cancelled successfully",
            data=LiveClassSerializer(live_class).data,
        )
        
        
        
