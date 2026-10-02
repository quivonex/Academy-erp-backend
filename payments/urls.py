from django.urls import path

from .views import (
    CoursePaymentListView,
    CoursePaymentReviewView,
    StudentCoursePaymentListCreateView,
)

student_payment_urlpatterns = [
    path(
        "course-payments/",
        StudentCoursePaymentListCreateView.as_view(),
        name="student-course-payment-list-create",
    ),
]

admin_payment_urlpatterns = [
    path(
        "",
        CoursePaymentListView.as_view(),
        name="course-payment-list",
    ),
    path(
        "<uuid:payment_uuid>/review/",
        CoursePaymentReviewView.as_view(),
        name="course-payment-review",
    ),
]