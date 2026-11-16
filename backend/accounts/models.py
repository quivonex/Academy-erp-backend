import uuid

from django.contrib.auth.models import AbstractBaseUser
from django.contrib.auth.models import PermissionsMixin
from django.db import models

from firms.models import Firm

from .managers import UserManager


class User(AbstractBaseUser, PermissionsMixin):

    class UserType(models.TextChoices):
        SUPER_ADMIN = "SUPER_ADMIN", "Super Admin"
        FIRM_ADMIN = "FIRM_ADMIN", "Firm Admin"
        FIRM_STAFF = "FIRM_STAFF", "Firm Staff"
        TEACHER = "TEACHER", "Teacher"
        STUDENT = "STUDENT", "Student"

    uuid = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
        db_index=True,
    )

    firm = models.ForeignKey(
        Firm,
        on_delete=models.PROTECT,
        related_name="users",
        null=True,
        blank=True,
    )

    email = models.EmailField(
        unique=True,
        db_index=True,
    )

    first_name = models.CharField(
        max_length=100,
        blank=True,
    )

    last_name = models.CharField(
        max_length=100,
        blank=True,
    )

    phone = models.CharField(
        max_length=20,
        blank=True,
        db_index=True,
    )

    user_type = models.CharField(
        max_length=20,
        choices=UserType.choices,
        db_index=True,
    )

    is_active = models.BooleanField(
        default=True,
        db_index=True,
    )
    
    auth_version = models.PositiveIntegerField(
        default=1,
    )
        
    is_staff = models.BooleanField(
        default=False,
    )

    date_joined = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    objects = UserManager()

    USERNAME_FIELD = "email"

    REQUIRED_FIELDS = []

    class Meta:
        db_table = "users"
        ordering = ["-date_joined"]
        indexes = [
            models.Index(fields=["firm", "user_type"]),
            models.Index(fields=["firm", "is_active"]),
        ]

    def __str__(self):
        return self.email

    @property
    def full_name(self):
        return f"{self.first_name} {self.last_name}".strip()
    
    
    
class PasswordResetOTP(models.Model):

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="password_reset_otps",
    )

    otp_hash = models.CharField(
        max_length=128,
    )

    expires_at = models.DateTimeField()

    used_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    attempts = models.PositiveSmallIntegerField(
        default=0,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    class Meta:
        db_table = "password_reset_otps"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["user", "expires_at"]),
        ]

    def __str__(self):
        return f"Password reset OTP for {self.user.email}"
    


    