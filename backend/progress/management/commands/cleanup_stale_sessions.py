from datetime import timedelta

from django.core.management.base import BaseCommand
from django.utils import timezone

from progress.models import StudentVideoWatchSession


class Command(BaseCommand):
    help = "Close video watch sessions inactive for over 1 hour"

    def handle(self, *args, **options):
        cutoff = timezone.now() - timedelta(hours=1)
        count = StudentVideoWatchSession.objects.filter(
            is_active=True,
            last_heartbeat_at__lt=cutoff,
        ).update(
            is_active=False,
            ended_at=timezone.now(),
        )

        self.stdout.write(
            self.style.SUCCESS(
                f"Closed {count} stale watch session(s)"
            )
        )
