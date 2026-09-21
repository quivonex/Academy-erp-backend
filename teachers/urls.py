from django.urls import path

from .views import (
    StaffActivateView,
    StaffDeactivateView,
    StaffDetailView,
    StaffListCreateView,
    TeacherActivateView,
    TeacherDeactivateView,
    TeacherDetailView,
    TeacherListCreateView,
)


teacher_urlpatterns = [
    path("", TeacherListCreateView.as_view(), name="teacher-list-create",),
    path("<uuid:teacher_uuid>/", TeacherDetailView.as_view(), name="teacher-detail",),
    path("<uuid:teacher_uuid>/activate/", TeacherActivateView.as_view(), name="teacher-activate",),
    path("<uuid:teacher_uuid>/deactivate/", TeacherDeactivateView.as_view(), name="teacher-deactivate",),
]


staff_urlpatterns = [
    path("",StaffListCreateView.as_view(), name="staff-list-create",),

    path("<uuid:staff_uuid>/", StaffDetailView.as_view(), name="staff-detail",),

    path("<uuid:staff_uuid>/activate/", StaffActivateView.as_view(), name="staff-activate",),

    path("<uuid:staff_uuid>/deactivate/", StaffDeactivateView.as_view(), name="staff-deactivate",),
]


urlpatterns = teacher_urlpatterns

