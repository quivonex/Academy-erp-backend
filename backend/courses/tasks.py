from celery import shared_task

from .services import expire_ended_enrollments


@shared_task(name="courses.tasks.expire_ended_enrollments_task")
def expire_ended_enrollments_task():
    expire_ended_enrollments()
