from rest_framework import serializers

from .models import DeviceToken, Notification


class DeviceTokenRegisterSerializer(serializers.Serializer):
    token = serializers.CharField(
        max_length=8192,
        trim_whitespace=True,
    )

    platform = serializers.ChoiceField(
        choices=DeviceToken.Platform.choices,
    )

    device_id = serializers.CharField(
        max_length=255,
        required=False,
        allow_blank=True,
    )

    def validate_token(self, value):
        if not value.strip():
            raise serializers.ValidationError(
                "Device token is required."
            )

        return value


class NotificationSerializer(serializers.ModelSerializer):
    recipient_uuid = serializers.UUIDField(
        source="recipient.uuid",
        read_only=True,
    )

    class Meta:
        model = Notification

        fields = (
            "uuid",
            "recipient_uuid",
            "notification_type",
            "title",
            "body",
            "action_url",
            "data",
            "is_read",
            "read_at",
            "created_at",
        )

        read_only_fields = fields


class NotificationSendSerializer(serializers.Serializer):
    recipient_user_uuids = serializers.ListField(
        child=serializers.UUIDField(),
        min_length=1,
        max_length=500,
    )

    notification_type = serializers.ChoiceField(
        choices=Notification.NotificationType.choices,
        default=Notification.NotificationType.GENERAL,
    )

    title = serializers.CharField(
        max_length=255,
    )

    body = serializers.CharField()

    action_url = serializers.CharField(
        max_length=1000,
        required=False,
        allow_blank=True,
    )

    data = serializers.DictField(
        required=False,
        default=dict,
    )

    def validate_recipient_user_uuids(self, value):
        if len(value) != len(set(value)):
            raise serializers.ValidationError(
                "Duplicate users are not allowed."
            )

        return value
    
    
    
class DeviceTokenUnregisterSerializer(serializers.Serializer):
    token = serializers.CharField(max_length=8192, trim_whitespace=True)

    def validate_token(self, value):
        if not value.strip():
            raise serializers.ValidationError("Device token is required.")
        return value