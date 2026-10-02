from django.urls import path
from .views import (
    CoursePaymentListView,
    CoursePaymentReviewView,
    EnrollmentFeeAccountListCreateView,
    InstallmentPaymentListCreateView,
    InstallmentPaymentVoidView,
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
        "fee-accounts/",
        EnrollmentFeeAccountListCreateView.as_view(),
        name="fee-account-list-create",
    ),
    
    path(
        "installments/",
        InstallmentPaymentListCreateView.as_view(),
        name="installment-payment-list-create",
    ),
    
    path(
        "installments/<uuid:installment_uuid>/void/",
        InstallmentPaymentVoidView.as_view(),
        name="installment-payment-void",
    ),

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