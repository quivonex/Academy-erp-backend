from django.urls import path

from .reports import (
    EnrollmentStatusReportView,
    FeeCollectionReportView,
    PendingAssignmentGradingReportView,
    PendingDuesReportView,
)
from .superadmin_views import SuperAdminDashboardSummaryView
from .views import FirmDashboardSummaryView


urlpatterns = [
    path("summary/", FirmDashboardSummaryView.as_view(), name="firm-dashboard-summary",),
    
    path("super-admin/summary/", SuperAdminDashboardSummaryView.as_view(), name="super-admin-dashboard-summary",),
    
    path("reports/fees/collection/", FeeCollectionReportView.as_view(), name="fee-collection-report",),
    
    path("reports/fees/pending-dues/", PendingDuesReportView.as_view(), name="pending-dues-report",),
    
    path("reports/enrollments/status/", EnrollmentStatusReportView.as_view(), name="enrollment-status-report",),
    
    path("reports/assignments/pending-grading/", PendingAssignmentGradingReportView.as_view(), name="pending-assignment-grading-report",),
]