from django.urls import path

from .portal_views import (StudentMyCoursesView, StudentCourseDetailView, StudentLiveClassListView,
    StudentCourseLiveClassListView,StudentCourseMaterialListView,
    StudentMaterialDetailView,)


urlpatterns = [
    path("courses/", StudentMyCoursesView.as_view(), name="student-my-courses",),
    
    path("courses/<uuid:course_uuid>/", StudentCourseDetailView.as_view(), name="student-course-detail",),

    path("live-classes/", StudentLiveClassListView.as_view(), name="student-live-classes",),
    
    path("courses/<uuid:course_uuid>/live-classes/", StudentCourseLiveClassListView.as_view(), name="student-course-live-classes",),
    
    path("courses/<uuid:course_uuid>/materials/", StudentCourseMaterialListView.as_view(), name="student-course-materials",),
    
    path("materials/<uuid:material_uuid>/", StudentMaterialDetailView.as_view(), name="student-material-detail",),

]