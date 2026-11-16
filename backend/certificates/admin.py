from django.contrib import admin

from .models import CourseCompletionCertificate


@admin.register(CourseCompletionCertificate)
class CourseCompletionCertificateAdmin(admin.ModelAdmin):
    list_display = (
        "certificate_number",
        "student_name",
        "course_name",
        "firm",
        "achieved_watch_percentage",
        "is_revoked",
        "issued_at",
    )
    list_filter = ("is_revoked", "firm")
    search_fields = (
        "certificate_number",
        "student_name",
        "verification_code",
    )
    readonly_fields = (
        "uuid",
        "verification_code",
        "created_at",
        "updated_at",
    )
