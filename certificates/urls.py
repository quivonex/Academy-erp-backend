from django.urls import path

from .views import (
    FirmCertificateListView,
    FirmCertificateRevokeView,
    PublicCertificateVerificationView,
    StudentCertificateDownloadView,
    StudentCertificateListView,
    StudentCertificateStatusView,
)


certificate_urlpatterns = [
    path(
        "",
        FirmCertificateListView.as_view(),
        name="firm-certificate-list",
    ),
    path(
        "<uuid:certificate_uuid>/revoke/",
        FirmCertificateRevokeView.as_view(),
        name="firm-certificate-revoke",
    ),
]


student_certificate_urlpatterns = [
    path(
        "certificates/",
        StudentCertificateListView.as_view(),
        name="student-certificate-list",
    ),
    path(
        "courses/<uuid:course_uuid>/certificate-status/",
        StudentCertificateStatusView.as_view(),
        name="student-certificate-status",
    ),
    path(
        "certificates/<uuid:certificate_uuid>/download/",
        StudentCertificateDownloadView.as_view(),
        name="student-certificate-download",
    ),
]


public_certificate_urlpatterns = [
    path(
        "<uuid:verification_code>/",
        PublicCertificateVerificationView.as_view(),
        name="public-certificate-verification",
    ),
]