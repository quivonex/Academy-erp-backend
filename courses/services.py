from django.db import transaction
from rest_framework.exceptions import ValidationError

from students.models import Student
from teachers.models import Teacher
from .models import (
    Chapter,
    Course,
    CourseCategory,
    Enrollment,
    Lesson,
    Subject,
)


def get_category(firm, category_uuid):
    try:
        return CourseCategory.objects.get(
            uuid=category_uuid,
            firm=firm,
        )
    except CourseCategory.DoesNotExist:
        raise ValidationError({
            "category_uuid": [
                "Invalid course category."
            ]
        })


def get_course(firm, course_uuid):
    try:
        return Course.objects.get(
            uuid=course_uuid,
            firm=firm,
        )
    except Course.DoesNotExist:
        raise ValidationError({
            "course_uuid": [
                "Invalid course."
            ]
        })


def get_teacher(firm, teacher_uuid):
    try:
        return Teacher.objects.get(
            uuid=teacher_uuid,
            firm=firm,
        )
    except Teacher.DoesNotExist:
        raise ValidationError({
            "teacher_uuid": [
                "Invalid teacher."
            ]
        })


def get_subject(firm, subject_uuid):
    try:
        return Subject.objects.get(
            uuid=subject_uuid,
            firm=firm,
        )
    except Subject.DoesNotExist:
        raise ValidationError({
            "subject_uuid": [
                "Invalid subject."
            ]
        })


def get_chapter(firm, chapter_uuid):
    try:
        return Chapter.objects.get(
            uuid=chapter_uuid,
            firm=firm,
        )
    except Chapter.DoesNotExist:
        raise ValidationError({
            "chapter_uuid": [
                "Invalid chapter."
            ]
        })


def get_student(firm, student_uuid):
    try:
        return Student.objects.get(
            uuid=student_uuid,
            firm=firm,
        )
    except Student.DoesNotExist:
        raise ValidationError({
            "student_uuid": [
                "Invalid student."
            ]
        })


@transaction.atomic
def create_category(firm, validated_data):
    return CourseCategory.objects.create(
        firm=firm,
        **validated_data,
    )


@transaction.atomic
def create_course(firm, validated_data):
    category_uuid = validated_data.pop(
        "category_uuid",
        None,
    )

    category = None

    if category_uuid:
        category = get_category(
            firm,
            category_uuid,
        )

    return Course.objects.create(
        firm=firm,
        category=category,
        **validated_data,
    )


@transaction.atomic
def create_subject(firm, validated_data):
    course_uuid = validated_data.pop(
        "course_uuid"
    )

    teacher_uuid = validated_data.pop(
        "teacher_uuid",
        None,
    )

    course = get_course(
        firm,
        course_uuid,
    )

    teacher = None

    if teacher_uuid:
        teacher = get_teacher(
            firm,
            teacher_uuid,
        )

    return Subject.objects.create(
        firm=firm,
        course=course,
        teacher=teacher,
        **validated_data,
    )


@transaction.atomic
def create_chapter(firm, validated_data):
    subject_uuid = validated_data.pop(
        "subject_uuid"
    )

    subject = get_subject(
        firm,
        subject_uuid,
    )

    return Chapter.objects.create(
        firm=firm,
        subject=subject,
        **validated_data,
    )


@transaction.atomic
def create_lesson(firm, validated_data):
    chapter_uuid = validated_data.pop(
        "chapter_uuid"
    )

    chapter = get_chapter(
        firm,
        chapter_uuid,
    )

    return Lesson.objects.create(
        firm=firm,
        chapter=chapter,
        **validated_data,
    )


@transaction.atomic
def create_enrollment(*, firm, granted_by, validated_data):
    student_uuid = validated_data.pop("student_uuid")
    course_uuid = validated_data.pop("course_uuid")

    student = get_student(
        firm=firm,
        student_uuid=student_uuid,
    )

    course = get_course(
        firm=firm,
        course_uuid=course_uuid,
    )

    if Enrollment.objects.filter(
        firm=firm,
        student=student,
        course=course,
    ).exists():
        raise ValidationError({
            "student_uuid": [
                "Student is already enrolled in this course."
            ]
        })

    enrollment = Enrollment.objects.create(
        firm=firm,
        student=student,
        course=course,
        source=Enrollment.Source.FIRM_GRANTED,
        granted_by=granted_by,
        **validated_data,
    )

    return enrollment



@transaction.atomic
def update_instance(instance, validated_data):
    for field, value in validated_data.items():
        setattr(instance, field, value)

    instance.save()

    return instance

