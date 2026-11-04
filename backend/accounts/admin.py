from django.contrib import admin

from .models import (
    Permission,
    Role,
    RolePermission,
    User,
    UserRole,
)


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = (
        "email",
        "user_type",
        "firm",
        "is_active",
        "is_staff",
        "date_joined",
    )

    list_filter = (
        "user_type",
        "is_active",
        "is_staff",
    )

    search_fields = (
        "email",
        "first_name",
        "last_name",
        "phone",
    )

    readonly_fields = (
        "uuid",
        "date_joined",
        "updated_at",
        "last_login",
    )


@admin.register(Role)
class RoleAdmin(admin.ModelAdmin):
    list_display = (
        "name",
        "code",
        "firm",
        "is_system_role",
        "is_active",
    )

    search_fields = (
        "name",
        "code",
    )


@admin.register(Permission)
class PermissionAdmin(admin.ModelAdmin):
    list_display = (
        "code",
        "name",
        "created_at",
    )

    search_fields = (
        "code",
        "name",
    )


@admin.register(UserRole)
class UserRoleAdmin(admin.ModelAdmin):
    list_display = (
        "user",
        "role",
        "created_at",
    )


@admin.register(RolePermission)
class RolePermissionAdmin(admin.ModelAdmin):
    list_display = (
        "role",
        "permission",
        "created_at",
    )
    
    
    