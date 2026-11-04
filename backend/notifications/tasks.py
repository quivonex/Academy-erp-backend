from celery import shared_task


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

    create_assignment_published_notifications(assignment)


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

    create_live_class_scheduled_notifications(live_class)


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

    create_live_class_started_notifications(live_class)


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

    create_live_class_cancelled_notifications(live_class)


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

    create_live_class_updated_notifications(
        live_class,
        schedule_changed=schedule_changed,
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

    create_material_available_notifications(material)


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

    create_chapter_video_access_notifications(
        course=course,
        students=students,
        chapters=chapters,
        access_start_at=access_start_at,
        access_end_at=access_end_at,
    )
