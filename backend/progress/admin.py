from django.contrib import admin

from .models import StudentMaterialProgress, StudentVideoWatchSession


@admin.register(StudentMaterialProgress)
class StudentMaterialProgressAdmin(admin.ModelAdmin):
    list_display = (
        "student",
        "material",
        "course",
        "watched_seconds",
        "verified_watched_seconds",
        "completion_percentage",
        "verified_completion_percentage",
        "is_completed",
        "is_verified_completed",
    )
    list_filter = ("firm", "is_completed", "is_verified_completed")
    search_fields = (
        "student__first_name",
        "student__last_name",
    )
    readonly_fields = ("uuid", "created_at", "updated_at")


@admin.register(StudentVideoWatchSession)
class StudentVideoWatchSessionAdmin(admin.ModelAdmin):
    list_display = (
        "student",
        "material",
        "is_active",
        "started_at",
        "ended_at",
        "last_heartbeat_at",
    )
    list_filter = ("is_active", "firm")
    readonly_fields = ("uuid", "started_at")
