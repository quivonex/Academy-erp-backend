from django.urls import path

from .views import (
    ChapterDetailView,
    ChapterListCreateView,
    CourseCategoryDetailView,
    CourseCategoryListCreateView,
    CourseDetailView,
    CourseListCreateView,
    EnrollmentDetailView,
    EnrollmentListCreateView,
    LessonDetailView,
    LessonListCreateView,
    PublicCourseCategoryListView,
    PublicCourseDetailView,
    PublicCourseListView,
    SubjectDetailView,
    SubjectListCreateView,
)

category_urlpatterns = [
    path("", CourseCategoryListCreateView.as_view()),
    path("<uuid:category_uuid>/", CourseCategoryDetailView.as_view()),
]

course_urlpatterns = [
    path("", CourseListCreateView.as_view()),
    path("<uuid:course_uuid>/", CourseDetailView.as_view()),
]

subject_urlpatterns = [
    path("", SubjectListCreateView.as_view()),
    path("<uuid:subject_uuid>/", SubjectDetailView.as_view()),
]

chapter_urlpatterns = [
    path("", ChapterListCreateView.as_view()),
    path("<uuid:chapter_uuid>/", ChapterDetailView.as_view()),
]

lesson_urlpatterns = [
    path("", LessonListCreateView.as_view()),
    path("<uuid:lesson_uuid>/", LessonDetailView.as_view()),
]

enrollment_urlpatterns = [
    path("", EnrollmentListCreateView.as_view()),
    path("<uuid:enrollment_uuid>/", EnrollmentDetailView.as_view()),
]

public_course_urlpatterns = [
    path(
        "categories/",
        PublicCourseCategoryListView.as_view(),
        name="public-course-category-list",
    ),
    path(
        "",
        PublicCourseListView.as_view(),
        name="public-course-list",
    ),
    path(
        "<uuid:course_uuid>/",
        PublicCourseDetailView.as_view(),
        name="public-course-detail",
    ),
]

urlpatterns = course_urlpatterns