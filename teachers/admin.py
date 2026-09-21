from django.contrib import admin

from .models import Staff, Teacher


@admin.register(Teacher)
class TeacherAdmin(admin.ModelAdmin):
    list_display = (
        "employee_id",
        "first_name",
        "last_name",
        "firm",
        "phone",
        "specialization",
        "is_active",
    )

    list_filter = (
        "firm",
        "gender",
        "is_active",
    )

    search_fields = (
        "employee_id",
        "first_name",
        "last_name",
        "email",
        "phone",
        "specialization",
    )

    readonly_fields = (
        "uuid",
        "created_at",
        "updated_at",
    )


@admin.register(Staff)
class StaffAdmin(admin.ModelAdmin):
    list_display = (
        "employee_id",
        "first_name",
        "last_name",
        "firm",
        "designation",
        "department",
        "is_active",
    )

    list_filter = (
        "firm",
        "department",
        "is_active",
    )

    search_fields = (
        "employee_id",
        "first_name",
        "last_name",
        "email",
        "phone",
        "designation",
        "department",
    )

    readonly_fields = (
        "uuid",
        "created_at",
        "updated_at",
    )
    
    
    