from django.urls import path

from .grading_views import (
    AssignmentSubmissionDetailView,
    AssignmentSubmissionGradeView,
    AssignmentSubmissionListView,
)
from .views import (
    AssignmentDetailView,
    AssignmentListCreateView,
    AssignmentPDFImportView,
    AssignmentQuestionListCreateView,
    StudentAssignmentDetailView,
    StudentAssignmentResultView,
    StudentAssignmentSubmitView,
    StudentCourseAssignmentListView,
)


urlpatterns = [
    path(
        "",
        AssignmentListCreateView.as_view(),
        name="assignment-list-create",
    ),

    path(
        "import-pdf/",
        AssignmentPDFImportView.as_view(),
        name="assignment-import-pdf",
    ),

    path(
        "<uuid:assignment_uuid>/questions/",
        AssignmentQuestionListCreateView.as_view(),
        name="assignment-questions",
    ),

    path(
        "<uuid:assignment_uuid>/submissions/",
        AssignmentSubmissionListView.as_view(),
        name="assignment-submissions",
    ),

    path(
        "submissions/<uuid:submission_uuid>/",
        AssignmentSubmissionDetailView.as_view(),
        name="assignment-submission-detail",
    ),

    path(
        "submissions/<uuid:submission_uuid>/grade/",
        AssignmentSubmissionGradeView.as_view(),
        name="assignment-submission-grade",
    ),

    path(
        "<uuid:assignment_uuid>/",
        AssignmentDetailView.as_view(),
        name="assignment-detail",
    ),
]


student_assignment_urlpatterns = [
    path(
        "courses/<uuid:course_uuid>/assignments/",
        StudentCourseAssignmentListView.as_view(),
        name="student-course-assignments",
    ),

    path(
        "assignments/<uuid:assignment_uuid>/",
        StudentAssignmentDetailView.as_view(),
        name="student-assignment-detail",
    ),

    path(
        "assignments/<uuid:assignment_uuid>/submit/",
        StudentAssignmentSubmitView.as_view(),
        name="student-assignment-submit",
    ),

    path(
        "assignments/<uuid:assignment_uuid>/result/",
        StudentAssignmentResultView.as_view(),
        name="student-assignment-result",
    ),
]
