from django.contrib import admin

from .models import LiveClass


@admin.register(LiveClass)
class LiveClassAdmin(admin.ModelAdmin):
    list_display = (
        "title",
        "firm",
        "course",
        "teacher",
        "status",
        "scheduled_start_at",
        "scheduled_end_at",
    )
    list_filter = ("status", "firm", "course")
    search_fields = ("title",)
    readonly_fields = ("uuid", "created_at", "updated_at")
