from django.contrib import admin

from .models import (
    Chapter,
    Course,
    CourseCategory,
    Enrollment,
    Lesson,
    Subject,
)


@admin.register(CourseCategory)
class CourseCategoryAdmin(admin.ModelAdmin):
    list_display = (
        "name",
        "firm",
        "is_active",
        "created_at",
    )

    list_filter = (
        "firm",
        "is_active",
    )

    search_fields = ("name",)


@admin.register(Course)
class CourseAdmin(admin.ModelAdmin):
    list_display = (
        "name",
        "code",
        "firm",
        "category",
        "duration_months",
        "is_active",
    )

    list_filter = (
        "firm",
        "is_active",
    )

    search_fields = (
        "name",
        "code",
    )


@admin.register(Subject)
class SubjectAdmin(admin.ModelAdmin):
    list_display = (
        "name",
        "course",
        "teacher",
        "firm",
        "is_active",
    )

    list_filter = (
        "firm",
        "is_active",
    )

    search_fields = (
        "name",
        "code",
    )


@admin.register(Chapter)
class ChapterAdmin(admin.ModelAdmin):
    list_display = (
        "title",
        "subject",
        "sequence",
        "firm",
        "is_active",
    )


@admin.register(Lesson)
class LessonAdmin(admin.ModelAdmin):
    list_display = (
        "title",
        "chapter",
        "sequence",
        "firm",
        "is_active",
    )


@admin.register(Enrollment)
class EnrollmentAdmin(admin.ModelAdmin):
    list_display = (
        "student",
        "course",
        "firm",
        "status",
        "enrolled_at",
    )

    list_filter = (
        "firm",
        "status",
    )

    search_fields = (
        "student__first_name",
        "student__last_name",
        "student__admission_number",
        "course__name",
        "course__code",
    )
    
    
    