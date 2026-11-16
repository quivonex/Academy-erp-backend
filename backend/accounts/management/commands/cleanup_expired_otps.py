from django.core.management.base import BaseCommand
from django.utils import timezone

from accounts.models import PasswordResetOTP


class Command(BaseCommand):
    help = "Delete expired or used password reset OTPs"

    def handle(self, *args, **options):
        now = timezone.now()
        deleted, _ = PasswordResetOTP.objects.filter(
            expires_at__lt=now,
        ).delete()

        used_deleted, _ = PasswordResetOTP.objects.filter(
            used_at__isnull=False,
        ).delete()

        total = deleted + used_deleted
        self.stdout.write(
            self.style.SUCCESS(
                f"Deleted {total} expired/used OTPs"
            )
        )
