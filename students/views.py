from django.db.models import Q
from django.shortcuts import get_object_or_404

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from common.pagination import StandardResultsSetPagination
from common.permissions import IsFirmAdminOrStaff
from common.responses import (
    error_response,
    success_response,
)

from .models import Student
from .serializers import (
    StudentListSerializer,
    StudentSerializer,
)
from .services import (
    activate_student,
    create_student,
    deactivate_student,
    update_student,
)
from rest_framework.exceptions import ValidationError
from accounts.serializers import UserSerializer
from .serializers import StudentEnableLoginSerializer
from .services import enable_student_login



class StudentListCreateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get(self, request):
        students = Student.objects.filter(
            firm=request.user.firm,
        )

        search = request.query_params.get(
            "search"
        )

        if search:
            students = students.filter(
                Q(first_name__icontains=search)
                | Q(last_name__icontains=search)
                | Q(admission_number__icontains=search)
                | Q(email__icontains=search)
                | Q(phone__icontains=search)
            )

        is_active = request.query_params.get(
            "is_active"
        )

        if is_active is not None:
            if is_active.lower() == "true":
                students = students.filter(
                    is_active=True
                )

            elif is_active.lower() == "false":
                students = students.filter(
                    is_active=False
                )

        students = students.order_by(
            "-created_at"
        )

        paginator = StandardResultsSetPagination()

        page = paginator.paginate_queryset(
            students,
            request,
        )

        serializer = StudentListSerializer(
            page,
            many=True,
        )

        return paginator.get_paginated_response(
            serializer.data
        )

    def post(self, request):
        serializer = StudentSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                message="Student creation failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        admission_number = (
            serializer.validated_data[
                "admission_number"
            ]
        )

        if Student.objects.filter(
            firm=request.user.firm,
            admission_number=admission_number,
        ).exists():
            return error_response(
                message="Student creation failed",
                errors={
                    "admission_number": [
                        (
                            "A student with this admission "
                            "number already exists."
                        )
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        student = create_student(
            firm=request.user.firm,
            validated_data=serializer.validated_data,
        )

        return success_response(
            message="Student created successfully",
            data=StudentSerializer(student).data,
            status_code=status.HTTP_201_CREATED,
        )


class StudentDetailView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get_object(
        self,
        request,
        student_uuid,
    ):
        return get_object_or_404(
            Student,
            uuid=student_uuid,
            firm=request.user.firm,
        )

    def get(
        self,
        request,
        student_uuid,
    ):
        student = self.get_object(
            request,
            student_uuid,
        )

        return success_response(
            message="Student retrieved successfully",
            data=StudentSerializer(student).data,
        )

    def patch(
        self,
        request,
        student_uuid,
    ):
        student = self.get_object(
            request,
            student_uuid,
        )

        serializer = StudentSerializer(
            student,
            data=request.data,
            partial=True,
        )

        if not serializer.is_valid():
            return error_response(
                message="Student update failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        admission_number = (
            serializer.validated_data.get(
                "admission_number"
            )
        )

        if admission_number:
            duplicate = Student.objects.filter(
                firm=request.user.firm,
                admission_number=admission_number,
            ).exclude(
                pk=student.pk
            ).exists()

            if duplicate:
                return error_response(
                    message="Student update failed",
                    errors={
                        "admission_number": [
                            (
                                "A student with this admission "
                                "number already exists."
                            )
                        ]
                    },
                    status_code=status.HTTP_400_BAD_REQUEST,
                )

        student = update_student(
            student,
            serializer.validated_data,
        )

        return success_response(
            message="Student updated successfully",
            data=StudentSerializer(student).data,
        )


class StudentDeactivateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def patch(
        self,
        request,
        student_uuid,
    ):
        student = get_object_or_404(
            Student,
            uuid=student_uuid,
            firm=request.user.firm,
        )

        if not student.is_active:
            return error_response(
                message="Student is already inactive.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        student = deactivate_student(student)

        return success_response(
            message="Student deactivated successfully",
            data=StudentSerializer(student).data,
        )


class StudentActivateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def patch(
        self,
        request,
        student_uuid,
    ):
        student = get_object_or_404(
            Student,
            uuid=student_uuid,
            firm=request.user.firm,
        )

        if student.is_active:
            return error_response(
                message="Student is already active.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        student = activate_student(student)

        return success_response(
            message="Student activated successfully",
            data=StudentSerializer(student).data,
        )
        
        
class StudentEnableLoginView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def post(self, request, student_uuid):
        student = get_object_or_404(
            Student,
            uuid=student_uuid,
            firm=request.user.firm,
        )

        serializer = StudentEnableLoginSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                message="Student login creation failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        try:
            user = enable_student_login(
                student=student,
                email=serializer.validated_data["email"],
                password=serializer.validated_data["password"],
            )

        except ValidationError as exc:
            return error_response(
                message="Student login creation failed",
                errors=exc.detail,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        return success_response(
            message="Student login enabled successfully",
            data=UserSerializer(user).data,
            status_code=status.HTTP_201_CREATED,
        )
        
        
        
