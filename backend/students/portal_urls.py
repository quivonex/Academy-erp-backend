from django.urls import path

from .portal_views import (StudentMyCoursesView, StudentCourseDetailView, StudentLiveClassListView,
    StudentCourseLiveClassListView,StudentCourseMaterialListView,StudentLiveClassDetailView,
    StudentMaterialDetailView,)


from .enrollment_views import StudentCourseEnrollmentView, StudentEnrollmentRequestsView

urlpatterns = [
    path("enrollments/", StudentEnrollmentRequestsView.as_view(), name="student-enrollment-requests"),
    path("courses/<uuid:course_uuid>/enrollment/", StudentCourseEnrollmentView.as_view(), name="student-course-enrollment"),
    path("courses/", StudentMyCoursesView.as_view(), name="student-my-courses",),
    
    path("courses/<uuid:course_uuid>/", StudentCourseDetailView.as_view(), name="student-course-detail",),

    path("live-classes/", StudentLiveClassListView.as_view(), name="student-live-classes",),
    
    path("courses/<uuid:course_uuid>/live-classes/", StudentCourseLiveClassListView.as_view(), name="student-course-live-classes",),
    
    path("courses/<uuid:course_uuid>/materials/", StudentCourseMaterialListView.as_view(), name="student-course-materials",),
    
    path("materials/<uuid:material_uuid>/", StudentMaterialDetailView.as_view(), name="student-material-detail",),

    path("live-classes/<uuid:live_class_uuid>/", StudentLiveClassDetailView.as_view(), name="student-live-class-detail",),


]