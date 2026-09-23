from django.urls import path

from .views import (
    AssignmentListCreateView,
    AssignmentDetailView,
    AssignmentQuestionListCreateView,
)


urlpatterns = [
    path("", AssignmentListCreateView.as_view(), name="assignment-list-create",),

    path("<uuid:assignment_uuid>/", AssignmentDetailView.as_view(), name="assignment-detail",),

    path("<uuid:assignment_uuid>/questions/", AssignmentQuestionListCreateView.as_view(), name="assignment-questions",),
]