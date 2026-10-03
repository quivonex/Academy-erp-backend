from decimal import Decimal

from django.db.models import Sum
from django.utils.dateparse import parse_date

from rest_framework import status
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from common.pagination import StandardResultsSetPagination
from common.permissions import IsFirmAdminOrStaff
from common.responses import error_response, success_response
from payments.models import (
    EnrollmentFeeAccount,
    InstallmentPayment,
)
from payments.serializers import (
    EnrollmentFeeAccountSerializer,
    InstallmentPaymentSerializer,
)


def get_date_range(request):
    date_from_value = request.query_params.get("date_from")
    date_to_value = request.query_params.get("date_to")

    date_from = (
        parse_date(date_from_value)
        if date_from_value
        else None
    )

    date_to = (
        parse_date(date_to_value)
        if date_to_value
        else None
    )

    if date_from_value and not date_from:
        raise ValidationError({
            "date_from": [
                "Use date format YYYY-MM-DD."
            ]
        })

    if date_to_value and not date_to:
        raise ValidationError({
            "date_to": [
                "Use date format YYYY-MM-DD."
            ]
        })

    if date_from and date_to and date_to < date_from:
        raise ValidationError({
            "date_to": [
                "Date to must be on or after date from."
            ]
        })

    return date_from, date_to


def get_paginated_data(request, queryset, serializer_class):
    paginator = StandardResultsSetPagination()

    page = paginator.paginate_queryset(
        queryset,
        request,
    )

    serializer = serializer_class(
        page,
        many=True,
    )

    return {
        "count": paginator.page.paginator.count,
        "next": paginator.get_next_link(),
        "previous": paginator.get_previous_link(),
        "results": serializer.data,
    }


class FeeCollectionReportView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get(self, request):
        try:
            date_from, date_to = get_date_range(request)
        except ValidationError as exc:
            return error_response(
                message="Invalid date filter",
                errors=exc.detail,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        payments = (
            InstallmentPayment.objects
            .filter(
                firm=request.user.firm,
                status=InstallmentPayment.Status.RECORDED,
            )
            .select_related(
                "fee_account",
                "fee_account__enrollment",
                "fee_account__enrollment__student",
                "fee_account__enrollment__course",
                "recorded_by",
                "voided_by",
            )
            .order_by("-payment_date", "-created_at")
        )

        if date_from:
            payments = payments.filter(
                payment_date__gte=date_from
            )

        if date_to:
            payments = payments.filter(
                payment_date__lte=date_to
            )

        course_uuid = request.query_params.get(
            "course_uuid"
        )

        if course_uuid:
            payments = payments.filter(
                fee_account__enrollment__course__uuid=(
                    course_uuid
                )
            )

        total_collected = (
            payments.aggregate(total=Sum("amount"))
            .get("total")
            or Decimal("0.00")
        )

        return success_response(
            message=(
                "Fee collection report retrieved successfully"
            ),
            data={
                "summary": {
                    "date_from": date_from,
                    "date_to": date_to,
                    "total_collected": total_collected,
                    "payment_count": payments.count(),
                },
                "payments": get_paginated_data(
                    request,
                    payments,
                    InstallmentPaymentSerializer,
                ),
            },
        )


class PendingDuesReportView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get(self, request):
        try:
            date_from, date_to = get_date_range(request)
        except ValidationError as exc:
            return error_response(
                message="Invalid date filter",
                errors=exc.detail,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        fee_accounts = (
            EnrollmentFeeAccount.objects
            .filter(
                firm=request.user.firm,
                status__in=[
                    EnrollmentFeeAccount.Status.UNPAID,
                    EnrollmentFeeAccount.Status.PARTIALLY_PAID,
                ],
            )
            .select_related(
                "enrollment",
                "enrollment__student",
                "enrollment__course",
                "created_by",
            )
            .order_by("due_date", "-created_at")
        )

        if date_from:
            fee_accounts = fee_accounts.filter(
                due_date__gte=date_from
            )

        if date_to:
            fee_accounts = fee_accounts.filter(
                due_date__lte=date_to
            )

        course_uuid = request.query_params.get(
            "course_uuid"
        )

        if course_uuid:
            fee_accounts = fee_accounts.filter(
                enrollment__course__uuid=course_uuid
            )

        total_pending_amount = (
            fee_accounts.aggregate(
                total=Sum("balance_amount")
            )
            .get("total")
            or Decimal("0.00")
        )

        return success_response(
            message=(
                "Pending dues report retrieved successfully"
            ),
            data={
                "summary": {
                    "date_from": date_from,
                    "date_to": date_to,
                    "total_pending_amount": (
                        total_pending_amount
                    ),
                    "fee_account_count": (
                        fee_accounts.count()
                    ),
                },
                "fee_accounts": get_paginated_data(
                    request,
                    fee_accounts,
                    EnrollmentFeeAccountSerializer,
                ),
            },
        )