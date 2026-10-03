from django.utils import timezone

from .models import (
    Enrollment,
    StudentChapterVideoAccess,
)


def get_student_active_enrollment(
    *,
    student,
    course,
):
    now = timezone.now()

    enrollment = Enrollment.objects.filter(
        firm=student.firm,
        student=student,
        course=course,
        status=Enrollment.Status.ACTIVE,
    ).first()

    if not enrollment:
        return None

    if (
        enrollment.access_start_at
        and now < enrollment.access_start_at
    ):
        return None

    if (
        enrollment.access_end_at
        and now > enrollment.access_end_at
    ):
        return None

    return enrollment


def student_has_course_access(
    *,
    student,
    course,
):
    return get_student_active_enrollment(
        student=student,
        course=course,
    ) is not None
    
    
    
    
def get_student_active_chapter_video_access(
    *,
    student,
    course,
    chapter,
):
    now = timezone.now()

    access = (
        StudentChapterVideoAccess.objects
        .filter(
            firm=student.firm,
            student=student,
            course=course,
            chapter=chapter,
            is_active=True,
        )
        .first()
    )

    if not access:
        return None

    if (
        access.access_start_at
        and now < access.access_start_at
    ):
        return None

    if (
        access.access_end_at
        and now > access.access_end_at
    ):
        return None

    return access


def student_has_chapter_video_access(
    *,
    student,
    course,
    chapter,
):
    return get_student_active_chapter_video_access(
        student=student,
        course=course,
        chapter=chapter,
    ) is not None
    
    

