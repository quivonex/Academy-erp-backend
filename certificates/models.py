import uuid as uuid_lib

from django.db import models

from courses.models import Course, Enrollment
from firms.models import Firm
from students.models import Student


class CourseCompletionCertificate(models.Model):
    uuid = models.UUIDField(
        default=uuid_lib.uuid4,
        editable=False,
        unique=True,
        db_index=True,
    )

    firm = models.ForeignKey(
        Firm,
        on_delete=models.PROTECT,
        related_name="course_certificates",
    )

    enrollment = models.OneToOneField(
        Enrollment,
        on_delete=models.PROTECT,
        related_name="completion_certificate",
    )

    student = models.ForeignKey(
        Student,
        on_delete=models.PROTECT,
        related_name="course_certificates",
    )

    course = models.ForeignKey(
        Course,
        on_delete=models.PROTECT,
        related_name="completion_certificates",
    )

    certificate_number = models.CharField(
        max_length=100,
        unique=True,
        db_index=True,
    )

    verification_code = models.UUIDField(
        default=uuid_lib.uuid4,
        unique=True,
        editable=False,
        db_index=True,
    )

    required_watch_percentage = models.DecimalField(
        max_digits=5,
        decimal_places=2,
    )

    achieved_watch_percentage = models.DecimalField(
        max_digits=5,
        decimal_places=2,
    )

    student_name = models.CharField(
        max_length=255,
    )

    admission_number = models.CharField(
        max_length=100,
        blank=True,
    )

    course_name = models.CharField(
        max_length=255,
    )

    file_key = models.CharField(
        max_length=1000,
        blank=True,
    )

    issued_at = models.DateTimeField(
        auto_now_add=True,
    )

    is_revoked = models.BooleanField(
        default=False,
        db_index=True,
    )

    revoked_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    revoked_reason = models.TextField(
        blank=True,
    )

    class Meta:
        db_table = "course_completion_certificates"

        ordering = [
            "-issued_at",
        ]

        indexes = [
            models.Index(
                fields=[
                    "firm",
                    "student",
                    "course",
                ]
            ),
            models.Index(
                fields=[
                    "firm",
                    "is_revoked",
                ]
            ),
        ]

    def __str__(self):
        return self.certificate_number