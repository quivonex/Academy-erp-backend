from django.db import transaction

from .models import Staff, Teacher


@transaction.atomic
def create_teacher(firm, validated_data):
    return Teacher.objects.create(
        firm=firm,
        **validated_data,
    )


@transaction.atomic
def update_teacher(teacher, validated_data):
    for field, value in validated_data.items():
        setattr(teacher, field, value)

    teacher.save()
    return teacher


@transaction.atomic
def activate_teacher(teacher):
    teacher.is_active = True
    teacher.save(
        update_fields=["is_active", "updated_at"]
    )
    return teacher


@transaction.atomic
def deactivate_teacher(teacher):
    teacher.is_active = False
    teacher.save(
        update_fields=["is_active", "updated_at"]
    )
    return teacher


@transaction.atomic
def create_staff(firm, validated_data):
    return Staff.objects.create(
        firm=firm,
        **validated_data,
    )


@transaction.atomic
def update_staff(staff, validated_data):
    for field, value in validated_data.items():
        setattr(staff, field, value)

    staff.save()
    return staff


@transaction.atomic
def activate_staff(staff):
    staff.is_active = True
    staff.save(
        update_fields=["is_active", "updated_at"]
    )
    return staff


@transaction.atomic
def deactivate_staff(staff):
    staff.is_active = False
    staff.save(
        update_fields=["is_active", "updated_at"]
    )
    return staff


