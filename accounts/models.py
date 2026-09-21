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
    
    
    
    
class Role(models.Model):

    uuid = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
    )

    firm = models.ForeignKey(
        Firm,
        on_delete=models.CASCADE,
        related_name="roles",
        null=True,
        blank=True,
    )

    name = models.CharField(
        max_length=100,
    )

    code = models.CharField(
        max_length=100,
        db_index=True,
    )

    description = models.TextField(
        blank=True,
    )

    is_system_role = models.BooleanField(
        default=False,
    )

    is_active = models.BooleanField(
        default=True,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    class Meta:
        db_table = "roles"
        constraints = [
            models.UniqueConstraint(
                fields=["firm", "code"],
                name="unique_role_code_per_firm",
            )
        ]

    def __str__(self):
        return self.name


class Permission(models.Model):

    uuid = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
    )

    code = models.CharField(
        max_length=150,
        unique=True,
        db_index=True,
    )

    name = models.CharField(
        max_length=150,
    )

    description = models.TextField(
        blank=True,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    def __str__(self):
        return self.code


class UserRole(models.Model):

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="assigned_roles",
    )

    role = models.ForeignKey(
        Role,
        on_delete=models.CASCADE,
        related_name="assigned_users",
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    class Meta:
        db_table = "user_roles"
        constraints = [
            models.UniqueConstraint(
                fields=["user", "role"],
                name="unique_user_role",
            )
        ]

    def __str__(self):
        return f"{self.user.email} - {self.role.name}"


class RolePermission(models.Model):

    role = models.ForeignKey(
        Role,
        on_delete=models.CASCADE,
        related_name="role_permissions",
    )

    permission = models.ForeignKey(
        Permission,
        on_delete=models.CASCADE,
        related_name="permission_roles",
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    class Meta:
        db_table = "role_permissions"
        constraints = [
            models.UniqueConstraint(
                fields=["role", "permission"],
                name="unique_role_permission",
            )
        ]

    def __str__(self):
        return f"{self.role.name} - {self.permission.code}"
    
    
    