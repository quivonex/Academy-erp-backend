from django.urls import path

from .views import (
    AssignmentListCreateView,
    AssignmentDetailView,
    AssignmentQuestionListCreateView,
    AssignmentPDFImportView,
    StudentCourseAssignmentListView,
    StudentAssignmentDetailView,
    StudentAssignmentSubmitView,
    StudentAssignmentResultView,
)


urlpatterns = [
    path("", AssignmentListCreateView.as_view(), name="assignment-list-create",),

    path("<uuid:assignment_uuid>/", AssignmentDetailView.as_view(), name="assignment-detail",),

    path("<uuid:assignment_uuid>/questions/", AssignmentQuestionListCreateView.as_view(), name="assignment-questions",),

    path("import-pdf/", AssignmentPDFImportView.as_view(), name="assignment-import-pdf",),
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