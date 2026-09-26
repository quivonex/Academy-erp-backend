from django.contrib import admin

from .models import HomeBanner


@admin.register(HomeBanner)
class HomeBannerAdmin(admin.ModelAdmin):
    list_display = (
        "title",
        "firm",
        "course",
        "display_order",
        "starts_at",
        "ends_at",
        "is_active",
    )
    list_filter = ("firm", "is_active")
    search_fields = ("title", "subtitle")
    ordering = ("display_order", "-created_at")
    
    
