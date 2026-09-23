from django.urls import path

from .views import (
    StudentMaterialProgressView,
    StudentCourseProgressView,
)


urlpatterns = [
    path(
        "materials/<uuid:material_uuid>/progress/",
        StudentMaterialProgressView.as_view(),
        name="student-material-progress",
    ),

    path(
        "courses/<uuid:course_uuid>/progress/",
        StudentCourseProgressView.as_view(),
        name="student-course-progress",
    ),
]