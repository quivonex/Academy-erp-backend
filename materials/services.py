from django.db import transaction

from rest_framework.exceptions import ValidationError
import uuid
from django.core.files.storage import default_storage
from courses.models import (
    Course,
    Subject,
    Chapter,
    Lesson,
)

from classes.models import LiveClass

from .models import LearningMaterial


def get_tenant_object(
    model,
    *,
    firm,
    object_uuid,
    field_name,
):
    try:
        return model.objects.get(
            uuid=object_uuid,
            firm=firm,
        )

    except model.DoesNotExist:
        raise ValidationError({
            field_name: [
                f"Invalid {field_name}."
            ]
        })


@transaction.atomic
def create_material(
    *,
    firm,
    validated_data,
):
    course_uuid = validated_data.pop(
        "course_uuid"
    )

    subject_uuid = validated_data.pop(
        "subject_uuid",
        None,
    )

    chapter_uuid = validated_data.pop(
        "chapter_uuid",
        None,
    )

    lesson_uuid = validated_data.pop(
        "lesson_uuid",
        None,
    )

    live_class_uuid = validated_data.pop(
        "live_class_uuid",
        None,
    )

    course = get_tenant_object(
        Course,
        firm=firm,
        object_uuid=course_uuid,
        field_name="course_uuid",
    )

    subject = None
    chapter = None
    lesson = None
    live_class = None

    if subject_uuid:
        subject = get_tenant_object(
            Subject,
            firm=firm,
            object_uuid=subject_uuid,
            field_name="subject_uuid",
        )

        if subject.course_id != course.id:
            raise ValidationError({
                "subject_uuid": [
                    "Subject does not belong to this course."
                ]
            })

    if chapter_uuid:
        chapter = get_tenant_object(
            Chapter,
            firm=firm,
            object_uuid=chapter_uuid,
            field_name="chapter_uuid",
        )

        if not subject or chapter.subject_id != subject.id:
            raise ValidationError({
                "chapter_uuid": [
                    "Chapter does not belong to this subject."
                ]
            })

    if lesson_uuid:
        lesson = get_tenant_object(
            Lesson,
            firm=firm,
            object_uuid=lesson_uuid,
            field_name="lesson_uuid",
        )

        if not chapter or lesson.chapter_id != chapter.id:
            raise ValidationError({
                "lesson_uuid": [
                    "Lesson does not belong to this chapter."
                ]
            })

    if live_class_uuid:
        live_class = get_tenant_object(
            LiveClass,
            firm=firm,
            object_uuid=live_class_uuid,
            field_name="live_class_uuid",
        )

        if live_class.course_id != course.id:
            raise ValidationError({
                "live_class_uuid": [
                    "Live class does not belong to this course."
                ]
            })

    uploaded_file = validated_data.pop("file", None,)
    
    file_key = ""
    
    if uploaded_file:
        extension = uploaded_file.name.split(".")[-1]
    
        storage_path = (
            f"materials/"
            f"{firm.uuid}/"
            f"{course.uuid}/"
            f"{uuid.uuid4().hex}.{extension}"
        )
    
        file_key = default_storage.save(
            storage_path,
            uploaded_file,
        )
    material = LearningMaterial.objects.create(
        firm=firm,
        course=course,
        subject=subject,
        chapter=chapter,
        lesson=lesson,
        live_class=live_class,
        file_key=file_key,
        **validated_data,
    )

    return material

