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
    
    
    
