import os
import uuid
from django.utils import timezone
from django.core.files.storage import default_storage
from decimal import Decimal
from rest_framework.exceptions import ValidationError
from django.db import models, transaction
from courses.models import Course, Enrollment
from students.models import Student

from .models import (
    CoursePayment,
    EnrollmentFeeAccount,
    InstallmentPayment,
)


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



def refresh_fee_account_summary(fee_account):
    payable_amount = (
        fee_account.total_amount
        - fee_account.discount_amount
    )

    paid_amount = (
        fee_account.installments
        .filter(
            status=InstallmentPayment.Status.RECORDED
        )
        .aggregate(total=models.Sum("amount"))
        .get("total")
        or Decimal("0.00")
    )

    balance_amount = payable_amount - paid_amount

    if balance_amount < Decimal("0.00"):
        balance_amount = Decimal("0.00")

    if paid_amount <= Decimal("0.00"):
        fee_status = EnrollmentFeeAccount.Status.UNPAID

    elif balance_amount <= Decimal("0.00"):
        fee_status = EnrollmentFeeAccount.Status.PAID

    else:
        fee_status = (
            EnrollmentFeeAccount.Status.PARTIALLY_PAID
        )

    fee_account.paid_amount = paid_amount
    fee_account.balance_amount = balance_amount
    fee_account.status = fee_status

    fee_account.save(
        update_fields=[
            "paid_amount",
            "balance_amount",
            "status",
            "updated_at",
        ]
    )

    return fee_account


@transaction.atomic
def create_fee_account(
    *,
    firm,
    created_by,
    validated_data,
):
    enrollment_uuid = validated_data["enrollment_uuid"]

    try:
        enrollment = (
            Enrollment.objects
            .select_related("student", "course")
            .get(
                uuid=enrollment_uuid,
                firm=firm,
            )
        )

    except Enrollment.DoesNotExist:
        raise ValidationError({
            "enrollment_uuid": [
                "Enrollment was not found."
            ]
        })

    if EnrollmentFeeAccount.objects.filter(
        firm=firm,
        enrollment=enrollment,
    ).exists():
        raise ValidationError({
            "enrollment_uuid": [
                (
                    "A fee account already exists "
                    "for this enrollment."
                )
            ]
        })

    total_amount = validated_data["total_amount"]
    discount_amount = validated_data["discount_amount"]

    balance_amount = total_amount - discount_amount

    return EnrollmentFeeAccount.objects.create(
        firm=firm,
        enrollment=enrollment,
        total_amount=total_amount,
        discount_amount=discount_amount,
        paid_amount=Decimal("0.00"),
        balance_amount=balance_amount,
        due_date=validated_data.get("due_date"),
        notes=validated_data.get("notes", ""),
        created_by=created_by,
        status=EnrollmentFeeAccount.Status.UNPAID,
    )


@transaction.atomic
def record_installment_payment(
    *,
    firm,
    recorded_by,
    validated_data,
):
    fee_account_uuid = validated_data["fee_account_uuid"]

    try:
        fee_account = (
            EnrollmentFeeAccount.objects
            .select_for_update()
            .select_related(
                "enrollment",
                "enrollment__student",
                "enrollment__course",
            )
            .get(
                uuid=fee_account_uuid,
                firm=firm,
            )
        )

    except EnrollmentFeeAccount.DoesNotExist:
        raise ValidationError({
            "fee_account_uuid": [
                "Fee account was not found."
            ]
        })

    refresh_fee_account_summary(fee_account)

    if fee_account.status == EnrollmentFeeAccount.Status.PAID:
        raise ValidationError({
            "amount": [
                "This fee account is already fully paid."
            ]
        })

    amount = validated_data["amount"]

    if amount > fee_account.balance_amount:
        raise ValidationError({
            "amount": [
                (
                    "Installment amount cannot be greater "
                    "than the pending balance."
                )
            ]
        })

    transaction_reference = (
        validated_data.get(
            "transaction_reference",
            "",
        )
        .strip()
    )

    if transaction_reference:
        reference_exists = (
            InstallmentPayment.objects
            .filter(
                firm=firm,
                transaction_reference=transaction_reference,
                status=InstallmentPayment.Status.RECORDED,
            )
            .exists()
        )

        if reference_exists:
            raise ValidationError({
                "transaction_reference": [
                    (
                        "This transaction reference "
                        "is already used."
                    )
                ]
            })

    installment = InstallmentPayment.objects.create(
        firm=firm,
        fee_account=fee_account,
        amount=amount,
        payment_method=validated_data["payment_method"],
        transaction_reference=transaction_reference,
        payment_date=(validated_data.get("payment_date") or timezone.localdate()),
        notes=validated_data.get("notes", ""),
        recorded_by=recorded_by,
    )

    refresh_fee_account_summary(fee_account)

    return installment, fee_account


@transaction.atomic
def void_installment_payment(
    *,
    firm,
    voided_by,
    installment_uuid,
    validated_data,
):
    try:
        installment = (
            InstallmentPayment.objects
            .select_for_update()
            .select_related("fee_account")
            .get(
                uuid=installment_uuid,
                firm=firm,
            )
        )

    except InstallmentPayment.DoesNotExist:
        raise ValidationError({
            "installment_uuid": [
                "Installment payment was not found."
            ]
        })

    if (
        installment.status
        != InstallmentPayment.Status.RECORDED
    ):
        raise ValidationError({
            "installment": [
                "Only recorded payments can be voided."
            ]
        })

    fee_account = (
        EnrollmentFeeAccount.objects
        .select_for_update()
        .get(pk=installment.fee_account_id)
    )

    installment.status = InstallmentPayment.Status.VOIDED
    installment.voided_by = voided_by
    installment.voided_at = timezone.now()
    installment.void_reason = validated_data["void_reason"]

    installment.save(
        update_fields=[
            "status",
            "voided_by",
            "voided_at",
            "void_reason",
            "updated_at",
        ]
    )

    refresh_fee_account_summary(fee_account)

    return installment, fee_account



