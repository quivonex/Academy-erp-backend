from celery import shared_task
from django.utils import timezone

from .models import PasswordResetOTP


@shared_task(name="accounts.tasks.cleanup_expired_otps_task")
def cleanup_expired_otps_task():
    now = timezone.now()
    expired, _ = PasswordResetOTP.objects.filter(expires_at__lt=now).delete()
    used, _ = PasswordResetOTP.objects.filter(used_at__isnull=False).delete()
    return f"Deleted {expired + used} expired/used OTPs"
