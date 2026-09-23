import uuid

from django.conf import settings
from django.db import models

from firms.models import Firm
from courses.models import (
    Course,
    Subject,
    Chapter,
    Lesson,
)
from students.models import Student


class Assignment(models.Model):

    uuid = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
        db_index=True,
    )

    firm = models.ForeignKey(
        Firm,
        on_delete=models.PROTECT,
        related_name="assignments",
    )

    course = models.ForeignKey(
        Course,
        on_delete=models.PROTECT,
        related_name="assignments",
    )

    subject = models.ForeignKey(
        Subject,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="assignments",
    )

    chapter = models.ForeignKey(
        Chapter,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="assignments",
    )

    lesson = models.ForeignKey(
        Lesson,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="assignments",
    )

    title = models.CharField(
        max_length=255,
    )

    description = models.TextField(
        blank=True,
    )

    instructions = models.TextField(
        blank=True,
    )

    max_marks = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        default=0,
    )

    due_at = models.DateTimeField(
        null=True,
        blank=True,
        db_index=True,
    )

    allow_late_submission = models.BooleanField(
        default=False,
    )

    is_published = models.BooleanField(
        default=False,
        db_index=True,
    )

    is_active = models.BooleanField(
        default=True,
        db_index=True,
    )

    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="created_assignments",
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    class Meta:
        db_table = "assignments"

        ordering = [
            "-created_at",
        ]

        indexes = [
            models.Index(
                fields=[
                    "firm",
                    "course",
                    "is_active",
                    "is_published",
                ]
            ),
        ]

    def __str__(self):
        return self.title


class AssignmentQuestion(models.Model):

    class AnswerType(models.TextChoices):
        TEXT = "TEXT", "Text"
        FILE = "FILE", "File"

    uuid = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
        db_index=True,
    )

    assignment = models.ForeignKey(
        Assignment,
        on_delete=models.CASCADE,
        related_name="questions",
    )

    question_text = models.TextField()

    answer_type = models.CharField(
        max_length=20,
        choices=AnswerType.choices,
        default=AnswerType.TEXT,
    )

    marks = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        default=0,
    )

    sequence = models.PositiveIntegerField(
        default=1,
    )

    is_required = models.BooleanField(
        default=True,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    class Meta:
        db_table = "assignment_questions"

        ordering = [
            "sequence",
            "created_at",
        ]

    def __str__(self):
        return self.question_text[:80]


class AssignmentSubmission(models.Model):

    class Status(models.TextChoices):
        DRAFT = "DRAFT", "Draft"
        SUBMITTED = "SUBMITTED", "Submitted"
        GRADED = "GRADED", "Graded"

    uuid = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
        db_index=True,
    )

    firm = models.ForeignKey(
        Firm,
        on_delete=models.PROTECT,
        related_name="assignment_submissions",
    )

    assignment = models.ForeignKey(
        Assignment,
        on_delete=models.PROTECT,
        related_name="submissions",
    )

    student = models.ForeignKey(
        Student,
        on_delete=models.PROTECT,
        related_name="assignment_submissions",
    )

    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.DRAFT,
        db_index=True,
    )

    submitted_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    total_marks_obtained = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        null=True,
        blank=True,
    )

    feedback = models.TextField(
        blank=True,
    )

    graded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="graded_assignment_submissions",
    )

    graded_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    class Meta:
        db_table = "assignment_submissions"

        constraints = [
            models.UniqueConstraint(
                fields=[
                    "assignment",
                    "student",
                ],
                name="unique_assignment_student_submission",
            )
        ]

    def __str__(self):
        return (
            f"{self.assignment.title} - "
            f"{self.student}"
        )


class AssignmentAnswer(models.Model):

    uuid = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
        db_index=True,
    )

    submission = models.ForeignKey(
        AssignmentSubmission,
        on_delete=models.CASCADE,
        related_name="answers",
    )

    question = models.ForeignKey(
        AssignmentQuestion,
        on_delete=models.PROTECT,
        related_name="answers",
    )

    text_answer = models.TextField(
        blank=True,
    )

    file_key = models.CharField(
        max_length=1000,
        blank=True,
    )

    marks_obtained = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        null=True,
        blank=True,
    )

    feedback = models.TextField(
        blank=True,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    class Meta:
        db_table = "assignment_answers"

        constraints = [
            models.UniqueConstraint(
                fields=[
                    "submission",
                    "question",
                ],
                name="unique_submission_question_answer",
            )
        ]

    def __str__(self):
        return str(self.uuid)
    
    