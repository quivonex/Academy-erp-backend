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



def create_live_class_scheduled_notifications(live_class):
    from courses.models import Enrollment

    now = timezone.now()

    enrollments = (
        Enrollment.objects
        .filter(
            firm=live_class.firm,
            course=live_class.course,
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

    scheduled_start_at = timezone.localtime(
        live_class.scheduled_start_at
    )

    body = (
        f"'{live_class.title}' is scheduled on "
        f"{scheduled_start_at.strftime('%d %b %Y, %I:%M %p')}."
    )

    notifications = [
        Notification(
            firm=live_class.firm,
            recipient=enrollment.student.user,
            notification_type=Notification.NotificationType.LIVE_CLASS,
            title="Live class scheduled",
            body=body,
            data={
                "live_class_uuid": str(live_class.uuid),
                "course_uuid": str(live_class.course.uuid),
                "scheduled_start_at": (
                    live_class.scheduled_start_at.isoformat()
                ),
                "scheduled_end_at": (
                    live_class.scheduled_end_at.isoformat()
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



def create_live_class_cancelled_notifications(live_class):
    from courses.models import Enrollment

    now = timezone.now()

    enrollments = (
        Enrollment.objects
        .filter(
            firm=live_class.firm,
            course=live_class.course,
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

    scheduled_start_at = timezone.localtime(
        live_class.scheduled_start_at
    )

    body = (
        f"'{live_class.title}', scheduled for "
        f"{scheduled_start_at.strftime('%d %b %Y, %I:%M %p')}, "
        f"has been cancelled."
    )

    notifications = [
        Notification(
            firm=live_class.firm,
            recipient=enrollment.student.user,
            notification_type=Notification.NotificationType.LIVE_CLASS,
            title="Live class cancelled",
            body=body,
            data={
                "live_class_uuid": str(live_class.uuid),
                "course_uuid": str(live_class.course.uuid),
                "scheduled_start_at": (
                    live_class.scheduled_start_at.isoformat()
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


def create_material_available_notifications(material):
    from courses.models import (
        Enrollment,
        StudentChapterVideoAccess,
    )

    now = timezone.now()

    if (
        not material.is_active
        or (
            material.available_from
            and material.available_from > now
        )
        or (
            material.available_until
            and material.available_until < now
        )
    ):
        return 0

    recipient_user_ids = set(
        Enrollment.objects
        .filter(
            firm=material.firm,
            course=material.course,
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
        .values_list("student__user_id", flat=True)
    )

    if (
        material.material_type == "VIDEO"
        and material.chapter_id
    ):
        recipient_user_ids.update(
            StudentChapterVideoAccess.objects
            .filter(
                firm=material.firm,
                course=material.course,
                chapter=material.chapter,
                is_active=True,
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
            .values_list("student__user_id", flat=True)
        )

    if not recipient_user_ids:
        return 0

    title = (
        "New class recording available"
        if material.source == "LIVE_CLASS_RECORDING"
        else "New study material available"
    )

    notifications = [
        Notification(
            firm=material.firm,
            recipient_id=user_id,
            notification_type=Notification.NotificationType.MATERIAL,
            title=title,
            body=(
                f"'{material.title}' is now available in "
                f"{material.course.name}."
            ),
            data={
                "material_uuid": str(material.uuid),
                "course_uuid": str(material.course.uuid),
                "material_type": material.material_type,
            },
        )
        for user_id in recipient_user_ids
    ]

    Notification.objects.bulk_create(
        notifications,
        batch_size=500,
    )

    return len(notifications)



def create_installment_payment_recorded_notification(
    installment,
    fee_account,
):
    enrollment = fee_account.enrollment
    student = enrollment.student
    user = student.user

    if not student.is_active or not user.is_active:
        return None

    return create_notification(
        firm=fee_account.firm,
        recipient=user,
        notification_type=Notification.NotificationType.PAYMENT,
        title="Payment recorded successfully",
        body=(
            f"Your payment of ₹{installment.amount} for "
            f"{enrollment.course.name} has been recorded. "
            f"Remaining balance: ₹{fee_account.balance_amount}."
        ),
        data={
            "installment_uuid": str(installment.uuid),
            "fee_account_uuid": str(fee_account.uuid),
            "enrollment_uuid": str(enrollment.uuid),
            "course_uuid": str(enrollment.course.uuid),
            "amount": str(installment.amount),
            "balance_amount": str(fee_account.balance_amount),
            "payment_method": installment.payment_method,
            "payment_date": installment.payment_date.isoformat(),
        },
    )


def create_installment_payment_voided_notification(
    installment,
    fee_account,
):
    enrollment = fee_account.enrollment
    student = enrollment.student
    user = student.user

    if not student.is_active or not user.is_active:
        return None

    return create_notification(
        firm=fee_account.firm,
        recipient=user,
        notification_type=Notification.NotificationType.PAYMENT,
        title="Payment entry voided",
        body=(
            f"A payment entry of ₹{installment.amount} for "
            f"{enrollment.course.name} was voided. "
            f"Please contact the academy if you need assistance."
        ),
        data={
            "installment_uuid": str(installment.uuid),
            "fee_account_uuid": str(fee_account.uuid),
            "enrollment_uuid": str(enrollment.uuid),
            "course_uuid": str(enrollment.course.uuid),
            "amount": str(installment.amount),
            "balance_amount": str(fee_account.balance_amount),
            "void_reason": installment.void_reason,
        },
    )
    
    
    
    
def create_live_class_started_notifications(live_class):
    from courses.models import Enrollment

    now = timezone.now()

    recipient_user_ids = (
        Enrollment.objects.filter(
            firm=live_class.firm,
            course=live_class.course,
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
        .values_list("student__user_id", flat=True)
        .distinct()
    )

    notifications = [
        Notification(
            firm=live_class.firm,
            recipient_id=user_id,
            notification_type=Notification.NotificationType.LIVE_CLASS,
            title="Live class started",
            body=(
                f"'{live_class.title}' is live now. "
                "Join the class from your course."
            ),
            data={
                "live_class_uuid": str(live_class.uuid),
                "course_uuid": str(live_class.course.uuid),
                "meeting_url": live_class.meeting_url,
            },
        )
        for user_id in recipient_user_ids
    ]

    if not notifications:
        return 0

    Notification.objects.bulk_create(
        notifications,
        batch_size=500,
    )

    return len(notifications)


def create_live_class_updated_notifications(
    live_class,
    *,
    schedule_changed,
):
    from courses.models import Enrollment

    now = timezone.now()

    recipient_user_ids = (
        Enrollment.objects.filter(
            firm=live_class.firm,
            course=live_class.course,
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
        .values_list("student__user_id", flat=True)
        .distinct()
    )

    if not recipient_user_ids:
        return 0

    if schedule_changed:
        start_at = timezone.localtime(
            live_class.scheduled_start_at
        )

        title = "Live class rescheduled"
        body = (
            f"'{live_class.title}' is now scheduled for "
            f"{start_at.strftime('%d %b %Y, %I:%M %p')}."
        )
    else:
        title = "Live class details updated"
        body = (
            f"The meeting details for '{live_class.title}' "
            "have been updated. Please check your course."
        )

    Notification.objects.bulk_create(
        [
            Notification(
                firm=live_class.firm,
                recipient_id=user_id,
                notification_type=Notification.NotificationType.LIVE_CLASS,
                title=title,
                body=body,
                data={
                    "live_class_uuid": str(live_class.uuid),
                    "course_uuid": str(live_class.course.uuid),
                    "scheduled_start_at": (
                        live_class.scheduled_start_at.isoformat()
                    ),
                    "scheduled_end_at": (
                        live_class.scheduled_end_at.isoformat()
                    ),
                },
            )
            for user_id in recipient_user_ids
        ],
        batch_size=500,
    )

    return len(recipient_user_ids)


def create_chapter_video_access_notifications(
    *,
    course,
    students,
    chapters,
    access_start_at,
    access_end_at,
):
    from students.models import Student

    student_ids = [student.id for student in students]

    recipient_user_ids = (
        Student.objects.filter(
            firm=course.firm,
            id__in=student_ids,
            is_active=True,
            user__is_active=True,
        )
        .values_list("user_id", flat=True)
        .distinct()
    )

    if not recipient_user_ids:
        return 0

    chapter_titles = [chapter.title for chapter in chapters]

    if len(chapter_titles) <= 3:
        chapter_text = ", ".join(chapter_titles)
    else:
        chapter_text = (
            f"{', '.join(chapter_titles[:3])} "
            f"and {len(chapter_titles) - 3} more"
        )

    if access_start_at <= timezone.now():
        body = (
            f"You can now watch videos for {chapter_text} "
            f"in {course.name}."
        )
    else:
        start_at = timezone.localtime(access_start_at)
        body = (
            f"Video access for {chapter_text} in {course.name} "
            f"starts on {start_at.strftime('%d %b %Y, %I:%M %p')}."
        )

    Notification.objects.bulk_create(
        [
            Notification(
                firm=course.firm,
                recipient_id=user_id,
                notification_type=Notification.NotificationType.MATERIAL,
                title="Chapter video access granted",
                body=body,
                data={
                    "course_uuid": str(course.uuid),
                    "chapter_uuids": [
                        str(chapter.uuid)
                        for chapter in chapters
                    ],
                    "access_start_at": access_start_at.isoformat(),
                    "access_end_at": (
                        access_end_at.isoformat()
                        if access_end_at
                        else None
                    ),
                },
            )
            for user_id in recipient_user_ids
        ],
        batch_size=500,
    )

    return len(recipient_user_ids)


