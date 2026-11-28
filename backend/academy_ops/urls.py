from django.urls import path
from materials.views import LearningMaterialListCreateView
from assignments.template_views import MCQTemplateView, MCQTemplatePromptView
from .views import (
    EnrollmentCandidatesView, BulkCourseAssignView, StudentOverviewView,
    BatchListCreateView, BatchDetailView, BatchMembersView, BatchAttendanceView,
    AttendanceReportView, JobListCreateView, JobDetailView, JobApplicationsView, BatchMemberDetailView,
    ApplicationReviewView, StudentJobsView, StudentJobDetailView, StudentJobApplyView,
    StudentApplicationsView, StudentWithdrawView,
)

urlpatterns = [
    path("courses/<uuid:course_uuid>/materials/", LearningMaterialListCreateView.as_view()),
    path("courses/<uuid:course_uuid>/enrollment-candidates/", EnrollmentCandidatesView.as_view()),
    path("courses/<uuid:course_uuid>/bulk-assign/", BulkCourseAssignView.as_view()),
    path("students/<uuid:student_uuid>/overview/", StudentOverviewView.as_view()),
    path("batches/", BatchListCreateView.as_view()),
    path("batches/<uuid:batch_uuid>/", BatchDetailView.as_view()),
    path("batches/<uuid:batch_uuid>/members/", BatchMembersView.as_view()),
    path("batches/<uuid:batch_uuid>/members/<uuid:membership_uuid>/", BatchMemberDetailView.as_view()),
    path("batches/<uuid:batch_uuid>/attendance/", BatchAttendanceView.as_view()),
    path("batches/<uuid:batch_uuid>/attendance/report/", AttendanceReportView.as_view()),
    path("placements/openings/", JobListCreateView.as_view()),
    path("placements/openings/<uuid:opening_uuid>/", JobDetailView.as_view()),
    path("placements/openings/<uuid:opening_uuid>/applications/", JobApplicationsView.as_view()),
    path("placements/applications/<uuid:application_uuid>/", ApplicationReviewView.as_view()),
    path("student/jobs/", StudentJobsView.as_view()),
    path("student/jobs/<uuid:opening_uuid>/", StudentJobDetailView.as_view()),
    path("student/jobs/<uuid:opening_uuid>/apply/", StudentJobApplyView.as_view()),
    path("student/job-applications/", StudentApplicationsView.as_view()),
    path("student/job-applications/<uuid:application_uuid>/withdraw/", StudentWithdrawView.as_view()),
    path("assignments/mcq-template/", MCQTemplateView.as_view()),
    path("assignments/mcq-template/prompt/", MCQTemplatePromptView.as_view()),
]
