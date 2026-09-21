from django.db import transaction
from rest_framework.exceptions import ValidationError
from django.utils import timezone

from courses.models import (
    Course,
    Subject,
    Chapter,
    Lesson,
)
from teachers.models import Teacher

from .models import LiveClass


def get_object(model, firm, object_uuid, field_name):
    try:
        return model.objects.get(
            uuid=object_uuid,
            firm=firm,
        )
    except model.DoesNotExist:
        raise ValidationError({
            field_name: [
                f"Invalid {field_name.replace('_uuid', '')}."
            ]
        })


@transaction.atomic
def create_live_class(firm, validated_data):

    course_uuid = validated_data.pop("course_uuid")
    teacher_uuid = validated_data.pop("teacher_uuid")

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

    course = get_object(
        Course,
        firm,
        course_uuid,
        "course_uuid",
    )

    teacher = get_object(
        Teacher,
        firm,
        teacher_uuid,
        "teacher_uuid",
    )

    subject = None
    chapter = None
    lesson = None

    if subject_uuid:
        subject = get_object(
            Subject,
            firm,
            subject_uuid,
            "subject_uuid",
        )

        if subject.course_id != course.id:
            raise ValidationError({
                "subject_uuid": [
                    "Subject does not belong to this course."
                ]
            })

    if chapter_uuid:
        chapter = get_object(
            Chapter,
            firm,
            chapter_uuid,
            "chapter_uuid",
        )

        if not subject:
            raise ValidationError({
                "chapter_uuid": [
                    "Subject is required when chapter is provided."
                ]
            })

        if chapter.subject_id != subject.id:
            raise ValidationError({
                "chapter_uuid": [
                    "Chapter does not belong to this subject."
                ]
            })

    if lesson_uuid:
        lesson = get_object(
            Lesson,
            firm,
            lesson_uuid,
            "lesson_uuid",
        )

        if not chapter:
            raise ValidationError({
                "lesson_uuid": [
                    "Chapter is required when lesson is provided."
                ]
            })

        if lesson.chapter_id != chapter.id:
            raise ValidationError({
                "lesson_uuid": [
                    "Lesson does not belong to this chapter."
                ]
            })

    return LiveClass.objects.create(
        firm=firm,
        course=course,
        subject=subject,
        chapter=chapter,
        lesson=lesson,
        teacher=teacher,
        **validated_data,
    )
    
    
@transaction.atomic
def start_live_class(live_class):
    if live_class.status != LiveClass.Status.SCHEDULED:
        raise ValidationError({
            "status": ["Only a scheduled class can be started."]
        })

    live_class.status = LiveClass.Status.LIVE
    live_class.actual_start_at = timezone.now()

    live_class.save(
        update_fields=[
            "status",
            "actual_start_at",
            "updated_at",
        ]
    )

    return live_class


@transaction.atomic
def complete_live_class(live_class):
    if live_class.status != LiveClass.Status.LIVE:
        raise ValidationError({
            "status": ["Only a live class can be completed."]
        })

    live_class.status = LiveClass.Status.COMPLETED
    live_class.actual_end_at = timezone.now()

    live_class.save(
        update_fields=[
            "status",
            "actual_end_at",
            "updated_at",
        ]
    )

    return live_class


@transaction.atomic
def cancel_live_class(live_class):
    if live_class.status not in [
        LiveClass.Status.SCHEDULED,
        LiveClass.Status.LIVE,
    ]:
        raise ValidationError({
            "status": [
                "This class cannot be cancelled."
            ]
        })

    live_class.status = LiveClass.Status.CANCELLED

    if live_class.actual_start_at:
        live_class.actual_end_at = timezone.now()

    live_class.save()

    return live_class


