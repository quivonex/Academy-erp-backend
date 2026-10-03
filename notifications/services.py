import hashlib

from django.utils import timezone

from .models import DeviceToken, Notification


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
    
    
    
    
