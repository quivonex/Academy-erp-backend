from decimal import Decimal
from io import BytesIO
import uuid as uuid_lib
from django.conf import settings

from reportlab.graphics.barcode import qr
from reportlab.graphics.shapes import Drawing
from reportlab.graphics import renderPDF
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
from django.db import transaction
from django.utils import timezone

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
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

    page_size = landscape(A4)
    page_width, page_height = page_size

    pdf = canvas.Canvas(
        buffer,
        pagesize=page_size,
    )

    # ---------------------------------------------------------
    # COLORS
    # ---------------------------------------------------------

    navy = colors.HexColor("#172554")
    blue = colors.HexColor("#1E3A8A")
    gold = colors.HexColor("#C9A227")
    dark = colors.HexColor("#111827")
    gray = colors.HexColor("#4B5563")
    light_gray = colors.HexColor("#E5E7EB")
    background = colors.HexColor("#FFFEF8")

    # ---------------------------------------------------------
    # BACKGROUND
    # ---------------------------------------------------------

    pdf.setFillColor(background)
    pdf.rect(
        0,
        0,
        page_width,
        page_height,
        fill=1,
        stroke=0,
    )

    # ---------------------------------------------------------
    # OUTER CERTIFICATE BORDER
    # ---------------------------------------------------------

    pdf.setStrokeColor(navy)
    pdf.setLineWidth(4)
    pdf.rect(
        20,
        20,
        page_width - 40,
        page_height - 40,
        fill=0,
        stroke=1,
    )

    # Gold inner border
    pdf.setStrokeColor(gold)
    pdf.setLineWidth(1.5)
    pdf.rect(
        28,
        28,
        page_width - 56,
        page_height - 56,
        fill=0,
        stroke=1,
    )

    # Decorative corner lines
    corner_length = 45

    pdf.setStrokeColor(gold)
    pdf.setLineWidth(3)

    # Top left
    pdf.line(38, page_height - 38, 38 + corner_length, page_height - 38)
    pdf.line(38, page_height - 38, 38, page_height - 38 - corner_length)

    # Top right
    pdf.line(
        page_width - 38,
        page_height - 38,
        page_width - 38 - corner_length,
        page_height - 38,
    )
    pdf.line(
        page_width - 38,
        page_height - 38,
        page_width - 38,
        page_height - 38 - corner_length,
    )

    # Bottom left
    pdf.line(38, 38, 38 + corner_length, 38)
    pdf.line(38, 38, 38, 38 + corner_length)

    # Bottom right
    pdf.line(
        page_width - 38,
        38,
        page_width - 38 - corner_length,
        38,
    )
    pdf.line(
        page_width - 38,
        38,
        page_width - 38,
        38 + corner_length,
    )

    # ---------------------------------------------------------
    # FIRM / ACADEMY LOGO
    # ---------------------------------------------------------

    firm = certificate.firm

    if firm.logo:
        try:
            with firm.logo.open("rb") as logo_file:
                logo_data = logo_file.read()

            logo = ImageReader(
                BytesIO(logo_data)
            )

            logo_width = 65
            logo_height = 65

            pdf.drawImage(
                logo,
                (page_width - logo_width) / 2,
                page_height - 105,
                width=logo_width,
                height=logo_height,
                preserveAspectRatio=True,
                mask="auto",
            )

        except Exception:
            # Certificate generation should not fail
            # only because a logo cannot be loaded.
            pass

    # ---------------------------------------------------------
    # FIRM NAME
    # ---------------------------------------------------------

    firm_name_y = page_height - 128

    pdf.setFillColor(navy)
    pdf.setFont("Helvetica-Bold", 18)

    pdf.drawCentredString(
        page_width / 2,
        firm_name_y,
        firm.name,
    )

    # ---------------------------------------------------------
    # CERTIFICATE TITLE
    # ---------------------------------------------------------

    pdf.setFillColor(gold)
    pdf.setFont("Helvetica-Bold", 27)

    pdf.drawCentredString(
        page_width / 2,
        page_height - 175,
        "CERTIFICATE OF COMPLETION",
    )

    # Decorative line below title
    line_width = 220

    pdf.setStrokeColor(gold)
    pdf.setLineWidth(1)

    pdf.line(
        (page_width - line_width) / 2,
        page_height - 188,
        (page_width + line_width) / 2,
        page_height - 188,
    )

    # ---------------------------------------------------------
    # CERTIFICATE MESSAGE
    # ---------------------------------------------------------

    pdf.setFillColor(gray)
    pdf.setFont("Helvetica", 12)

    pdf.drawCentredString(
        page_width / 2,
        page_height - 220,
        "This is to certify that",
    )

    # ---------------------------------------------------------
    # STUDENT NAME
    # ---------------------------------------------------------

    student_name = certificate.student_name or "Student"

    pdf.setFillColor(blue)
    pdf.setFont("Helvetica-Bold", 25)

    pdf.drawCentredString(
        page_width / 2,
        page_height - 260,
        student_name,
    )

    # Student name underline
    pdf.setStrokeColor(light_gray)
    pdf.setLineWidth(1)

    pdf.line(
        page_width / 2 - 180,
        page_height - 270,
        page_width / 2 + 180,
        page_height - 270,
    )

    # ---------------------------------------------------------
    # COURSE COMPLETION MESSAGE
    # ---------------------------------------------------------

    pdf.setFillColor(gray)
    pdf.setFont("Helvetica", 12)

    pdf.drawCentredString(
        page_width / 2,
        page_height - 300,
        "has successfully completed the course",
    )

    # ---------------------------------------------------------
    # COURSE NAME
    # ---------------------------------------------------------

    course_name = certificate.course_name or "Course"

    # Prevent very long course names from overflowing.
    max_course_length = 65

    if len(course_name) > max_course_length:
        course_name = (
            course_name[:max_course_length - 3]
            + "..."
        )

    pdf.setFillColor(dark)
    pdf.setFont("Helvetica-Bold", 20)

    pdf.drawCentredString(
        page_width / 2,
        page_height - 338,
        course_name,
    )

    # ---------------------------------------------------------
    # VERIFIED COURSE PROGRESS
    # ---------------------------------------------------------

    pdf.setFillColor(gray)
    pdf.setFont("Helvetica", 10)

    progress_text = (
        "Verified Course Progress: "
        f"{certificate.achieved_watch_percentage}%"
        "    |    "
        "Required: "
        f"{certificate.required_watch_percentage}%"
    )

    pdf.drawCentredString(
        page_width / 2,
        page_height - 370,
        progress_text,
    )

    # ---------------------------------------------------------
    # STUDENT / CERTIFICATE INFORMATION
    # ---------------------------------------------------------

    info_y = 135

    pdf.setStrokeColor(light_gray)
    pdf.setLineWidth(1)

    pdf.line(
        70,
        info_y + 35,
        page_width - 70,
        info_y + 35,
    )

    pdf.setFillColor(gray)
    pdf.setFont("Helvetica", 9)

    admission_number = (
        certificate.admission_number
        or "N/A"
    )

    pdf.drawString(
        75,
        info_y + 12,
        f"Admission No: {admission_number}",
    )

    issued_date = (
        certificate.issued_at.strftime(
            "%d %b %Y"
        )
    )

    pdf.drawRightString(
        page_width - 75,
        info_y + 12,
        f"Issue Date: {issued_date}",
    )

    # ---------------------------------------------------------
    # CERTIFICATE NUMBER
    # ---------------------------------------------------------

    pdf.setFillColor(dark)
    pdf.setFont("Helvetica-Bold", 9)

    pdf.drawString(
        75,
        info_y - 10,
        (
            "Certificate No: "
            f"{certificate.certificate_number}"
        ),
    )

    # ---------------------------------------------------------
    # VERIFICATION CODE
    # ---------------------------------------------------------

    pdf.setFillColor(gray)
    pdf.setFont("Helvetica", 8)

    pdf.drawString(
        75,
        info_y - 30,
        (
            "Verification Code: "
            f"{certificate.verification_code}"
        ),
    )

        # ---------------------------------------------------------
    # QR CODE - PUBLIC CERTIFICATE VERIFICATION
    # ---------------------------------------------------------

    verification_base_url = getattr(
        settings,
        "CERTIFICATE_VERIFICATION_BASE_URL",
        "",
    ).rstrip("/")

    if verification_base_url:
        verification_url = (
            f"{verification_base_url}/"
            f"{certificate.verification_code}/"
        )
        
        print(
    "CERTIFICATE QR DEBUG:",
    verification_url
    )

        qr_code = qr.QrCodeWidget(
            verification_url
        )

        bounds = qr_code.getBounds()

        qr_width = bounds[2] - bounds[0]
        qr_height = bounds[3] - bounds[1]

        qr_size = 75

        drawing = Drawing(
            qr_size,
            qr_size,
        )

        scale_x = qr_size / qr_width
        scale_y = qr_size / qr_height

        qr_code.transform = [
            scale_x,
            0,
            0,
            scale_y,
            0,
            0,
        ]

        drawing.add(qr_code)

        qr_x = page_width - 160
        qr_y = 55

        renderPDF.draw(
            drawing,
            pdf,
            qr_x,
            qr_y,
        )

        pdf.setFillColor(gray)
        pdf.setFont(
            "Helvetica-Bold",
            7,
        )

        pdf.drawCentredString(
            qr_x + (qr_size / 2),
            qr_y - 10,
            "Scan to verify",
        )
        
        
        
        
    # ---------------------------------------------------------
    # FOOTER
    # ---------------------------------------------------------

    pdf.setFillColor(colors.HexColor("#6B7280"))
    pdf.setFont("Helvetica-Oblique", 7)

    pdf.drawCentredString(
        page_width / 2,
        55,
        (
            "This certificate is digitally generated "
            "and can be verified using its unique "
            "verification code."
        ),
    )

    # ---------------------------------------------------------
    # FINISH PDF
    # ---------------------------------------------------------

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