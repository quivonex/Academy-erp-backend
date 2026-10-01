import os
from decimal import Decimal
from rest_framework import serializers

from .models import (
    CoursePayment,
    EnrollmentFeeAccount,
    InstallmentPayment,
)


class CoursePaymentSerializer(
    serializers.ModelSerializer
):
    student_uuid = serializers.UUIDField(
        source="student.uuid",
        read_only=True,
    )

    student_name = serializers.CharField(
        source="student.full_name",
        read_only=True,
    )

    course_uuid = serializers.UUIDField(
        source="course.uuid",
        read_only=True,
    )

    course_name = serializers.CharField(
        source="course.name",
        read_only=True,
    )

    course_code = serializers.CharField(
        source="course.code",
        read_only=True,
    )

    reviewed_by_name = serializers.CharField(
        source="reviewed_by.full_name",
        read_only=True,
        allow_null=True,
    )

    class Meta:
        model = CoursePayment

        fields = (
            "uuid",
            "student_uuid",
            "student_name",
            "course_uuid",
            "course_name",
            "course_code",
            "amount",
            "payment_method",
            "utr_number",
            "payment_screenshot_key",
            "status",
            "student_note",
            "admin_note",
            "reviewed_by_name",
            "reviewed_at",
            "created_at",
            "updated_at",
        )

        read_only_fields = fields


class StudentCoursePaymentCreateSerializer(
    serializers.Serializer
):
    course_uuid = serializers.UUIDField()

    payment_method = serializers.ChoiceField(
        choices=CoursePayment.PaymentMethod.choices,
        default=CoursePayment.PaymentMethod.UPI,
    )

    utr_number = serializers.CharField(
        max_length=100,
        required=False,
        allow_blank=True,
    )

    payment_screenshot = serializers.FileField(
        required=False,
    )

    student_note = serializers.CharField(
        required=False,
        allow_blank=True,
    )

    allowed_extensions = {
        ".pdf",
        ".jpg",
        ".jpeg",
        ".png",
    }

    max_file_size = 10 * 1024 * 1024

    def validate_payment_screenshot(self, value):
        if value.size > self.max_file_size:
            raise serializers.ValidationError(
                "Payment proof must not exceed 10 MB."
            )

        extension = os.path.splitext(
            value.name.lower()
        )[1]

        if extension not in self.allowed_extensions:
            raise serializers.ValidationError(
                (
                    "Only PDF, JPG, JPEG and PNG "
                    "files are allowed."
                )
            )

        if extension == ".pdf":
            current_position = value.tell()

            value.seek(0)
            file_header = value.read(5)
            value.seek(current_position)

            if file_header != b"%PDF-":
                raise serializers.ValidationError(
                    "Uploaded file is not a valid PDF."
                )

        return value

    def validate(self, attrs):
        payment_method = attrs.get(
            "payment_method"
        )

        utr_number = (
            attrs.get("utr_number", "")
            .strip()
        )

        payment_screenshot = attrs.get(
            "payment_screenshot"
        )

        if payment_method in [
            CoursePayment.PaymentMethod.UPI,
            CoursePayment.PaymentMethod.BANK_TRANSFER,
        ]:
            if not utr_number:
                raise serializers.ValidationError({
                    "utr_number": [
                        (
                            "UTR or transaction reference "
                            "number is required."
                        )
                    ]
                })

            if not payment_screenshot:
                raise serializers.ValidationError({
                    "payment_screenshot": [
                        (
                            "Payment proof screenshot or "
                            "receipt is required."
                        )
                    ]
                })

        attrs["utr_number"] = utr_number

        return attrs
    
    
class CoursePaymentReviewSerializer(
    serializers.Serializer
):
    status = serializers.ChoiceField(
        choices=[
            CoursePayment.Status.APPROVED,
            CoursePayment.Status.REJECTED,
        ]
    )

    admin_note = serializers.CharField(
        required=False,
        allow_blank=True,
    )
    
    
    
class EnrollmentFeeAccountSerializer(
    serializers.ModelSerializer
):
    enrollment_uuid = serializers.UUIDField(
        source="enrollment.uuid",
        read_only=True,
    )

    student_uuid = serializers.UUIDField(
        source="enrollment.student.uuid",
        read_only=True,
    )

    student_name = serializers.CharField(
        source="enrollment.student.full_name",
        read_only=True,
    )

    admission_number = serializers.CharField(
        source="enrollment.student.admission_number",
        read_only=True,
    )

    course_uuid = serializers.UUIDField(
        source="enrollment.course.uuid",
        read_only=True,
    )

    course_name = serializers.CharField(
        source="enrollment.course.name",
        read_only=True,
    )

    course_code = serializers.CharField(
        source="enrollment.course.code",
        read_only=True,
    )

    created_by_name = serializers.CharField(
        source="created_by.full_name",
        read_only=True,
        allow_null=True,
    )

    class Meta:
        model = EnrollmentFeeAccount

        fields = (
            "uuid",
            "enrollment_uuid",
            "student_uuid",
            "student_name",
            "admission_number",
            "course_uuid",
            "course_name",
            "course_code",
            "total_amount",
            "discount_amount",
            "paid_amount",
            "balance_amount",
            "due_date",
            "status",
            "notes",
            "created_by_name",
            "created_at",
            "updated_at",
        )

        read_only_fields = fields


class EnrollmentFeeAccountCreateSerializer(
    serializers.Serializer
):
    enrollment_uuid = serializers.UUIDField()

    total_amount = serializers.DecimalField(
        max_digits=10,
        decimal_places=2,
        min_value=Decimal("0.01"),
    )

    discount_amount = serializers.DecimalField(
        max_digits=10,
        decimal_places=2,
        min_value=Decimal("0.00"),
        required=False,
        default=0,
    )

    due_date = serializers.DateField(
        required=False,
        allow_null=True,
    )

    notes = serializers.CharField(
        required=False,
        allow_blank=True,
    )

    def validate(self, attrs):
        total_amount = attrs["total_amount"]
        discount_amount = attrs["discount_amount"]

        if discount_amount >= total_amount:
            raise serializers.ValidationError({
                "discount_amount": [
                    (
                        "Discount amount must be less "
                        "than total amount."
                    )
                ]
            })

        return attrs


class InstallmentPaymentSerializer(
    serializers.ModelSerializer
):
    fee_account_uuid = serializers.UUIDField(
        source="fee_account.uuid",
        read_only=True,
    )

    student_name = serializers.CharField(
        source="fee_account.enrollment.student.full_name",
        read_only=True,
    )

    admission_number = serializers.CharField(
        source=(
            "fee_account.enrollment.student."
            "admission_number"
        ),
        read_only=True,
    )

    course_name = serializers.CharField(
        source="fee_account.enrollment.course.name",
        read_only=True,
    )

    recorded_by_name = serializers.CharField(
        source="recorded_by.full_name",
        read_only=True,
        allow_null=True,
    )

    voided_by_name = serializers.CharField(
        source="voided_by.full_name",
        read_only=True,
        allow_null=True,
    )

    class Meta:
        model = InstallmentPayment

        fields = (
            "uuid",
            "fee_account_uuid",
            "student_name",
            "admission_number",
            "course_name",
            "amount",
            "payment_method",
            "transaction_reference",
            "payment_date",
            "notes",
            "status",
            "recorded_by_name",
            "voided_by_name",
            "voided_at",
            "void_reason",
            "created_at",
            "updated_at",
        )

        read_only_fields = fields


class InstallmentPaymentCreateSerializer(
    serializers.Serializer
):
    fee_account_uuid = serializers.UUIDField()

    amount = serializers.DecimalField(
        max_digits=10,
        decimal_places=2,
        min_value=0.01,
    )

    payment_method = serializers.ChoiceField(
        choices=InstallmentPayment.PaymentMethod.choices,
    )

    transaction_reference = serializers.CharField(
        required=False,
        allow_blank=True,
        max_length=100,
    )

    payment_date = serializers.DateField(
        required=False,
    )

    notes = serializers.CharField(
        required=False,
        allow_blank=True,
    )


class InstallmentPaymentVoidSerializer(
    serializers.Serializer
):
    void_reason = serializers.CharField(
        min_length=3,
        max_length=1000,
    )
