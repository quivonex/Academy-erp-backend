from django.db.models import Prefetch
from rest_framework import status
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from common.pagination import StandardResultsSetPagination
from common.permissions import IsFirmAdminOrStaff, IsStudent
from common.responses import error_response, success_response

from .models import (
    CoursePayment,
    EnrollmentFeeAccount,
    InstallmentPayment,
)
from .serializers import (
    StudentFeeAccountLedgerSerializer,
    CoursePaymentReviewSerializer,
    CoursePaymentSerializer,
    StudentCoursePaymentCreateSerializer,
    EnrollmentFeeAccountCreateSerializer,
    EnrollmentFeeAccountSerializer,
    InstallmentPaymentCreateSerializer,
    InstallmentPaymentSerializer,
    InstallmentPaymentVoidSerializer,
)
from .services import (
    create_course_payment,
    create_fee_account,
    record_installment_payment,
    review_course_payment,
    void_installment_payment,
)


class StudentCoursePaymentListCreateView(APIView):
    permission_classes = [IsAuthenticated, IsStudent]

    def get(self, request):
        student = request.user.student_profile

        payments = (
            CoursePayment.objects
            .filter(firm=request.user.firm, student=student)
            .select_related("course", "reviewed_by")
            .order_by("-created_at")
        )

        paginator = StandardResultsSetPagination()
        page = paginator.paginate_queryset(payments, request)

        serializer = CoursePaymentSerializer(page, many=True)
        return paginator.get_paginated_response(
            serializer.data
        )

    def post(self, request):
        serializer = StudentCoursePaymentCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            payment = create_course_payment(
                user=request.user,
                validated_data=serializer.validated_data,
            )
        except ValidationError as exc:
            return error_response(
                message="Unable to create payment request",
                errors=exc.detail,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        return success_response(
            message="Payment request submitted successfully",
            data=CoursePaymentSerializer(payment).data,
            status_code=status.HTTP_201_CREATED,
        )


class CoursePaymentListView(APIView):
    permission_classes = [IsAuthenticated, IsFirmAdminOrStaff]

    def get(self, request):
        payments = (
            CoursePayment.objects
            .filter(firm=request.user.firm)
            .select_related("student", "course", "reviewed_by")
            .order_by("-created_at")
        )

        payment_status = request.query_params.get("status")
        if payment_status:
            valid_statuses = [choice[0] for choice in CoursePayment.Status.choices]

            if payment_status not in valid_statuses:
                return error_response(
                    message="Invalid payment status",
                    errors={"status": [f"Choose one of: {', '.join(valid_statuses)}"]},
                    status_code=status.HTTP_400_BAD_REQUEST,
                )

            payments = payments.filter(status=payment_status)

        paginator = StandardResultsSetPagination()
        page = paginator.paginate_queryset(payments, request)

        serializer = CoursePaymentSerializer(page, many=True)
        return paginator.get_paginated_response(
            serializer.data
        )


class CoursePaymentReviewView(APIView):
    permission_classes = [IsAuthenticated, IsFirmAdminOrStaff]

    def patch(self, request, payment_uuid):
        serializer = CoursePaymentReviewSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            payment = review_course_payment(
                firm=request.user.firm,
                reviewed_by=request.user,
                payment_uuid=payment_uuid,
                validated_data=serializer.validated_data,
            )
        except ValidationError as exc:
            return error_response(
                message="Unable to review payment request",
                errors=exc.detail,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        return success_response(
            message="Payment request reviewed successfully",
            data=CoursePaymentSerializer(payment).data,
        )
        
class EnrollmentFeeAccountListCreateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get(self, request):
        fee_accounts = (
            EnrollmentFeeAccount.objects
            .filter(firm=request.user.firm)
            .select_related(
                "enrollment",
                "enrollment__student",
                "enrollment__course",
                "created_by",
            )
            .order_by("-created_at")
        )

        enrollment_uuid = request.query_params.get(
            "enrollment_uuid"
        )
        student_uuid = request.query_params.get(
            "student_uuid"
        )
        fee_status = request.query_params.get("status")

        if enrollment_uuid:
            fee_accounts = fee_accounts.filter(
                enrollment__uuid=enrollment_uuid
            )

        if student_uuid:
            fee_accounts = fee_accounts.filter(
                enrollment__student__uuid=student_uuid
            )

        if fee_status:
            valid_statuses = [
                choice[0]
                for choice
                in EnrollmentFeeAccount.Status.choices
            ]

            if fee_status not in valid_statuses:
                return error_response(
                    message="Invalid fee account status",
                    errors={
                        "status": [
                            (
                                "Use UNPAID, PARTIALLY_PAID, "
                                "or PAID."
                            )
                        ]
                    },
                    status_code=status.HTTP_400_BAD_REQUEST,
                )

            fee_accounts = fee_accounts.filter(
                status=fee_status
            )

        paginator = StandardResultsSetPagination()
        page = paginator.paginate_queryset(
            fee_accounts,
            request,
        )

        serializer = EnrollmentFeeAccountSerializer(
            page,
            many=True,
        )

        return paginator.get_paginated_response(
            serializer.data
        )

    def post(self, request):
        serializer = EnrollmentFeeAccountCreateSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                message="Fee account creation failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        try:
            fee_account = create_fee_account(
                firm=request.user.firm,
                created_by=request.user,
                validated_data=serializer.validated_data,
            )
        except ValidationError as exc:
            return error_response(
                message="Fee account creation failed",
                errors=exc.detail,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        return success_response(
            message="Fee account created successfully",
            data=EnrollmentFeeAccountSerializer(
                fee_account
            ).data,
            status_code=status.HTTP_201_CREATED,
        )


class InstallmentPaymentListCreateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get(self, request):
        installments = (
            InstallmentPayment.objects
            .filter(firm=request.user.firm)
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

        fee_account_uuid = request.query_params.get(
            "fee_account_uuid"
        )
        installment_status = request.query_params.get(
            "status"
        )

        if fee_account_uuid:
            installments = installments.filter(
                fee_account__uuid=fee_account_uuid
            )

        if installment_status:
            valid_statuses = [
                choice[0]
                for choice
                in InstallmentPayment.Status.choices
            ]

            if installment_status not in valid_statuses:
                return error_response(
                    message="Invalid installment status",
                    errors={
                        "status": [
                            "Use RECORDED or VOIDED."
                        ]
                    },
                    status_code=status.HTTP_400_BAD_REQUEST,
                )

            installments = installments.filter(
                status=installment_status
            )

        paginator = StandardResultsSetPagination()
        page = paginator.paginate_queryset(
            installments,
            request,
        )

        serializer = InstallmentPaymentSerializer(
            page,
            many=True,
        )

        return paginator.get_paginated_response(
            serializer.data
        )

    def post(self, request):
        serializer = InstallmentPaymentCreateSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                message="Installment payment recording failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        try:
            installment, fee_account = (
                record_installment_payment(
                    firm=request.user.firm,
                    recorded_by=request.user,
                    validated_data=serializer.validated_data,
                )
            )
        except ValidationError as exc:
            return error_response(
                message="Installment payment recording failed",
                errors=exc.detail,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        return success_response(
            message="Installment payment recorded successfully",
            data={
                "installment": InstallmentPaymentSerializer(
                    installment
                ).data,
                "fee_account": EnrollmentFeeAccountSerializer(
                    fee_account
                ).data,
            },
            status_code=status.HTTP_201_CREATED,
        )


class InstallmentPaymentVoidView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def patch(self, request, installment_uuid):
        serializer = InstallmentPaymentVoidSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                message="Installment void failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        try:
            installment, fee_account = (
                void_installment_payment(
                    firm=request.user.firm,
                    voided_by=request.user,
                    installment_uuid=installment_uuid,
                    validated_data=serializer.validated_data,
                )
            )
        except ValidationError as exc:
            return error_response(
                message="Installment void failed",
                errors=exc.detail,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        return success_response(
            message="Installment payment voided successfully",
            data={
                "installment": InstallmentPaymentSerializer(
                    installment
                ).data,
                "fee_account": EnrollmentFeeAccountSerializer(
                    fee_account
                ).data,
            },
        )
        
        
        
        
class StudentFeeAccountLedgerListView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsStudent,
    ]

    def get(self, request):
        student = request.user.student_profile

        installments_queryset = (
            InstallmentPayment.objects
            .filter(firm=request.user.firm)
            .order_by("-payment_date", "-created_at")
        )

        fee_accounts = (
            EnrollmentFeeAccount.objects
            .filter(
                firm=request.user.firm,
                enrollment__student=student,
            )
            .select_related(
                "enrollment",
                "enrollment__course",
            )
            .prefetch_related(
                Prefetch(
                    "installments",
                    queryset=installments_queryset,
                )
            )
            .order_by("-created_at")
        )

        paginator = StandardResultsSetPagination()

        page = paginator.paginate_queryset(
            fee_accounts,
            request,
        )

        serializer = StudentFeeAccountLedgerSerializer(
            page,
            many=True,
        )

        return paginator.get_paginated_response(
            serializer.data
        )
        
        
        
        
