import uuid

from django.conf import settings
from django.db import models

from firms.models import Firm


class Teacher(models.Model):

    class Gender(models.TextChoices):
        MALE = "MALE", "Male"
        FEMALE = "FEMALE", "Female"
        OTHER = "OTHER", "Other"

    uuid = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
        db_index=True,
    )

    firm = models.ForeignKey(
        Firm,
        on_delete=models.PROTECT,
        related_name="teachers",
    )

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="teacher_profile",
        null=True,
        blank=True,
    )

    employee_id = models.CharField(
        max_length=50,
    )

    first_name = models.CharField(
        max_length=100,
    )

    last_name = models.CharField(
        max_length=100,
        blank=True,
    )

    email = models.EmailField(
        blank=True,
    )

    phone = models.CharField(
        max_length=20,
        blank=True,
    )

    gender = models.CharField(
        max_length=10,
        choices=Gender.choices,
        blank=True,
    )

    qualification = models.CharField(
        max_length=255,
        blank=True,
    )

    specialization = models.CharField(
        max_length=255,
        blank=True,
    )

    experience_years = models.PositiveIntegerField(
        default=0,
    )

    address = models.TextField(
        blank=True,
    )

    joined_date = models.DateField(
        null=True,
        blank=True,
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
        db_table = "teachers"
        ordering = ["-created_at"]

        constraints = [
            models.UniqueConstraint(
                fields=["firm", "employee_id"],
                name="unique_teacher_employee_per_firm",
            )
        ]

        indexes = [
            models.Index(
                fields=["firm", "is_active"]
            ),
            models.Index(
                fields=["firm", "first_name"]
            ),
        ]

    @property
    def full_name(self):
        return (
            f"{self.first_name} {self.last_name}"
        ).strip()

    def __str__(self):
        return (
            f"{self.full_name} "
            f"({self.employee_id})"
        )


class Staff(models.Model):

    uuid = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
        db_index=True,
    )

    firm = models.ForeignKey(
        Firm,
        on_delete=models.PROTECT,
        related_name="staff_members",
    )

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="staff_profile",
        null=True,
        blank=True,
    )

    employee_id = models.CharField(
        max_length=50,
    )

    first_name = models.CharField(
        max_length=100,
    )

    last_name = models.CharField(
        max_length=100,
        blank=True,
    )

    email = models.EmailField(
        blank=True,
    )

    phone = models.CharField(
        max_length=20,
        blank=True,
    )

    designation = models.CharField(
        max_length=150,
        blank=True,
    )

    department = models.CharField(
        max_length=150,
        blank=True,
    )

    address = models.TextField(
        blank=True,
    )

    joined_date = models.DateField(
        null=True,
        blank=True,
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
        db_table = "staff"
        ordering = ["-created_at"]

        constraints = [
            models.UniqueConstraint(
                fields=["firm", "employee_id"],
                name="unique_staff_employee_per_firm",
            )
        ]

        indexes = [
            models.Index(
                fields=["firm", "is_active"]
            )
        ]

    @property
    def full_name(self):
        return (
            f"{self.first_name} {self.last_name}"
        ).strip()

    def __str__(self):
        return (
            f"{self.full_name} "
            f"({self.employee_id})"
        )
        
        
