import uuid

from django.db import models

from firms.models import Firm
from students.models import Student
from teachers.models import Teacher


class CourseCategory(models.Model):
    uuid = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
        db_index=True,
    )

    firm = models.ForeignKey(
        Firm,
        on_delete=models.PROTECT,
        related_name="course_categories",
    )

    name = models.CharField(max_length=150)

    description = models.TextField(blank=True)

    is_active = models.BooleanField(
        default=True,
        db_index=True,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    class Meta:
        db_table = "course_categories"
        ordering = ["name"]

        constraints = [
            models.UniqueConstraint(
                fields=["firm", "name"],
                name="unique_course_category_per_firm",
            )
        ]

    def __str__(self):
        return self.name


class Course(models.Model):
    class DeliveryMode(models.TextChoices):
        ONLINE = "ONLINE", "Online"
        OFFLINE = "OFFLINE", "Offline"
        HYBRID = "HYBRID", "Hybrid"
    
    uuid = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
        db_index=True,
    )

    firm = models.ForeignKey(
        Firm,
        on_delete=models.PROTECT,
        related_name="courses",
    )

    category = models.ForeignKey(
        CourseCategory,
        on_delete=models.SET_NULL,
        related_name="courses",
        null=True,
        blank=True,
    )

    name = models.CharField(max_length=200)

    code = models.CharField(max_length=50)

    description = models.TextField(blank=True)

    duration_months = models.PositiveIntegerField(
        null=True,
        blank=True,
    )
    
    price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
    )
    
    delivery_mode = models.CharField(
        max_length=20,
        choices=DeliveryMode.choices,
        default=DeliveryMode.ONLINE,
        db_index=True,
    )
    
    is_published = models.BooleanField(
        default=False,
        db_index=True,
    )
    
    is_purchasable_online = models.BooleanField(
        default=False,
        db_index=True,
    )
    
    access_duration_days = models.PositiveIntegerField(
        null=True,
        blank=True,
    )
    

    is_active = models.BooleanField(
        default=True,
        db_index=True,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    class Meta:
        db_table = "courses"
        ordering = ["name"]

        constraints = [
            models.UniqueConstraint(
                fields=["firm", "code"],
                name="unique_course_code_per_firm",
            )
        ]

        indexes = [
            models.Index(
                fields=["firm", "is_active"]
            )
        ]

    def __str__(self):
        return f"{self.name} ({self.code})"


class Subject(models.Model):
    uuid = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
        db_index=True,
    )

    firm = models.ForeignKey(
        Firm,
        on_delete=models.PROTECT,
        related_name="subjects",
    )

    course = models.ForeignKey(
        Course,
        on_delete=models.CASCADE,
        related_name="subjects",
    )

    teacher = models.ForeignKey(
        Teacher,
        on_delete=models.SET_NULL,
        related_name="subjects",
        null=True,
        blank=True,
    )

    name = models.CharField(max_length=200)

    code = models.CharField(
        max_length=50,
        blank=True,
    )

    description = models.TextField(blank=True)

    is_active = models.BooleanField(
        default=True,
        db_index=True,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    class Meta:
        db_table = "subjects"
        ordering = ["name"]

        constraints = [
            models.UniqueConstraint(
                fields=["course", "name"],
                name="unique_subject_name_per_course",
            )
        ]

        indexes = [
            models.Index(
                fields=["firm", "course"]
            )
        ]

    def __str__(self):
        return f"{self.name} - {self.course.name}"


class Chapter(models.Model):
    uuid = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
        db_index=True,
    )

    firm = models.ForeignKey(
        Firm,
        on_delete=models.PROTECT,
        related_name="chapters",
    )

    subject = models.ForeignKey(
        Subject,
        on_delete=models.CASCADE,
        related_name="chapters",
    )

    title = models.CharField(max_length=255)

    description = models.TextField(blank=True)

    sequence = models.PositiveIntegerField(
        default=1,
    )

    is_active = models.BooleanField(
        default=True,
        db_index=True,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    class Meta:
        db_table = "chapters"
        ordering = ["sequence", "created_at"]

        constraints = [
            models.UniqueConstraint(
                fields=["subject", "sequence"],
                name="unique_chapter_sequence_per_subject",
            )
        ]

    def __str__(self):
        return self.title


class Lesson(models.Model):
    uuid = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
        db_index=True,
    )

    firm = models.ForeignKey(
        Firm,
        on_delete=models.PROTECT,
        related_name="lessons",
    )

    chapter = models.ForeignKey(
        Chapter,
        on_delete=models.CASCADE,
        related_name="lessons",
    )

    title = models.CharField(max_length=255)

    description = models.TextField(blank=True)

    sequence = models.PositiveIntegerField(
        default=1,
    )

    is_active = models.BooleanField(
        default=True,
        db_index=True,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    class Meta:
        db_table = "lessons"
        ordering = ["sequence", "created_at"]

        constraints = [
            models.UniqueConstraint(
                fields=["chapter", "sequence"],
                name="unique_lesson_sequence_per_chapter",
            )
        ]

    def __str__(self):
        return self.title


class Enrollment(models.Model):

    class Status(models.TextChoices):
        ACTIVE = "ACTIVE", "Active"
        COMPLETED = "COMPLETED", "Completed"
        CANCELLED = "CANCELLED", "Cancelled"

    class Source(models.TextChoices):
        ONLINE_PURCHASE = "ONLINE_PURCHASE", "Online Purchase"
        FIRM_GRANTED = "FIRM_GRANTED", "Firm Granted"

    uuid = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
        db_index=True,
    )

    firm = models.ForeignKey(
        Firm,
        on_delete=models.PROTECT,
        related_name="enrollments",
    )

    student = models.ForeignKey(
        Student,
        on_delete=models.PROTECT,
        related_name="enrollments",
    )

    course = models.ForeignKey(
        Course,
        on_delete=models.PROTECT,
        related_name="enrollments",
    )

    source = models.CharField(
        max_length=30,
        choices=Source.choices,
        default=Source.FIRM_GRANTED,
        db_index=True,
    )

    granted_by = models.ForeignKey(
        "accounts.User",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="granted_enrollments",
    )

    access_start_at = models.DateTimeField(
        null=True,
        blank=True,
        db_index=True,
    )

    access_end_at = models.DateTimeField(
        null=True,
        blank=True,
        db_index=True,
    )

    enrolled_at = models.DateTimeField(
        auto_now_add=True,
    )

    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.ACTIVE,
        db_index=True,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    class Meta:
        db_table = "enrollments"
        constraints = [
            models.UniqueConstraint(
                fields=["student", "course"],
                name="unique_student_course_enrollment",
            )
        ]

    def __str__(self):
        return f"{self.student} - {self.course}"
    
    