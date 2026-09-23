import uuid

from django.db import models

from firms.models import Firm
from students.models import Student
from courses.models import Course
from materials.models import LearningMaterial


class StudentMaterialProgress(models.Model):
    uuid = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
        db_index=True,
    )

    firm = models.ForeignKey(
        Firm,
        on_delete=models.PROTECT,
        related_name="material_progress_records",
    )

    student = models.ForeignKey(
        Student,
        on_delete=models.CASCADE,
        related_name="material_progress_records",
    )

    course = models.ForeignKey(
        Course,
        on_delete=models.PROTECT,
        related_name="student_material_progress",
    )

    material = models.ForeignKey(
        LearningMaterial,
        on_delete=models.CASCADE,
        related_name="student_progress",
    )

    watched_seconds = models.PositiveIntegerField(
        default=0,
    )

    last_position_seconds = models.PositiveIntegerField(
        default=0,
    )

    completion_percentage = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=0,
    )

    is_completed = models.BooleanField(
        default=False,
        db_index=True,
    )

    started_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    completed_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    last_accessed_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    class Meta:
        db_table = "student_material_progress"

        constraints = [
            models.UniqueConstraint(
                fields=[
                    "student",
                    "material",
                ],
                name="unique_student_material_progress",
            )
        ]

        indexes = [
            models.Index(
                fields=[
                    "firm",
                    "student",
                    "course",
                ]
            ),
        ]

    def __str__(self):
        return (
            f"{self.student} - "
            f"{self.material.title}"
        )
        
        
