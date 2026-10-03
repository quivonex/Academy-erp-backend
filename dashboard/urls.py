from django.urls import path

from .reports import (
    FeeCollectionReportView,
    PendingDuesReportView,
)
from .views import FirmDashboardSummaryView


urlpatterns = [
    path("summary/", FirmDashboardSummaryView.as_view(), name="firm-dashboard-summary",),
    path("reports/fees/collection/", FeeCollectionReportView.as_view(), name="fee-collection-report",),
    path("reports/fees/pending-dues/", PendingDuesReportView.as_view(), name="pending-dues-report",),
]