from django.urls import path

from .views import (
    DeviceTokenRegisterView,
    DeviceTokenUnregisterView,
    NotificationListView,
    NotificationMarkAllReadView,
    NotificationMarkReadView,
    NotificationSendView,
    NotificationUnreadCountView,
)


urlpatterns = [
    path(
        "",
        NotificationListView.as_view(),
        name="notification-list",
    ),

    path(
        "unread-count/",
        NotificationUnreadCountView.as_view(),
        name="notification-unread-count",
    ),

    path(
        "mark-all-read/",
        NotificationMarkAllReadView.as_view(),
        name="notification-mark-all-read",
    ),

    path(
        "devices/register/",
        DeviceTokenRegisterView.as_view(),
        name="device-token-register",
    ),

    path(
        "devices/unregister/",
        DeviceTokenUnregisterView.as_view(),
        name="device-token-unregister",
    ),

    path(
        "send/",
        NotificationSendView.as_view(),
        name="notification-send",
    ),

    path("<uuid:notification_uuid>/read/",
        NotificationMarkReadView.as_view(),
        name="notification-mark-read",
    ),
]