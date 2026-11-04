from decimal import Decimal
from io import BytesIO
import uuid as uuid_lib

from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
from django.db import transaction
from django.utils import timezone

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas

from materials.models import LearningMaterial
from payments.models import EnrollmentFeeAccount
from progress.models import StudentMaterialProgress

from .models import CourseCompletionCertificate


VIDEO_COMPLETION_PERCENTAGE = Decimal("90.00")


def generate_certificate_number():
    while True:
        certificate_number = (
            f"CERT-{timezone.localdate():%Y%m%d}-"
            f"{uuid_lib.uuid4().hex[:10].upper()}"
        )

        if not CourseCompletionCertificate.objects.filter(
            certificate_number=certificate_number
        ).exists():
            return certificate_number


def get_verified_course_watch_percentage(*, enrollment):
    eligible_videos = LearningMaterial.objects.filter(
        firm=enrollment.firm,
        course=enrollment.course,
        material_type=LearningMaterial.MaterialType.VIDEO,
        is_active=True,
        counts_toward_progress=True,
    )

    total_videos = eligible_videos.count()

    if total_videos == 0:
        return {
            "total_videos": 0,
            "completed_videos": 0,
            "watch_percentage": Decimal("0.00"),
        }

    completed_videos = (
        StudentMaterialProgress.objects
        .filter(
            firm=enrollment.firm,
            student=enrollment.student,
            course=enrollment.course,
            material__in=eligible_videos,
            is_verified_completed=True,
        )
        .count()
    )

    watch_percentage = (
        Decimal(completed_videos)
        / Decimal(total_videos)
    ) * Decimal("100")

    return {
        "total_videos": total_videos,
        "completed_videos": completed_videos,
        "watch_percentage": min(
            watch_percentage,
            Decimal("100.00"),
        ),
    }


def is_course_fee_fully_paid(*, enrollment):
    # A free course does not require a fee account.
    if enrollment.course.price <= Decimal("0.00"):
        return True

    try:
        fee_account = enrollment.fee_account
    except EnrollmentFeeAccount.DoesNotExist:
        return False

    return fee_account.status == EnrollmentFeeAccount.Status.PAID


def get_certificate_eligibility(*, enrollment):
    course = enrollment.course

    watch_data = get_verified_course_watch_percentage(
        enrollment=enrollment,
    )

    required_percentage = (
        course.certificate_required_watch_percentage
    )

    certificate_enabled = course.is_certificate_enabled

    has_required_watch_progress = (
        watch_data["total_videos"] > 0
        and watch_data["watch_percentage"]
        >= required_percentage
    )

    fee_fully_paid = is_course_fee_fully_paid(
        enrollment=enrollment,
    )

    is_eligible = (
        enrollment.status == enrollment.Status.ACTIVE
        and certificate_enabled
        and has_required_watch_progress
        and fee_fully_paid
    )

    return {
        "is_eligible": is_eligible,
        "certificate_enabled": certificate_enabled,
        "enrollment_is_active": (
            enrollment.status == enrollment.Status.ACTIVE
        ),
        "total_videos": watch_data["total_videos"],
        "completed_videos": watch_data["completed_videos"],
        "achieved_watch_percentage": (
            watch_data["watch_percentage"]
        ),
        "required_watch_percentage": required_percentage,
        "fee_fully_paid": fee_fully_paid,
    }


def build_course_certificate_pdf(
    *,
    certificate,
):
    buffer = BytesIO()

    pdf = canvas.Canvas(
        buffer,
        pagesize=A4,
    )

    page_width, page_height = A4

    pdf.setFillColor(colors.HexColor("#1E3A8A"))
    pdf.rect(
        0,
        page_height - 105,
        page_width,
        105,
        fill=1,
        stroke=0,
    )

    pdf.setFillColor(colors.white)
    pdf.setFont("Helvetica-Bold", 24)
    pdf.drawCentredString(
        page_width / 2,
        page_height - 55,
        "VIDYASETU",
    )

    pdf.setFont("Helvetica", 11)
    pdf.drawCentredString(
        page_width / 2,
        page_height - 77,
        "Certificate of Course Completion",
    )

    pdf.setFillColor(colors.HexColor("#111827"))
    pdf.setFont("Helvetica", 13)
    pdf.drawCentredString(
        page_width / 2,
        page_height - 165,
        "This is to certify that",
    )

    pdf.setFont("Helvetica-Bold", 26)
    pdf.drawCentredString(
        page_width / 2,
        page_height - 215,
        certificate.student_name,
    )

    pdf.setFont("Helvetica", 13)
    pdf.drawCentredString(
        page_width / 2,
        page_height - 255,
        "has successfully completed the course",
    )

    pdf.setFont("Helvetica-Bold", 20)
    pdf.drawCentredString(
        page_width / 2,
        page_height - 295,
        certificate.course_name,
    )

    pdf.setFont("Helvetica", 10)
    pdf.drawCentredString(
        page_width / 2,
        page_height - 330,
        (
            "Course completion requirement: "
            f"{certificate.required_watch_percentage}% "
            "verified video progress"
        ),
    )

    pdf.setFont("Helvetica", 10)
    pdf.drawCentredString(
        page_width / 2,
        page_height - 350,
        (
            "Achieved verified video progress: "
            f"{certificate.achieved_watch_percentage}%"
        ),
    )

    pdf.setStrokeColor(colors.HexColor("#C9A227"))
    pdf.setLineWidth(2)
    pdf.rect(
        40,
        105,
        page_width - 80,
        page_height - 235,
        fill=0,
        stroke=1,
    )

    pdf.setFillColor(colors.HexColor("#374151"))
    pdf.setFont("Helvetica", 9)
    pdf.drawString(
        55,
        80,
        f"Certificate No: {certificate.certificate_number}",
    )

    pdf.drawRightString(
        page_width - 55,
        80,
        (
            "Issued: "
            f"{certificate.issued_at.strftime('%d %b %Y')}"
        ),
    )

    pdf.setFont("Helvetica", 8)
    pdf.drawString(
        55,
        58,
        (
            "Verify this certificate using code: "
            f"{certificate.verification_code}"
        ),
    )

    pdf.showPage()
    pdf.save()

    buffer.seek(0)
    return buffer.getvalue()


@transaction.atomic
def issue_certificate_if_eligible(*, enrollment):
    enrollment = (
        enrollment.__class__.objects
        .select_for_update()
        .select_related(
            "firm",
            "student",
            "course",
        )
        .get(pk=enrollment.pk)
    )

    eligibility = get_certificate_eligibility(
        enrollment=enrollment,
    )

    if not eligibility["is_eligible"]:
        return None, eligibility

    certificate, _ = (
        CourseCompletionCertificate.objects
        .get_or_create(
            enrollment=enrollment,
            defaults={
                "firm": enrollment.firm,
                "student": enrollment.student,
                "course": enrollment.course,
                "certificate_number": (
                    generate_certificate_number()
                ),
                "required_watch_percentage": (
                    eligibility[
                        "required_watch_percentage"
                    ]
                ),
                "achieved_watch_percentage": (
                    eligibility[
                        "achieved_watch_percentage"
                    ]
                ),
                "student_name": (
                    enrollment.student.full_name
                ),
                "admission_number": (
                    enrollment.student.admission_number
                    or ""
                ),
                "course_name": enrollment.course.name,
            },
        )
    )

    if not certificate.file_key:
        pdf_content = build_course_certificate_pdf(
            certificate=certificate,
        )

        file_path = (
            f"course_certificates/"
            f"{enrollment.firm.uuid}/"
            f"{enrollment.student.uuid}/"
            f"{enrollment.course.uuid}/"
            f"{certificate.certificate_number}.pdf"
        )

        certificate.file_key = default_storage.save(
            file_path,
            ContentFile(pdf_content),
        )

        certificate.save(
            update_fields=[
                "file_key",
            ]
        )

    return certificate, eligibility