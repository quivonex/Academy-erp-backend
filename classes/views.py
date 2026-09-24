from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.db import transaction
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
from teachers.models import Teacher
from .models import LiveClass
from .serializers import (
    LiveClassSerializer,
    LiveClassUpdateSerializer,
)
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
        
        
class LiveClassActionBaseView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get_live_class(
        self,
        request,
        live_class_uuid,
        lock=False,
    ):
        queryset = LiveClass.objects

        if lock:
            queryset = queryset.select_for_update()

        return get_object_or_404(
            queryset,
            uuid=live_class_uuid,
            firm=request.user.firm,
        )


class LiveClassStartView(LiveClassActionBaseView):

    def patch(self, request, live_class_uuid):
        with transaction.atomic():
            live_class = self.get_live_class(
                request,
                live_class_uuid,
                lock=True,
            )

            try:
                live_class = start_live_class(
                    live_class
                )

            except ValidationError as exc:
                return error_response(
                    message="Unable to start class",
                    errors=exc.detail,
                    status_code=(
                        status.HTTP_400_BAD_REQUEST
                    ),
                )

        return success_response(
            message="Live class started successfully",
            data=LiveClassSerializer(live_class).data,
        )


class LiveClassCompleteView(LiveClassActionBaseView):

    def patch(self, request, live_class_uuid):
        with transaction.atomic():
            live_class = self.get_live_class(
                request,
                live_class_uuid,
                lock=True,
            )

            try:
                live_class = complete_live_class(
                    live_class
                )

            except ValidationError as exc:
                return error_response(
                    message="Unable to complete class",
                    errors=exc.detail,
                    status_code=(
                        status.HTTP_400_BAD_REQUEST
                    ),
                )

        return success_response(
            message="Live class completed successfully",
            data=LiveClassSerializer(live_class).data,
        )


class LiveClassCancelView(LiveClassActionBaseView):

    def patch(self, request, live_class_uuid):
        with transaction.atomic():
            live_class = self.get_live_class(
                request,
                live_class_uuid,
                lock=True,
            )

            try:
                live_class = cancel_live_class(
                    live_class
                )

            except ValidationError as exc:
                return error_response(
                    message="Unable to cancel class",
                    errors=exc.detail,
                    status_code=(
                        status.HTTP_400_BAD_REQUEST
                    ),
                )

        return success_response(
            message="Live class cancelled successfully",
            data=LiveClassSerializer(live_class).data,
        )
        
        
        
class LiveClassDetailView(APIView):

    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get_object(self, request, live_class_uuid):
        return get_object_or_404(
            LiveClass.objects.select_related(
                "course",
                "subject",
                "chapter",
                "lesson",
                "teacher",
            ),
            uuid=live_class_uuid,
            firm=request.user.firm,
        )

    def get(self, request, live_class_uuid):
        live_class = self.get_object(
            request,
            live_class_uuid,
        )

        return success_response(
            message="Live class retrieved successfully",
            data=LiveClassSerializer(live_class).data,
        )

    def patch(self, request, live_class_uuid):

        scheduled_editable_fields = {
            "teacher_uuid",
            "title",
            "description",
            "scheduled_start_at",
            "scheduled_end_at",
            "meeting_url",
            "meeting_id",
            "meeting_password",
        }

        live_editable_fields = {
            "title",
            "description",
            "meeting_url",
            "meeting_id",
            "meeting_password",
        }

        received_fields = set(request.data.keys())

        if not received_fields:
            return error_response(
                message="Please provide at least one field to update.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        with transaction.atomic():

            live_class = get_object_or_404(
                LiveClass.objects.select_for_update(),
                uuid=live_class_uuid,
                firm=request.user.firm,
            )

            if live_class.status == LiveClass.Status.SCHEDULED:
                allowed_fields = scheduled_editable_fields

            elif live_class.status == LiveClass.Status.LIVE:
                allowed_fields = live_editable_fields

            else:
                return error_response(
                    message=(
                        "Completed or cancelled live classes "
                        "cannot be updated."
                    ),
                    status_code=status.HTTP_400_BAD_REQUEST,
                )

            invalid_fields = received_fields - allowed_fields

            if invalid_fields:
                return error_response(
                    message=(
                        "Some fields cannot be updated for "
                        f"a {live_class.status} live class."
                    ),
                    errors={
                        "fields": [
                            (
                                "Not allowed: "
                                + ", ".join(sorted(invalid_fields))
                            )
                        ]
                    },
                    status_code=status.HTTP_400_BAD_REQUEST,
                )

            serializer = LiveClassUpdateSerializer(
                live_class,
                data=request.data,
                partial=True,
            )

            if not serializer.is_valid():
                return error_response(
                    message="Live class update failed",
                    errors=serializer.errors,
                    status_code=status.HTTP_400_BAD_REQUEST,
                )

            validated_data = dict(serializer.validated_data)

            teacher_uuid = validated_data.pop(
                "teacher_uuid",
                None,
            )

            changed_fields = []

            if teacher_uuid:
                teacher = get_object_or_404(
                    Teacher,
                    uuid=teacher_uuid,
                    firm=request.user.firm,
                    is_active=True,
                )

                live_class.teacher = teacher
                changed_fields.append("teacher")

            for field, value in validated_data.items():
                setattr(live_class, field, value)
                changed_fields.append(field)

            live_class.save(
                update_fields=changed_fields + [
                    "updated_at",
                ]
            )

        return success_response(
            message="Live class updated successfully",
            data=LiveClassSerializer(live_class).data,
        )    
        
