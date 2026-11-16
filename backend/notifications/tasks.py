import logging

from celery import shared_task

logger = logging.getLogger(__name__)


def _push_to_users(user_ids, *, title, body, data=None):
    try:
        from .push import send_push_to_users

        send_push_to_users(
            user_ids,
            title=title,
            body=body,
            data=data,
        )
    except Exception:
        logger.exception("FCM push delivery failed")


@shared_task(
    name="notifications.send_assignment_published",
    ignore_result=True,
)
def send_assignment_published_notifications(assignment_id):
    from assignments.models import Assignment
    from .services import create_assignment_published_notifications

    try:
        assignment = (
            Assignment.objects
            .select_related("course", "firm")
            .get(pk=assignment_id)
        )
    except Assignment.DoesNotExist:
        return

    count = create_assignment_published_notifications(assignment)

    if count:
        from courses.models import Enrollment
        from django.db.models import Q
        from django.utils import timezone

        now = timezone.now()
        user_ids = list(
            Enrollment.objects.filter(
                firm=assignment.firm,
                course=assignment.course,
                status=Enrollment.Status.ACTIVE,
                student__is_active=True,
                student__user__is_active=True,
            ).filter(
                Q(access_start_at__isnull=True) | Q(access_start_at__lte=now)
            ).filter(
                Q(access_end_at__isnull=True) | Q(access_end_at__gte=now)
            ).values_list("student__user_id", flat=True)
        )

        body = f"'{assignment.title}' has been published for {assignment.course.name}."
        _push_to_users(
            user_ids,
            title="New assignment available",
            body=body,
            data={"assignment_uuid": str(assignment.uuid)},
        )


@shared_task(
    name="notifications.send_live_class_scheduled",
    ignore_result=True,
)
def send_live_class_scheduled_notifications(live_class_id):
    from classes.models import LiveClass
    from .services import create_live_class_scheduled_notifications

    try:
        live_class = (
            LiveClass.objects
            .select_related("course", "firm")
            .get(pk=live_class_id)
        )
    except LiveClass.DoesNotExist:
        return

    count = create_live_class_scheduled_notifications(live_class)

    if count:
        from courses.models import Enrollment
        from django.db.models import Q
        from django.utils import timezone

        now = timezone.now()
        user_ids = list(
            Enrollment.objects.filter(
                firm=live_class.firm,
                course=live_class.course,
                status=Enrollment.Status.ACTIVE,
                student__is_active=True,
                student__user__is_active=True,
            ).filter(
                Q(access_start_at__isnull=True) | Q(access_start_at__lte=now)
            ).filter(
                Q(access_end_at__isnull=True) | Q(access_end_at__gte=now)
            ).values_list("student__user_id", flat=True)
        )

        scheduled_at = timezone.localtime(live_class.scheduled_start_at)
        _push_to_users(
            user_ids,
            title="Live class scheduled",
            body=f"'{live_class.title}' is scheduled on {scheduled_at.strftime('%d %b %Y, %I:%M %p')}.",
            data={"live_class_uuid": str(live_class.uuid)},
        )


@shared_task(
    name="notifications.send_live_class_started",
    ignore_result=True,
)
def send_live_class_started_notifications(live_class_id):
    from classes.models import LiveClass
    from .services import create_live_class_started_notifications

    try:
        live_class = (
            LiveClass.objects
            .select_related("course", "firm")
            .get(pk=live_class_id)
        )
    except LiveClass.DoesNotExist:
        return

    count = create_live_class_started_notifications(live_class)

    if count:
        from courses.models import Enrollment
        from django.db.models import Q
        from django.utils import timezone

        now = timezone.now()
        user_ids = list(
            Enrollment.objects.filter(
                firm=live_class.firm,
                course=live_class.course,
                status=Enrollment.Status.ACTIVE,
                student__is_active=True,
                student__user__is_active=True,
            ).filter(
                Q(access_start_at__isnull=True) | Q(access_start_at__lte=now)
            ).filter(
                Q(access_end_at__isnull=True) | Q(access_end_at__gte=now)
            ).values_list("student__user_id", flat=True).distinct()
        )

        _push_to_users(
            user_ids,
            title="Live class started",
            body=f"'{live_class.title}' is live now. Join the class from your course.",
            data={"live_class_uuid": str(live_class.uuid)},
        )


@shared_task(
    name="notifications.send_live_class_cancelled",
    ignore_result=True,
)
def send_live_class_cancelled_notifications(live_class_id):
    from classes.models import LiveClass
    from .services import create_live_class_cancelled_notifications

    try:
        live_class = (
            LiveClass.objects
            .select_related("course", "firm")
            .get(pk=live_class_id)
        )
    except LiveClass.DoesNotExist:
        return

    count = create_live_class_cancelled_notifications(live_class)

    if count:
        from courses.models import Enrollment
        from django.db.models import Q
        from django.utils import timezone

        now = timezone.now()
        user_ids = list(
            Enrollment.objects.filter(
                firm=live_class.firm,
                course=live_class.course,
                status=Enrollment.Status.ACTIVE,
                student__is_active=True,
                student__user__is_active=True,
            ).filter(
                Q(access_start_at__isnull=True) | Q(access_start_at__lte=now)
            ).filter(
                Q(access_end_at__isnull=True) | Q(access_end_at__gte=now)
            ).values_list("student__user_id", flat=True)
        )

        scheduled_at = timezone.localtime(live_class.scheduled_start_at)
        _push_to_users(
            user_ids,
            title="Live class cancelled",
            body=f"'{live_class.title}', scheduled for {scheduled_at.strftime('%d %b %Y, %I:%M %p')}, has been cancelled.",
            data={"live_class_uuid": str(live_class.uuid)},
        )


@shared_task(
    name="notifications.send_live_class_updated",
    ignore_result=True,
)
def send_live_class_updated_notifications(
    live_class_id,
    schedule_changed,
):
    from classes.models import LiveClass
    from .services import create_live_class_updated_notifications

    try:
        live_class = (
            LiveClass.objects
            .select_related("course", "firm")
            .get(pk=live_class_id)
        )
    except LiveClass.DoesNotExist:
        return

    count = create_live_class_updated_notifications(
        live_class,
        schedule_changed=schedule_changed,
    )

    if count:
        from courses.models import Enrollment
        from django.db.models import Q
        from django.utils import timezone

        now = timezone.now()
        user_ids = list(
            Enrollment.objects.filter(
                firm=live_class.firm,
                course=live_class.course,
                status=Enrollment.Status.ACTIVE,
                student__is_active=True,
                student__user__is_active=True,
            ).filter(
                Q(access_start_at__isnull=True) | Q(access_start_at__lte=now)
            ).filter(
                Q(access_end_at__isnull=True) | Q(access_end_at__gte=now)
            ).values_list("student__user_id", flat=True).distinct()
        )

        if schedule_changed:
            start_at = timezone.localtime(live_class.scheduled_start_at)
            title = "Live class rescheduled"
            body = f"'{live_class.title}' is now scheduled for {start_at.strftime('%d %b %Y, %I:%M %p')}."
        else:
            title = "Live class details updated"
            body = f"The meeting details for '{live_class.title}' have been updated."

        _push_to_users(
            user_ids,
            title=title,
            body=body,
            data={"live_class_uuid": str(live_class.uuid)},
        )


@shared_task(
    name="notifications.send_material_available",
    ignore_result=True,
)
def send_material_available_notifications(material_id):
    from materials.models import LearningMaterial
    from .services import create_material_available_notifications

    try:
        material = (
            LearningMaterial.objects
            .select_related("course", "firm", "chapter")
            .get(pk=material_id)
        )
    except LearningMaterial.DoesNotExist:
        return

    count = create_material_available_notifications(material)

    if count:
        from notifications.models import Notification

        user_ids = list(
            Notification.objects.filter(
                firm=material.firm,
                notification_type=Notification.NotificationType.MATERIAL,
                data__material_uuid=str(material.uuid),
            ).values_list("recipient_id", flat=True).distinct()
        )

        title = (
            "New class recording available"
            if material.source == "LIVE_CLASS_RECORDING"
            else "New study material available"
        )

        _push_to_users(
            user_ids,
            title=title,
            body=f"'{material.title}' is now available in {material.course.name}.",
            data={"material_uuid": str(material.uuid)},
        )


@shared_task(
    name="notifications.send_chapter_video_access",
    ignore_result=True,
)
def send_chapter_video_access_notifications(
    course_id,
    student_ids,
    chapter_ids,
    access_start_at_iso,
    access_end_at_iso,
):
    from django.utils.dateparse import parse_datetime
    from courses.models import Course
    from courses.models import Chapter
    from students.models import Student
    from .services import create_chapter_video_access_notifications

    try:
        course = Course.objects.get(pk=course_id)
    except Course.DoesNotExist:
        return

    students = list(
        Student.objects.filter(pk__in=student_ids)
    )
    chapters = list(
        Chapter.objects.filter(pk__in=chapter_ids)
    )

    access_start_at = parse_datetime(access_start_at_iso)
    access_end_at = (
        parse_datetime(access_end_at_iso)
        if access_end_at_iso
        else None
    )

    count = create_chapter_video_access_notifications(
        course=course,
        students=students,
        chapters=chapters,
        access_start_at=access_start_at,
        access_end_at=access_end_at,
    )

    if count:
        user_ids = list(
            Student.objects.filter(
                pk__in=student_ids,
                is_active=True,
                user__is_active=True,
            ).values_list("user_id", flat=True)
        )

        _push_to_users(
            user_ids,
            title="Chapter video access granted",
            body=f"New video access granted in {course.name}.",
            data={"course_uuid": str(course.uuid)},
        )
