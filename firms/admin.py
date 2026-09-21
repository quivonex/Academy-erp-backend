from django.contrib import admin

from .models import Firm


@admin.register(Firm)
class FirmAdmin(admin.ModelAdmin):
    list_display = (
        "name",
        "code",
        "email",
        "status",
        "is_active",
        "created_at",
    )

    list_filter = (
        "status",
        "is_active",
    )

    search_fields = (
        "name",
        "code",
        "email",
        "phone",
    )

    readonly_fields = (
        "uuid",
        "created_at",
        "updated_at",
    )
    
    
    