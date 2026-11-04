import uuid

from django.conf import settings
from django.db import models
from django.utils import timezone
import hashlib
from firms.models import Firm


class DeviceToken(models.Model):
    class Platform(models.TextChoices):
        ANDROID = "ANDROID", "Android"
        WEB = "WEB", "Web"
        IOS = "IOS", "iOS"

    uuid = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
        db_index=True,
    )

    firm = models.ForeignKey(
        Firm,
        on_delete=models.PROTECT,
        related_name="device_tokens",
    )

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="device_tokens",
    )

    token = models.TextField( )

    token_hash = models.CharField( max_length=64, unique=True, db_index=True,)
    
    platform = models.CharField(
        max_length=20,
        choices=Platform.choices,
    )

    device_id = models.CharField(
        max_length=255,
        blank=True,
    )

    is_active = models.BooleanField(
        default=True,
        db_index=True,
    )

    last_seen_at = models.DateTimeField(
        default=timezone.now,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    def save(self, *args, **kwargs):
        self.token_hash = hashlib.sha256(
            self.token.encode("utf-8")
        ).hexdigest()

        super().save(*args, **kwargs)

    class Meta:
        db_table = "notification_device_tokens"
        ordering = ["-last_seen_at"]

        indexes = [
            models.Index(
                fields=[
                    "firm",
                    "user",
                    "is_active",
                ]
            ),
        ]

    def __str__(self):
        return f"{self.user} - {self.platform}"


class Notification(models.Model):
    class NotificationType(models.TextChoices):
        GENERAL = "GENERAL", "General"
        COURSE_ACCESS = "COURSE_ACCESS", "Course Access"
        ASSIGNMENT = "ASSIGNMENT", "Assignment"
        LIVE_CLASS = "LIVE_CLASS", "Live Class"
        MATERIAL = "MATERIAL", "Material"
        PAYMENT = "PAYMENT", "Payment"
        RESULT = "RESULT", "Result"

    uuid = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
        db_index=True,
    )

    firm = models.ForeignKey(
        Firm,
        on_delete=models.PROTECT,
        related_name="notifications",
    )

    recipient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="notifications",
    )

    notification_type = models.CharField(
        max_length=30,
        choices=NotificationType.choices,
        default=NotificationType.GENERAL,
        db_index=True,
    )

    title = models.CharField(
        max_length=255,
    )

    body = models.TextField()

    action_url = models.CharField(
        max_length=1000,
        blank=True,
    )

    data = models.JSONField(
        default=dict,
        blank=True,
    )

    is_read = models.BooleanField(
        default=False,
        db_index=True,
    )

    read_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
        db_index=True,
    )

    class Meta:
        db_table = "notifications"
        ordering = ["-created_at"]

        indexes = [
            models.Index(
                fields=[
                    "firm",
                    "recipient",
                    "is_read",
                ]
            ),
        ]

    def __str__(self):
        return f"{self.notification_type}: {self.title}"