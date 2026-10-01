import os

from rest_framework import serializers

from .models import CoursePayment


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
    
    
    
    
