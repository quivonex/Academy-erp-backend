from rest_framework import status
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from common.pagination import StandardResultsSetPagination
from common.permissions import IsFirmAdminOrStaff, IsStudent
from common.responses import error_response, success_response

from .models import CoursePayment
from .serializers import (
    CoursePaymentReviewSerializer,
    CoursePaymentSerializer,
    StudentCoursePaymentCreateSerializer,
)
from .services import create_course_payment, review_course_payment


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
        return paginator.get_paginated_response({
            "success": True,
            "message": "Payment history retrieved successfully",
            "data": serializer.data,
        })

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
        return paginator.get_paginated_response({
            "success": True,
            "message": "Payment requests retrieved successfully",
            "data": serializer.data,
        })


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