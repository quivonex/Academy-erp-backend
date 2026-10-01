import os
import uuid
from django.utils import timezone
from django.core.files.storage import default_storage
from django.db import transaction

from rest_framework.exceptions import ValidationError

from courses.models import Course
from students.models import Student

from .models import CoursePayment


@transaction.atomic
def create_course_payment(
    *,
    user,
    validated_data,
):
    try:
        student = Student.objects.select_related(
            "firm"
        ).get(
            user=user,
            firm=user.firm,
            is_active=True,
        )
    
    except Student.DoesNotExist:
        raise ValidationError({
            "student": [
                "Active student profile was not found."
            ]
        })

    course_uuid = validated_data.pop(
        "course_uuid"
    )

    payment_screenshot = validated_data.pop(
        "payment_screenshot",
        None,
    )

    try:
        course = Course.objects.get(
            uuid=course_uuid,
            firm=user.firm,
            is_active=True,
            is_published=True,
            is_purchasable_online=True,
        )

    except Course.DoesNotExist:
        raise ValidationError({
            "course_uuid": [
                "Course was not found or is not available for online payment."
            ]
        })

    if course.price <= 0:
        raise ValidationError({
            "course_uuid": [
                (
                    "This course does not require "
                    "an online payment."
                )
            ]
        })

    existing_approved_payment = (
        CoursePayment.objects
        .filter(
            firm=user.firm,
            student=student,
            course=course,
            status=CoursePayment.Status.APPROVED,
        )
        .exists()
    )

    if existing_approved_payment:
        raise ValidationError({
            "course_uuid": [
                (
                    "Your payment for this course "
                    "is already approved."
                )
            ]
        })

    existing_pending_payment = (
        CoursePayment.objects
        .filter(
            firm=user.firm,
            student=student,
            course=course,
            status=CoursePayment.Status.PENDING,
        )
        .exists()
    )

    if existing_pending_payment:
        raise ValidationError({
            "course_uuid": [
                (
                    "A payment verification request "
                    "for this course is already pending."
                )
            ]
        })

    payment_method = validated_data.get(
        "payment_method"
    )

    utr_number = (
        validated_data.get(
            "utr_number",
            "",
        )
        .strip()
    )

    if utr_number:
        utr_already_used = (
            CoursePayment.objects
            .filter(
                firm=user.firm,
                utr_number=utr_number,
            )
            .exists()
        )

        if utr_already_used:
            raise ValidationError({
                "utr_number": [
                    (
                        "This UTR or transaction "
                        "reference is already used."
                    )
                ]
            })

    payment_screenshot_key = ""

    if payment_screenshot:
        extension = os.path.splitext(
            payment_screenshot.name.lower()
        )[1]

        storage_path = (
            f"course_payments/"
            f"{user.firm.uuid}/"
            f"{student.uuid}/"
            f"{course.uuid}/"
            f"{uuid.uuid4().hex}{extension}"
        )

        payment_screenshot_key = (
            default_storage.save(
                storage_path,
                payment_screenshot,
            )
        )

    payment = CoursePayment.objects.create(
        firm=user.firm,
        student=student,
        course=course,
        amount=course.price,
        payment_method=payment_method,
        utr_number=utr_number or None,
        payment_screenshot_key=payment_screenshot_key,
        student_note=validated_data.get(
            "student_note",
            "",
        ),
        status=CoursePayment.Status.PENDING,
    )

    return payment

@transaction.atomic
def review_course_payment(*, firm, reviewed_by, payment_uuid, validated_data):
    try:
        payment = (
            CoursePayment.objects
            .select_for_update()
            .select_related("student", "course")
            .get(uuid=payment_uuid, firm=firm)
        )
    except CoursePayment.DoesNotExist:
        raise ValidationError({
            "payment_uuid": ["Payment request was not found."]
        })

    if payment.status != CoursePayment.Status.PENDING:
        raise ValidationError({
            "payment": ["Only pending payment requests can be reviewed."]
        })

    payment.status = validated_data["status"]
    payment.admin_note = validated_data.get("admin_note", "")
    payment.reviewed_by = reviewed_by
    payment.reviewed_at = timezone.now()

    payment.save(update_fields=[
        "status",
        "admin_note",
        "reviewed_by",
        "reviewed_at",
        "updated_at",
    ])

    return payment

