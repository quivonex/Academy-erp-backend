from django.urls import path

from .views import (
    StudentCourseProgressView,
    StudentMaterialProgressView,
    StudentVideoWatchHeartbeatView,
    StudentVideoWatchSessionEndView,
    StudentVideoWatchSessionStartView,
)

urlpatterns = [
    path("materials/<uuid:material_uuid>/progress/", StudentMaterialProgressView.as_view(), name="student-material-progress",),

    path("courses/<uuid:course_uuid>/progress/", StudentCourseProgressView.as_view(), name="student-course-progress",),
    
    path("materials/<uuid:material_uuid>/watch-sessions/", StudentVideoWatchSessionStartView.as_view(), name="student-video-watch-session-start",),

    path("watch-sessions/<uuid:session_uuid>/heartbeat/", StudentVideoWatchHeartbeatView.as_view(), name="student-video-watch-heartbeat",),

    path("watch-sessions/<uuid:session_uuid>/end/", StudentVideoWatchSessionEndView.as_view(), name="student-video-watch-session-end",),

]