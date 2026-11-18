from datetime import timedelta

from celery import shared_task
from django.utils import timezone

from .models import StudentVideoWatchSession


@shared_task(name="progress.tasks.cleanup_stale_sessions_task")
def cleanup_stale_sessions_task():
    cutoff = timezone.now() - timedelta(hours=1)
    count = StudentVideoWatchSession.objects.filter(
        is_active=True,
        last_heartbeat_at__lt=cutoff,
    ).update(is_active=False, ended_at=timezone.now())
    return f"Closed {count} stale watch session(s)"
