from django.utils import timezone

from .models import Enrollment


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
    
    