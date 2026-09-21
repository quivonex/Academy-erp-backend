from django.urls import path

from .portal_views import (StudentMyCoursesView, StudentCourseDetailView, StudentLiveClassListView,
    StudentCourseLiveClassListView,)


urlpatterns = [
    path("courses/", StudentMyCoursesView.as_view(), name="student-my-courses",),
    path("courses/<uuid:course_uuid>/", StudentCourseDetailView.as_view(), name="student-course-detail",),

    path("live-classes/", StudentLiveClassListView.as_view(), name="student-live-classes",),
    path("courses/<uuid:course_uuid>/live-classes/", StudentCourseLiveClassListView.as_view(), name="student-course-live-classes",),

]