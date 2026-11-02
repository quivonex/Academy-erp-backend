from django.db import transaction
from django.utils import timezone
from .models import ParentGuardian, Student


@transaction.atomic
def create_student(
    firm,
    validated_data,
):
    guardians_data = validated_data.pop(
        "guardians",
        [],
    )

    admission_date = (
        validated_data.pop("joined_date", None)
        or timezone.localdate()
    )

    student = Student.objects.create(
        firm=firm,
        joined_date=admission_date,
        **validated_data,
    )

    for guardian_data in guardians_data:
        ParentGuardian.objects.create(
            student=student,
            **guardian_data,
        )

    return student

@transaction.atomic
def update_student(
    student,
    validated_data,
):
    guardians_data = validated_data.pop(
        "guardians",
        None,
    )

    for field, value in validated_data.items():
        setattr(
            student,
            field,
            value,
        )

    student.save()

    if guardians_data is not None:
        existing_ids = set(
            student.guardians.values_list("id", flat=True)
        )
        updated_ids = set()

        for guardian_data in guardians_data:
            guardian_id = guardian_data.pop("id", None)
            if guardian_id and guardian_id in existing_ids:
                ParentGuardian.objects.filter(
                    id=guardian_id,
                    student=student,
                ).update(**guardian_data)
                updated_ids.add(guardian_id)
            else:
                ParentGuardian.objects.create(
                    student=student,
                    **guardian_data,
                )

        stale_ids = existing_ids - updated_ids
        if stale_ids:
            student.guardians.filter(
                id__in=stale_ids
            ).delete()

    return student


@transaction.atomic
def deactivate_student(student):
    student.is_active = False

    student.save(
        update_fields=[
            "is_active",
            "updated_at",
        ]
    )

    return student


@transaction.atomic
def activate_student(student):
    student.is_active = True

    student.save(
        update_fields=[
            "is_active",
            "updated_at",
        ]
    )

    return student


from rest_framework.exceptions import ValidationError

from accounts.models import User

@transaction.atomic
def enable_student_login(
    *,
    student,
    email,
    password,
):
    if student.user_id:
        raise ValidationError({
            "student": [
                "Login is already enabled for this student."
            ]
        })

    if User.objects.filter(
        email__iexact=email
    ).exists():
        raise ValidationError({
            "email": [
                "A user with this email already exists."
            ]
        })

    user = User.objects.create_user(
        email=email,
        password=password,
        first_name=student.first_name,
        last_name=student.last_name,
        phone=student.phone,
        firm=student.firm,
        user_type=User.UserType.STUDENT,
        is_active=True,
    )

    student.user = user

    if not student.email:
        student.email = email

    student.save(
        update_fields=[
            "user",
            "email",
            "updated_at",
        ]
    )

    return user

