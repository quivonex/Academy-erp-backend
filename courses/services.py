from django.db import transaction
from rest_framework.exceptions import ValidationError
from datetime import timedelta
from django.utils import timezone
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
from datetime import timedelta
from django.utils import timezone


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
    enrollment_status = validated_data.get(
        "status",
        Enrollment.Status.PENDING,
    )
    
    if enrollment_status == Enrollment.Status.PENDING:
        validated_data["access_start_at"] = None
        validated_data["access_end_at"] = None
    
    elif enrollment_status == Enrollment.Status.ACTIVE:
        access_start_at = (
            validated_data.get("access_start_at")
            or timezone.now()
        )
    
        validated_data["access_start_at"] = access_start_at
    
        if (
            not validated_data.get("access_end_at")
            and course.access_duration_days
        ):
            validated_data["access_end_at"] = (
                access_start_at
                + timedelta(
                    days=course.access_duration_days
                )
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

@transaction.atomic
def bulk_assign_course_by_admission_date(
    *,
    firm,
    granted_by,
    validated_data,
):
    course_uuid = validated_data["course_uuid"]
    joined_date_from = validated_data["joined_date_from"]
    joined_date_to = (
        validated_data.get("joined_date_to")
        or joined_date_from
    )
    grant_access = validated_data["grant_access"]

    course = get_course(
        firm=firm,
        course_uuid=course_uuid,
    )

    if not course.is_active:
        raise ValidationError({
            "course_uuid": [
                "Inactive course cannot be assigned."
            ]
        })

    students = (
        Student.objects
        .filter(
            firm=firm,
            is_active=True,
            joined_date__gte=joined_date_from,
            joined_date__lte=joined_date_to,
        )
        .order_by("first_name", "last_name")
    )

    matched_students = list(students)

    if not matched_students:
        raise ValidationError({
            "joined_date_from": [
                "No active students were found for the selected "
                "admission date range."
            ]
        })

    student_ids = [
        student.id for student in matched_students
    ]

    enrolled_student_ids = set(
        Enrollment.objects.filter(
            firm=firm,
            course=course,
            student_id__in=student_ids,
        ).values_list("student_id", flat=True)
    )

    now = timezone.now()

    requested_start_at = validated_data.get(
        "access_start_at"
    )
    requested_end_at = validated_data.get(
        "access_end_at"
    )

    if grant_access:
        access_start_at = requested_start_at or now

        if requested_end_at:
            access_end_at = requested_end_at
        elif course.access_duration_days:
            access_end_at = (
                access_start_at
                + timedelta(days=course.access_duration_days)
            )
        else:
            access_end_at = None

        enrollment_status = Enrollment.Status.ACTIVE
    else:
        access_start_at = None
        access_end_at = None
        enrollment_status = Enrollment.Status.PENDING

    new_enrollments = []
    skipped_students = []

    for student in matched_students:
        if student.id in enrolled_student_ids:
            skipped_students.append({
                "student_uuid": str(student.uuid),
                "student_name": student.full_name,
                "admission_number": student.admission_number,
                "reason": "Student is already enrolled in this course.",
            })
            continue

        new_enrollments.append(
            Enrollment(
                firm=firm,
                student=student,
                course=course,
                source=Enrollment.Source.FIRM_GRANTED,
                granted_by=granted_by,
                status=enrollment_status,
                access_start_at=access_start_at,
                access_end_at=access_end_at,
            )
        )

    created_enrollments = Enrollment.objects.bulk_create(
        new_enrollments
    )

    return {
        "course": course,
        "joined_date_from": joined_date_from,
        "joined_date_to": joined_date_to,
        "grant_access": grant_access,
        "matched_count": len(matched_students),
        "created_enrollments": created_enrollments,
        "skipped_students": skipped_students,
    }
    
