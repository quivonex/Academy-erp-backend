from django.contrib import admin

from .models import LearningMaterial


@admin.register(LearningMaterial)
class LearningMaterialAdmin(admin.ModelAdmin):
    list_display = (
        "title",
        "firm",
        "course",
        "chapter",
        "material_type",
        "source",
        "is_active",
        "sequence",
    )
    list_filter = ("material_type", "source", "firm", "is_active")
    search_fields = ("title",)
    readonly_fields = ("uuid", "created_at", "updated_at")
