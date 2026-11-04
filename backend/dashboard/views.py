from decimal import Decimal

from django.db.models import Sum
from django.utils import timezone

from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from assignments.models import AssignmentSubmission
from classes.models import LiveClass
from common.permissions import IsFirmAdminOrStaff
from common.responses import success_response
from courses.models import Course, Enrollment
from payments.models import (
    EnrollmentFeeAccount,
    InstallmentPayment,
)
from students.models import Student
from teachers.models import Teacher


class FirmDashboardSummaryView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get(self, request):
        firm = request.user.firm
        now = timezone.now()
        month_start = timezone.localdate().replace(day=1)

        fee_totals = (
            EnrollmentFeeAccount.objects
            .filter(firm=firm)
            .aggregate(
                total_fee_amount=Sum("total_amount"),
                total_paid_amount=Sum("paid_amount"),
                total_balance_amount=Sum("balance_amount"),
            )
        )

        collected_this_month = (
            InstallmentPayment.objects
            .filter(
                firm=firm,
                status=InstallmentPayment.Status.RECORDED,
                payment_date__gte=month_start,
            )
            .aggregate(total=Sum("amount"))
            .get("total")
            or Decimal("0.00")
        )

        return success_response(
            message="Dashboard summary retrieved successfully",
            data={
                "students": {
                    "total": Student.objects.filter(
                        firm=firm,
                    ).count(),
                    "active": Student.objects.filter(
                        firm=firm,
                        is_active=True,
                    ).count(),
                },
                "teachers": {
                    "total": Teacher.objects.filter(
                        firm=firm,
                    ).count(),
                    "active": Teacher.objects.filter(
                        firm=firm,
                        is_active=True,
                    ).count(),
                },
                "courses": {
                    "total": Course.objects.filter(
                        firm=firm,
                    ).count(),
                    "active": Course.objects.filter(
                        firm=firm,
                        is_active=True,
                    ).count(),
                },
                "enrollments": {
                    "total": Enrollment.objects.filter(
                        firm=firm,
                    ).count(),
                    "pending": Enrollment.objects.filter(
                        firm=firm,
                        status=Enrollment.Status.PENDING,
                    ).count(),
                    "active": Enrollment.objects.filter(
                        firm=firm,
                        status=Enrollment.Status.ACTIVE,
                    ).count(),
                    "completed": Enrollment.objects.filter(
                        firm=firm,
                        status=Enrollment.Status.COMPLETED,
                    ).count(),
                    "cancelled": Enrollment.objects.filter(
                        firm=firm,
                        status=Enrollment.Status.CANCELLED,
                    ).count(),
                },
                "fees": {
                    "total_fee_amount": (
                        fee_totals["total_fee_amount"]
                        or Decimal("0.00")
                    ),
                    "total_paid_amount": (
                        fee_totals["total_paid_amount"]
                        or Decimal("0.00")
                    ),
                    "total_balance_amount": (
                        fee_totals["total_balance_amount"]
                        or Decimal("0.00")
                    ),
                    "collected_this_month": (
                        collected_this_month
                    ),
                    "unpaid_accounts": (
                        EnrollmentFeeAccount.objects
                        .filter(
                            firm=firm,
                            status=(
                                EnrollmentFeeAccount
                                .Status.UNPAID
                            ),
                        )
                        .count()
                    ),
                    "partially_paid_accounts": (
                        EnrollmentFeeAccount.objects
                        .filter(
                            firm=firm,
                            status=(
                                EnrollmentFeeAccount
                                .Status.PARTIALLY_PAID
                            ),
                        )
                        .count()
                    ),
                },
                "assignments": {
                    "pending_grading": (
                        AssignmentSubmission.objects
                        .filter(
                            firm=firm,
                            status=(
                                AssignmentSubmission
                                .Status.SUBMITTED
                            ),
                        )
                        .count()
                    ),
                },
                "live_classes": {
                    "upcoming": (
                        LiveClass.objects
                        .filter(
                            firm=firm,
                            is_active=True,
                            status=(
                                LiveClass.Status.SCHEDULED
                            ),
                            scheduled_start_at__gte=now,
                        )
                        .count()
                    ),
                    "live_now": (
                        LiveClass.objects
                        .filter(
                            firm=firm,
                            is_active=True,
                            status=LiveClass.Status.LIVE,
                        )
                        .count()
                    ),
                },
            },
        )