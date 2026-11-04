from django.contrib import admin

from .models import (
    ParentGuardian,
    Student,
)


class ParentGuardianInline(admin.TabularInline):
    model = ParentGuardian
    extra = 0


@admin.register(Student)
class StudentAdmin(admin.ModelAdmin):
    list_display = (
        "admission_number",
        "first_name",
        "last_name",
        "firm",
        "phone",
        "is_active",
        "created_at",
    )

    list_filter = (
        "firm",
        "gender",
        "is_active",
    )

    search_fields = (
        "admission_number",
        "first_name",
        "last_name",
        "email",
        "phone",
    )

    readonly_fields = (
        "uuid",
        "created_at",
        "updated_at",
    )

    inlines = [
        ParentGuardianInline,
    ]


@admin.register(ParentGuardian)
class ParentGuardianAdmin(admin.ModelAdmin):
    list_display = (
        "name",
        "student",
        "relationship",
        "phone",
        "is_primary",
    )

    search_fields = (
        "name",
        "phone",
        "email",
    )
    
    