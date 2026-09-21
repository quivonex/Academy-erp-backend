import uuid
from django.db import models

from firms.models import Firm
from courses.models import Course, Subject, Chapter, Lesson
from teachers.models import Teacher


class LiveClass(models.Model):

    class Status(models.TextChoices):
        SCHEDULED = "SCHEDULED", "Scheduled"
        LIVE = "LIVE", "Live"
        COMPLETED = "COMPLETED", "Completed"
        CANCELLED = "CANCELLED", "Cancelled"

    uuid = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
        db_index=True,
    )

    firm = models.ForeignKey(
        Firm,
        on_delete=models.PROTECT,
        related_name="live_classes",
    )

    course = models.ForeignKey(
        Course,
        on_delete=models.PROTECT,
        related_name="live_classes",
    )

    subject = models.ForeignKey(
        Subject,
        on_delete=models.PROTECT,
        related_name="live_classes",
        null=True,
        blank=True,
    )

    chapter = models.ForeignKey(
        Chapter,
        on_delete=models.SET_NULL,
        related_name="live_classes",
        null=True,
        blank=True,
    )

    lesson = models.ForeignKey(
        Lesson,
        on_delete=models.SET_NULL,
        related_name="live_classes",
        null=True,
        blank=True,
    )

    teacher = models.ForeignKey(
        Teacher,
        on_delete=models.PROTECT,
        related_name="live_classes",
    )

    title = models.CharField(max_length=255)

    description = models.TextField(blank=True)

    scheduled_start_at = models.DateTimeField(
        db_index=True,
    )

    scheduled_end_at = models.DateTimeField()

    actual_start_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    actual_end_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    meeting_url = models.URLField(
        max_length=1000,
        blank=True,
    )

    meeting_id = models.CharField(
        max_length=255,
        blank=True,
    )

    meeting_password = models.CharField(
        max_length=255,
        blank=True,
    )

    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.SCHEDULED,
        db_index=True,
    )

    is_active = models.BooleanField(
        default=True,
        db_index=True,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    class Meta:
        db_table = "live_classes"
        ordering = ["scheduled_start_at"]

        indexes = [
            models.Index(
                fields=["firm", "course", "status"]
            ),
            models.Index(
                fields=["firm", "scheduled_start_at"]
            ),
        ]

    def __str__(self):
        return f"{self.title} - {self.course.name}"
    
    