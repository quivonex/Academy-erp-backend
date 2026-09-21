from django.urls import path

from .portal_views import StudentMyCoursesView


urlpatterns = [
    path("courses/", StudentMyCoursesView.as_view(), name="student-my-courses",),
]