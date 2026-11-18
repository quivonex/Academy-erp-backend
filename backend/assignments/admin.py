from django.contrib import admin

from .models import (
    Assignment,
    AssignmentQuestion,
    AssignmentSubmission,
    AssignmentAnswer,
)


class AssignmentQuestionInline(admin.TabularInline):
    model = AssignmentQuestion
    extra = 0
    fields = (
        "question_text",
        "answer_type",
        "marks",
        "correct_option",
        "sequence",
    )


@admin.register(Assignment)
class AssignmentAdmin(admin.ModelAdmin):
    list_display = (
        "title",
        "firm",
        "course",
        "subject",
        "max_marks",
        "is_published",
        "due_at",
    )
    list_filter = ("firm", "is_published", "course")
    search_fields = ("title",)
    inlines = [AssignmentQuestionInline]
    readonly_fields = ("uuid", "created_at", "updated_at")


@admin.register(AssignmentQuestion)
class AssignmentQuestionAdmin(admin.ModelAdmin):
    list_display = (
        "question_text_short",
        "assignment",
        "answer_type",
        "marks",
        "sequence",
    )
    list_filter = ("answer_type",)
    readonly_fields = ("uuid", "created_at")

    def question_text_short(self, obj):
        return obj.question_text[:80] if obj.question_text else ""
    question_text_short.short_description = "Question"


@admin.register(AssignmentSubmission)
class AssignmentSubmissionAdmin(admin.ModelAdmin):
    list_display = (
        "student",
        "assignment",
        "status",
        "total_marks_obtained",
        "submitted_at",
    )
    list_filter = ("status", "firm")
    search_fields = (
        "student__first_name",
        "student__last_name",
    )
    readonly_fields = ("uuid", "created_at", "updated_at")


@admin.register(AssignmentAnswer)
class AssignmentAnswerAdmin(admin.ModelAdmin):
    list_display = (
        "submission",
        "question",
        "selected_option",
        "marks_obtained",
    )
    readonly_fields = ("uuid", "created_at", "updated_at")
