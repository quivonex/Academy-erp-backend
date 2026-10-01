import uuid

from django.conf import settings
from django.db import models

from courses.models import Course
from firms.models import Firm
from students.models import Student


class CoursePayment(models.Model):

    class PaymentMethod(models.TextChoices):
        UPI = "UPI", "UPI"
        BANK_TRANSFER = "BANK_TRANSFER", "Bank Transfer"
        CASH = "CASH", "Cash"

    class Status(models.TextChoices):
        PENDING = "PENDING", "Pending Verification"
        APPROVED = "APPROVED", "Approved"
        REJECTED = "REJECTED", "Rejected"
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
        related_name="course_payments",
    )

    student = models.ForeignKey(
        Student,
        on_delete=models.PROTECT,
        related_name="course_payments",
    )

    course = models.ForeignKey(
        Course,
        on_delete=models.PROTECT,
        related_name="course_payments",
    )

    amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
    )

    payment_method = models.CharField(
        max_length=30,
        choices=PaymentMethod.choices,
        default=PaymentMethod.UPI,
    )

    utr_number = models.CharField(
        max_length=100,
        null=True,
        blank=True,
        db_index=True,
    )

    payment_screenshot_key = models.CharField(
        max_length=1000,
        blank=True,
    )

    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.PENDING,
        db_index=True,
    )

    student_note = models.TextField(
        blank=True,
    )

    admin_note = models.TextField(
        blank=True,
    )

    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="reviewed_course_payments",
    )

    reviewed_at = models.DateTimeField(
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
        db_table = "course_payments"

        ordering = [
            "-created_at",
        ]

        indexes = [
            models.Index(
                fields=[
                    "firm",
                    "student",
                    "course",
                    "status",
                ]
            ),
        ]

    def __str__(self):
        return (
            f"{self.student.full_name} - "
            f"{self.course.name} - "
            f"{self.status}"
        )
        
        