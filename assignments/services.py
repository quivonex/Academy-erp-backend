from django.db import transaction

from rest_framework.exceptions import ValidationError

from courses.models import (
    Course,
    Subject,
    Chapter,
    Lesson,
)

from .models import (
    Assignment,
    AssignmentQuestion,
)


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
def create_assignment(
    *,
    firm,
    created_by,
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

    course = get_tenant_object(
        Course,
        firm=firm,
        object_uuid=course_uuid,
        field_name="course_uuid",
    )

    subject = None
    chapter = None
    lesson = None

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
        if not subject:
            raise ValidationError({
                "chapter_uuid": [
                    "subject_uuid is required."
                ]
            })

        chapter = get_tenant_object(
            Chapter,
            firm=firm,
            object_uuid=chapter_uuid,
            field_name="chapter_uuid",
        )

        if chapter.subject_id != subject.id:
            raise ValidationError({
                "chapter_uuid": [
                    "Chapter does not belong to this subject."
                ]
            })

    if lesson_uuid:
        if not chapter:
            raise ValidationError({
                "lesson_uuid": [
                    "chapter_uuid is required."
                ]
            })

        lesson = get_tenant_object(
            Lesson,
            firm=firm,
            object_uuid=lesson_uuid,
            field_name="lesson_uuid",
        )

        if lesson.chapter_id != chapter.id:
            raise ValidationError({
                "lesson_uuid": [
                    "Lesson does not belong to this chapter."
                ]
            })

    return Assignment.objects.create(
        firm=firm,
        course=course,
        subject=subject,
        chapter=chapter,
        lesson=lesson,
        created_by=created_by,
        **validated_data,
    )


@transaction.atomic
def create_assignment_question(
    *,
    assignment,
    validated_data,
):
    return AssignmentQuestion.objects.create(
        assignment=assignment,
        **validated_data,
    )
    
