from django.utils import timezone

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from accounts.models import User
from common.pagination import StandardResultsSetPagination
from common.permissions import IsFirmAdminOrStaff
from common.responses import (
    error_response,
    success_response,
)

from .models import DeviceToken, Notification
from .serializers import (
    DeviceTokenRegisterSerializer,
    NotificationSendSerializer,
    NotificationSerializer,
    DeviceTokenUnregisterSerializer,
)
from .services import (
    create_notification,
    get_token_hash,
    register_device_token,
)


class NotificationListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        queryset = Notification.objects.filter(
            firm=request.user.firm,
            recipient=request.user,
        )

        unread = request.query_params.get("unread")

        if unread == "true":
            queryset = queryset.filter(is_read=False)

        notification_type = request.query_params.get(
            "notification_type"
        )

        if notification_type:
            queryset = queryset.filter(
                notification_type=notification_type
            )

        paginator = StandardResultsSetPagination()

        page = paginator.paginate_queryset(
            queryset,
            request,
        )

        serializer = NotificationSerializer(
            page,
            many=True,
        )

        return paginator.get_paginated_response(
            serializer.data
        )


class NotificationUnreadCountView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        unread_count = Notification.objects.filter(
            firm=request.user.firm,
            recipient=request.user,
            is_read=False,
        ).count()

        return success_response(
            message="Unread notification count retrieved successfully",
            data={
                "unread_count": unread_count,
            },
        )


class NotificationMarkReadView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(
        self,
        request,
        notification_uuid,
    ):
        notification = Notification.objects.filter(
            uuid=notification_uuid,
            firm=request.user.firm,
            recipient=request.user,
        ).first()

        if not notification:
            return error_response(
                message="Notification not found.",
                errors={},
                status_code=status.HTTP_404_NOT_FOUND,
            )

        if not notification.is_read:
            notification.is_read = True
            notification.read_at = timezone.now()

            notification.save(
                update_fields=[
                    "is_read",
                    "read_at",
                ]
            )

        return success_response(
            message="Notification marked as read",
            data=NotificationSerializer(
                notification
            ).data,
        )


class NotificationMarkAllReadView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        updated_count = Notification.objects.filter(
            firm=request.user.firm,
            recipient=request.user,
            is_read=False,
        ).update(
            is_read=True,
            read_at=timezone.now(),
        )

        return success_response(
            message="All notifications marked as read",
            data={
                "updated_count": updated_count,
            },
        )


class DeviceTokenRegisterView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = DeviceTokenRegisterSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                message="Device registration failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        device_token = register_device_token(
            firm=request.user.firm,
            user=request.user,
            token=serializer.validated_data["token"],
            platform=serializer.validated_data["platform"],
            device_id=serializer.validated_data.get(
                "device_id",
                "",
            ),
        )

        return success_response(
            message="Device registered successfully",
            data={
                "uuid": str(device_token.uuid),
                "platform": device_token.platform,
                "is_active": device_token.is_active,
                "last_seen_at": device_token.last_seen_at,
            },
            status_code=status.HTTP_201_CREATED,
        )


class DeviceTokenUnregisterView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = DeviceTokenUnregisterSerializer(data=request.data)

        if not serializer.is_valid():
            return error_response(
                message="Device unregistration failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        updated_count = DeviceToken.objects.filter(
            firm=request.user.firm,
            user=request.user,
            token_hash=get_token_hash(
                serializer.validated_data["token"]
            ),
            is_active=True,
        ).update(
            is_active=False,
            last_seen_at=timezone.now(),
        )

        return success_response(
            message="Device unregistered successfully",
            data={
                "updated_count": updated_count,
            },
        )


class NotificationSendView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def post(self, request):
        serializer = NotificationSendSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                message="Notification sending failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        recipient_uuids = serializer.validated_data[
            "recipient_user_uuids"
        ]

        recipients = list(
            User.objects.filter(
                uuid__in=recipient_uuids,
                firm=request.user.firm,
                is_active=True,
            )
        )

        found_uuids = {
            user.uuid
            for user in recipients
        }

        invalid_user_uuids = [
            str(user_uuid)
            for user_uuid in recipient_uuids
            if user_uuid not in found_uuids
        ]

        if invalid_user_uuids:
            return error_response(
                message="Notification sending failed",
                errors={
                    "recipient_user_uuids": [
                        (
                            "One or more users do not belong "
                            "to your academy or are inactive."
                        )
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        for recipient in recipients:
            create_notification(
                firm=request.user.firm,
                recipient=recipient,
                notification_type=serializer.validated_data[
                    "notification_type"
                ],
                title=serializer.validated_data["title"],
                body=serializer.validated_data["body"],
                action_url=serializer.validated_data.get(
                    "action_url",
                    "",
                ),
                data=serializer.validated_data.get(
                    "data",
                    {},
                ),
            )

        return success_response(
            message="Notifications created successfully",
            data={
                "recipient_count": len(recipients),
                "invalid_user_uuids": invalid_user_uuids,
            },
            status_code=status.HTTP_201_CREATED,
        )