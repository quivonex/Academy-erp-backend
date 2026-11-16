import logging

from django.conf import settings

from .models import DeviceToken

logger = logging.getLogger(__name__)

_firebase_app = None


def _get_firebase_app():
    global _firebase_app

    if _firebase_app is not None:
        return _firebase_app

    credentials_file = getattr(
        settings, "FCM_CREDENTIALS_FILE", ""
    )

    if not credentials_file:
        return None

    try:
        import firebase_admin
        from firebase_admin import credentials

        cred = credentials.Certificate(credentials_file)
        _firebase_app = firebase_admin.initialize_app(cred)
        return _firebase_app
    except Exception:
        logger.exception("Failed to initialize Firebase app")
        return None


def send_push_to_users(user_ids, *, title, body, data=None):
    app = _get_firebase_app()
    if app is None:
        return 0

    try:
        from firebase_admin import messaging
    except ImportError:
        logger.warning("firebase-admin not installed")
        return 0

    tokens = list(
        DeviceToken.objects.filter(
            user_id__in=user_ids,
            is_active=True,
        ).values_list("token", flat=True)
    )

    if not tokens:
        return 0

    fcm_data = {
        str(k): str(v)
        for k, v in (data or {}).items()
    }

    notification = messaging.Notification(
        title=title,
        body=body,
    )

    sent_count = 0

    for i in range(0, len(tokens), 500):
        batch = tokens[i:i + 500]

        message = messaging.MulticastMessage(
            tokens=batch,
            notification=notification,
            data=fcm_data,
        )

        try:
            response = messaging.send_each_for_multicast(
                message, app=app
            )
            sent_count += response.success_count

            for idx, send_response in enumerate(
                response.responses
            ):
                if (
                    send_response.exception
                    and _is_token_invalid(send_response.exception)
                ):
                    DeviceToken.objects.filter(
                        token=batch[idx],
                    ).update(is_active=False)

        except Exception:
            logger.exception(
                "FCM multicast send failed for batch"
            )

    return sent_count


def _is_token_invalid(exception):
    from firebase_admin import messaging

    return isinstance(
        exception,
        (
            messaging.UnregisteredError,
            messaging.InvalidArgumentError,
        ),
    )
