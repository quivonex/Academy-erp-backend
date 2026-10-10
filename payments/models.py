import uuid

from django.conf import settings
from django.db import models
from django.utils import timezone
from courses.models import Course, Enrollment
from firms.models import Firm
from students.models import Student


class CoursePayment(models.Model):

    class PaymentMethod(models.TextChoices):
        UPI = "UPI", "UPI"
        BANK_TRANSFER = "BANK_TRANSFER", "Bank Transfer"
        CASH = "CASH", "Cash"

    class Status(models.TextChoices):
        PENDING = "PENDING", "Pending Verification"
        APPROVED = "APPROVED", "Approved"
        REJECTED = "REJECTED", "Rejected"
        CANCELLED = "CANCELLED", "Cancelled"

    uuid = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
        db_index=True,
    )

    firm = models.ForeignKey(
        Firm,
        on_delete=models.PROTECT,
        related_name="course_payments",
    )

    student = models.ForeignKey(
        Student,
        on_delete=models.PROTECT,
        related_name="course_payments",
    )

    course = models.ForeignKey(
        Course,
        on_delete=models.PROTECT,
        related_name="course_payments",
    )

    amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
    )

    payment_method = models.CharField(
        max_length=30,
        choices=PaymentMethod.choices,
        default=PaymentMethod.UPI,
    )

    utr_number = models.CharField(
        max_length=100,
        null=True,
        blank=True,
        db_index=True,
    )

    payment_screenshot_key = models.CharField(
        max_length=1000,
        blank=True,
    )

    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.PENDING,
        db_index=True,
    )

    student_note = models.TextField(
        blank=True,
    )

    admin_note = models.TextField(
        blank=True,
    )

    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="reviewed_course_payments",
    )

    reviewed_at = models.DateTimeField(
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
        db_table = "course_payments"

        ordering = [
            "-created_at",
        ]

        indexes = [
            models.Index(
                fields=[
                    "firm",
                    "student",
                    "course",
                    "status",
                ]
            ),
        ]

    def __str__(self):
        return (
            f"{self.student.full_name} - "
            f"{self.course.name} - "
            f"{self.status}"
        )
        
        
class EnrollmentFeeAccount(models.Model):

    class Status(models.TextChoices):
        UNPAID = "UNPAID", "Unpaid"
        PARTIALLY_PAID = "PARTIALLY_PAID", "Partially Paid"
        PAID = "PAID", "Paid"

    uuid = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
        db_index=True,
    )

    firm = models.ForeignKey(
        Firm,
        on_delete=models.PROTECT,
        related_name="fee_accounts",
    )

    enrollment = models.OneToOneField(
        Enrollment,
        on_delete=models.PROTECT,
        related_name="fee_account",
    )

    total_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
    )

    discount_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
    )

    paid_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
    )

    balance_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
    )

    due_date = models.DateField(
        null=True,
        blank=True,
    )

    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.UNPAID,
        db_index=True,
    )

    notes = models.TextField(
        blank=True,
    )

    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="created_fee_accounts",
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    class Meta:
        db_table = "enrollment_fee_accounts"
        ordering = ["-created_at"]
        indexes = [
            models.Index(
                fields=["firm", "status"],
            ),
        ]

    def __str__(self):
        return (
            f"{self.enrollment.student.full_name} - "
            f"{self.enrollment.course.name}"
        )


class InstallmentPayment(models.Model):

    class PaymentMethod(models.TextChoices):
        CASH = "CASH", "Cash"
        UPI = "UPI", "UPI"
        BANK_TRANSFER = "BANK_TRANSFER", "Bank Transfer"
        CARD = "CARD", "Card"
        OTHER = "OTHER", "Other"

    class Status(models.TextChoices):
        RECORDED = "RECORDED", "Recorded"
        VOIDED = "VOIDED", "Voided"

    uuid = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
        db_index=True,
    )

    firm = models.ForeignKey(
        Firm,
        on_delete=models.PROTECT,
        related_name="installment_payments",
    )

    fee_account = models.ForeignKey(
        EnrollmentFeeAccount,
        on_delete=models.PROTECT,
        related_name="installments",
    )

    amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
    )

    payment_method = models.CharField(
        max_length=30,
        choices=PaymentMethod.choices,
    )

    transaction_reference = models.CharField(
        max_length=100,
        blank=True,
    )

    payment_date = models.DateField(
        default=timezone.localdate,
    )

    notes = models.TextField(
        blank=True,
    )

    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.RECORDED,
        db_index=True,
    )

    recorded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="recorded_installment_payments",
    )

    voided_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="voided_installment_payments",
    )

    voided_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    void_reason = models.TextField(
        blank=True,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    class Meta:
        db_table = "installment_payments"
        ordering = ["-payment_date", "-created_at"]
        indexes = [
            models.Index(
                fields=["firm", "fee_account", "status"],
            ),
        ]

    def __str__(self):
        return (
            f"{self.fee_account.uuid} - "
            f"{self.amount} - {self.status}"
        )
        
        
        
class InstallmentPaymentReceipt(models.Model):
    uuid = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
        db_index=True,
    )

    firm = models.ForeignKey(
        Firm,
        on_delete=models.PROTECT,
        related_name="payment_receipts",
    )

    installment = models.OneToOneField(
        InstallmentPayment,
        on_delete=models.PROTECT,
        related_name="receipt",
    )

    receipt_number = models.CharField(
        max_length=100,
        unique=True,
        db_index=True,
    )

    student_name = models.CharField(
        max_length=255,
    )

    admission_number = models.CharField(
        max_length=100,
        blank=True,
    )

    course_name = models.CharField(
        max_length=255,
    )

    paid_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
    )

    balance_after_payment = models.DecimalField(
        max_digits=10,
        decimal_places=2,
    )

    payment_method = models.CharField(
        max_length=30,
    )

    transaction_reference = models.CharField(
        max_length=100,
        blank=True,
    )

    payment_date = models.DateField()

    file_key = models.CharField(
        max_length=1000,
        blank=True,
    )

    generated_at = models.DateTimeField(
        auto_now_add=True,
    )

    is_voided = models.BooleanField(
        default=False,
        db_index=True,
    )

    voided_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    void_reason = models.TextField(
        blank=True,
    )

    class Meta:
        db_table = "installment_payment_receipts"

        ordering = [
            "-payment_date",
            "-generated_at",
        ]

        indexes = [
            models.Index(
                fields=[
                    "firm",
                    "receipt_number",
                ]
            ),
            models.Index(
                fields=[
                    "firm",
                    "is_voided",
                ]
            ),
        ]

    def __str__(self):
        return self.receipt_number