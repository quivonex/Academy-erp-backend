from django.contrib import admin

from .models import User


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

    