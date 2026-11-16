from django.contrib import admin

from .models import (
    CoursePayment,
    EnrollmentFeeAccount,
    InstallmentPayment,
    InstallmentPaymentReceipt,
)


@admin.register(CoursePayment)
class CoursePaymentAdmin(admin.ModelAdmin):
    list_display = (
        "student",
        "course",
        "firm",
        "amount",
        "payment_method",
        "status",
        "created_at",
        "reviewed_at",
    )
    list_filter = ("status", "payment_method", "firm")
    search_fields = (
        "student__first_name",
        "student__last_name",
        "utr_number",
    )
    readonly_fields = ("uuid", "created_at", "updated_at")


@admin.register(EnrollmentFeeAccount)
class EnrollmentFeeAccountAdmin(admin.ModelAdmin):
    list_display = (
        "enrollment",
        "firm",
        "total_amount",
        "discount_amount",
        "paid_amount",
        "balance_amount",
        "status",
    )
    list_filter = ("status", "firm")
    readonly_fields = ("uuid", "created_at", "updated_at")


@admin.register(InstallmentPayment)
class InstallmentPaymentAdmin(admin.ModelAdmin):
    list_display = (
        "fee_account",
        "firm",
        "amount",
        "payment_method",
        "payment_date",
        "status",
    )
    list_filter = ("status", "payment_method", "firm")
    readonly_fields = ("uuid", "created_at", "updated_at")


@admin.register(InstallmentPaymentReceipt)
class InstallmentPaymentReceiptAdmin(admin.ModelAdmin):
    list_display = (
        "receipt_number",
        "firm",
        "student_name",
        "course_name",
        "paid_amount",
        "is_voided",
    )
    list_filter = ("is_voided", "firm")
    search_fields = ("receipt_number", "student_name")
    readonly_fields = ("uuid", "created_at", "updated_at")
