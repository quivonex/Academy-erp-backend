from django.urls import path

from .views import FirmDashboardSummaryView


urlpatterns = [
    path(
        "summary/",
        FirmDashboardSummaryView.as_view(),
        name="firm-dashboard-summary",
    ),
]