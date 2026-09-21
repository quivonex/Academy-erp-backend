import uuid

from django.db import models

from firms.models import Firm
from courses.models import Course, Subject, Chapter, Lesson
from classes.models import LiveClass


class LearningMaterial(models.Model):

    class MaterialType(models.TextChoices):
        VIDEO = "VIDEO", "Video"
        PDF = "PDF", "PDF"
        DOCUMENT = "DOCUMENT", "Document"
        LINK = "LINK", "Link"

    class Source(models.TextChoices):
        LIVE_CLASS_RECORDING = (
            "LIVE_CLASS_RECORDING",
            "Live Class Recording",
        )
        DIRECT_UPLOAD = (
            "DIRECT_UPLOAD",
            "Direct Upload",
        )

    uuid = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
        db_index=True,
    )

    firm = models.ForeignKey(
        Firm,
        on_delete=models.PROTECT,
        related_name="learning_materials",
    )

    course = models.ForeignKey(
        Course,
        on_delete=models.PROTECT,
        related_name="learning_materials",
    )

    subject = models.ForeignKey(
        Subject,
        on_delete=models.SET_NULL,
        related_name="learning_materials",
        null=True,
        blank=True,
    )

    chapter = models.ForeignKey(
        Chapter,
        on_delete=models.SET_NULL,
        related_name="learning_materials",
        null=True,
        blank=True,
    )

    lesson = models.ForeignKey(
        Lesson,
        on_delete=models.SET_NULL,
        related_name="learning_materials",
        null=True,
        blank=True,
    )

    live_class = models.ForeignKey(
        LiveClass,
        on_delete=models.SET_NULL,
        related_name="recordings",
        null=True,
        blank=True,
    )

    title = models.CharField(
        max_length=255,
    )

    description = models.TextField(
        blank=True,
    )

    material_type = models.CharField(
        max_length=20,
        choices=MaterialType.choices,
        db_index=True,
    )

    source = models.CharField(
        max_length=30,
        choices=Source.choices,
        default=Source.DIRECT_UPLOAD,
        db_index=True,
    )

    file_key = models.CharField(
        max_length=1000,
        blank=True,
    )

    external_url = models.URLField(
        max_length=1000,
        blank=True,
    )

    duration_seconds = models.PositiveIntegerField(
        null=True,
        blank=True,
    )

    sequence = models.PositiveIntegerField(
        default=1,
    )

    available_from = models.DateTimeField(
        null=True,
        blank=True,
        db_index=True,
    )

    available_until = models.DateTimeField(
        null=True,
        blank=True,
        db_index=True,
    )

    is_required = models.BooleanField(
        default=True,
    )

    counts_toward_progress = models.BooleanField(
        default=True,
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
        db_table = "learning_materials"

        ordering = [
            "sequence",
            "created_at",
        ]

        indexes = [
            models.Index(
                fields=[
                    "firm",
                    "course",
                    "is_active",
                ]
            ),
        ]

    def __str__(self):
        return f"{self.title} - {self.course.name}"
    
    