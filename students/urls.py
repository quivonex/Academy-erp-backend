from django.urls import path

from .views import (
    StudentActivateView,
    StudentDeactivateView,
    StudentDetailView,
    StudentListCreateView,
    StudentEnableLoginView,
)


urlpatterns = [
    path("", StudentListCreateView.as_view(), name="student-list-create",),

    path("<uuid:student_uuid>/", StudentDetailView.as_view(), name="student-detail",),

    path("<uuid:student_uuid>/activate/", StudentActivateView.as_view(), name="student-activate",),

    path("<uuid:student_uuid>/deactivate/", StudentDeactivateView.as_view(), name="student-deactivate",),

    path("<uuid:student_uuid>/enable-login/", StudentEnableLoginView.as_view(), name="student-enable-login",),
]