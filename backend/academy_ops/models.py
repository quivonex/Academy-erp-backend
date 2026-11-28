import uuid
from django.conf import settings
from django.db import models


class TenantRecord(models.Model):
    uuid = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    firm = models.ForeignKey("firms.Firm", on_delete=models.PROTECT)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        abstract = True


class Batch(TenantRecord):
    course = models.ForeignKey("courses.Course", on_delete=models.PROTECT, related_name="batches")
    name = models.CharField(max_length=150)
    start_date = models.DateField()
    end_date = models.DateField()
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ["-start_date", "pk"]
        constraints = [
            models.UniqueConstraint(fields=["firm", "course", "name"], name="ops_unique_batch_name"),
            models.CheckConstraint(condition=models.Q(end_date__gte=models.F("start_date")), name="ops_batch_dates"),
        ]


class BatchMembership(TenantRecord):
    batch = models.ForeignKey(Batch, on_delete=models.PROTECT, related_name="memberships")
    enrollment = models.ForeignKey("courses.Enrollment", on_delete=models.PROTECT, related_name="batch_memberships")
    joined_on = models.DateField()
    left_on = models.DateField(null=True, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["batch", "enrollment"], name="ops_unique_batch_enrollment"),
        ]


class AttendanceSession(TenantRecord):
    batch = models.ForeignKey(Batch, on_delete=models.PROTECT, related_name="attendance_sessions")
    date = models.DateField()
    label = models.CharField(max_length=80, default="Daily")
    marked_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-date", "pk"]
        constraints = [models.UniqueConstraint(fields=["batch", "date", "label"], name="ops_unique_attendance_session")]


class AttendanceRecord(models.Model):
    class Status(models.TextChoices):
        PRESENT = "PRESENT", "Present"
        ABSENT = "ABSENT", "Absent"
        LATE = "LATE", "Late"
        LEAVE = "LEAVE", "Leave"

    session = models.ForeignKey(AttendanceSession, on_delete=models.PROTECT, related_name="records")
    membership = models.ForeignKey(BatchMembership, on_delete=models.PROTECT, related_name="attendance_records")
    status = models.CharField(max_length=10, choices=Status.choices)
    note = models.CharField(max_length=255, blank=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["session", "membership"], name="ops_unique_attendance_record")]


class EnrollmentRenewal(TenantRecord):
    """Audit of an expired access period before renewing its existing enrollment."""
    enrollment = models.ForeignKey("courses.Enrollment", on_delete=models.PROTECT, related_name="renewals")
    previous_start_at = models.DateTimeField(null=True)
    previous_end_at = models.DateTimeField(null=True)
    previous_status = models.CharField(max_length=20)
    renewed_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL)


class JobOpening(TenantRecord):
    title = models.CharField(max_length=200)
    company_name = models.CharField(max_length=200)
    description = models.TextField()
    eligibility = models.TextField(blank=True)
    location = models.CharField(max_length=255)
    application_deadline = models.DateTimeField()
    interview_at = models.DateTimeField(null=True, blank=True)
    interview_end_at = models.DateTimeField(null=True, blank=True)
    interview_venue = models.CharField(max_length=255, blank=True)
    interview_url = models.URLField(blank=True)
    is_published = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at", "pk"]


class JobApplication(TenantRecord):
    class Status(models.TextChoices):
        APPLIED = "APPLIED", "Applied"
        SHORTLISTED = "SHORTLISTED", "Shortlisted"
        INTERVIEW = "INTERVIEW", "Interview"
        SELECTED = "SELECTED", "Selected"
        REJECTED = "REJECTED", "Rejected"
        WITHDRAWN = "WITHDRAWN", "Withdrawn"

    opening = models.ForeignKey(JobOpening, on_delete=models.PROTECT, related_name="applications")
    student = models.ForeignKey("students.Student", on_delete=models.PROTECT, related_name="job_applications")
    cover_letter = models.TextField(blank=True)
    resume_url = models.URLField(blank=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.APPLIED)
    admin_note = models.TextField(blank=True)
    interview_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at", "pk"]
        constraints = [models.UniqueConstraint(fields=["opening", "student"], name="ops_unique_job_application")]
