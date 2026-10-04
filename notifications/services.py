import hashlib

from django.utils import timezone

from .models import DeviceToken, Notification
from django.db.models import Q
from django.utils import timezone

def get_token_hash(token):
    return hashlib.sha256(
        token.encode("utf-8")
    ).hexdigest()


def register_device_token(
    *,
    firm,
    user,
    token,
    platform,
    device_id="",
):
    token = token.strip()

    device_token, _ = DeviceToken.objects.update_or_create(
        token_hash=get_token_hash(token),
        defaults={
            "firm": firm,
            "user": user,
            "token": token,
            "platform": platform,
            "device_id": device_id,
            "is_active": True,
            "last_seen_at": timezone.now(),
        },
    )

    return device_token


def create_notification(
    *,
    firm,
    recipient,
    notification_type,
    title,
    body,
    action_url="",
    data=None,
):
    return Notification.objects.create(
        firm=firm,
        recipient=recipient,
        notification_type=notification_type,
        title=title,
        body=body,
        action_url=action_url,
        data=data or {},
    )
    
    
    
def create_course_access_notification(enrollment):
    course = enrollment.course
    student = enrollment.student

    if not student.user or not student.user.is_active:
        return None

    body = (
        f"Course access has been granted for {course.name}."
    )

    if enrollment.access_start_at:
        body += (
            f" Access starts on "
            f"{enrollment.access_start_at.strftime('%d %b %Y, %I:%M %p')}."
        )

    return create_notification(
        firm=enrollment.firm,
        recipient=student.user,
        notification_type=Notification.NotificationType.COURSE_ACCESS,
        title="Course access granted",
        body=body,
        data={
            "course_uuid": str(course.uuid),
            "enrollment_uuid": str(enrollment.uuid),
            "access_start_at": (
                enrollment.access_start_at.isoformat()
                if enrollment.access_start_at
                else None
            ),
            "access_end_at": (
                enrollment.access_end_at.isoformat()
                if enrollment.access_end_at
                else None
            ),
        },
    )
    
    
    
    
def create_assignment_result_notification(
    submission,
    *,
    is_regrade=False,
):
    student = submission.student
    assignment = submission.assignment

    if not student.user or not student.user.is_active:
        return None

    marks_obtained = (
        submission.total_marks_obtained
        if submission.total_marks_obtained is not None
        else 0
    )

    title = (
        "Assignment result updated"
        if is_regrade
        else "Assignment graded"
    )

    return create_notification(
        firm=submission.firm,
        recipient=student.user,
        notification_type=Notification.NotificationType.RESULT,
        title=title,
        body=(
            f"Your result for '{assignment.title}' is available. "
            f"Score: {marks_obtained} out of {assignment.max_marks}."
        ),
        data={
            "assignment_uuid": str(assignment.uuid),
            "submission_uuid": str(submission.uuid),
            "marks_obtained": str(marks_obtained),
            "max_marks": str(assignment.max_marks),
        },
    )
    
    
    
    
def create_assignment_published_notifications(assignment):
    from courses.models import Enrollment

    now = timezone.now()

    enrollments = (
        Enrollment.objects
        .filter(
            firm=assignment.firm,
            course=assignment.course,
            status=Enrollment.Status.ACTIVE,
            student__is_active=True,
            student__user__is_active=True,
        )
        .filter(
            Q(access_start_at__isnull=True)
            | Q(access_start_at__lte=now)
        )
        .filter(
            Q(access_end_at__isnull=True)
            | Q(access_end_at__gte=now)
        )
        .select_related("student__user")
    )

    body = (
        f"'{assignment.title}' has been published for "
        f"{assignment.course.name}."
    )

    if assignment.due_at:
        body += (
            f" Submit it before "
            f"{assignment.due_at.strftime('%d %b %Y, %I:%M %p')}."
        )

    notifications = [
        Notification(
            firm=assignment.firm,
            recipient=enrollment.student.user,
            notification_type=Notification.NotificationType.ASSIGNMENT,
            title="New assignment available",
            body=body,
            data={
                "assignment_uuid": str(assignment.uuid),
                "course_uuid": str(assignment.course.uuid),
                "due_at": (
                    assignment.due_at.isoformat()
                    if assignment.due_at
                    else None
                ),
            },
        )
        for enrollment in enrollments
    ]

    if notifications:
        Notification.objects.bulk_create(
            notifications,
            batch_size=500,
        )

    return len(notifications)



