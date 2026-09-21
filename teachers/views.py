from django.db.models import Q
from django.shortcuts import get_object_or_404

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from common.pagination import StandardResultsSetPagination
from common.permissions import IsFirmAdminOrStaff
from common.responses import error_response, success_response

from .models import Staff, Teacher
from .serializers import (
    StaffListSerializer,
    StaffSerializer,
    TeacherListSerializer,
    TeacherSerializer,
)
from .services import (
    activate_staff,
    activate_teacher,
    create_staff,
    create_teacher,
    deactivate_staff,
    deactivate_teacher,
    update_staff,
    update_teacher,
)


class TeacherListCreateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get(self, request):
        teachers = Teacher.objects.filter(
            firm=request.user.firm
        )

        search = request.query_params.get("search")

        if search:
            teachers = teachers.filter(
                Q(first_name__icontains=search)
                | Q(last_name__icontains=search)
                | Q(employee_id__icontains=search)
                | Q(email__icontains=search)
                | Q(phone__icontains=search)
                | Q(specialization__icontains=search)
            )

        is_active = request.query_params.get(
            "is_active"
        )

        if is_active is not None:
            if is_active.lower() == "true":
                teachers = teachers.filter(
                    is_active=True
                )
            elif is_active.lower() == "false":
                teachers = teachers.filter(
                    is_active=False
                )

        teachers = teachers.order_by(
            "-created_at"
        )

        paginator = StandardResultsSetPagination()

        page = paginator.paginate_queryset(
            teachers,
            request,
        )

        serializer = TeacherListSerializer(
            page,
            many=True,
        )

        return paginator.get_paginated_response(
            serializer.data
        )

    def post(self, request):
        serializer = TeacherSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                message="Teacher creation failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        employee_id = serializer.validated_data[
            "employee_id"
        ]

        if Teacher.objects.filter(
            firm=request.user.firm,
            employee_id=employee_id,
        ).exists():
            return error_response(
                message="Teacher creation failed",
                errors={
                    "employee_id": [
                        "Employee ID already exists."
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        teacher = create_teacher(
            firm=request.user.firm,
            validated_data=serializer.validated_data,
        )

        return success_response(
            message="Teacher created successfully",
            data=TeacherSerializer(teacher).data,
            status_code=status.HTTP_201_CREATED,
        )


class TeacherDetailView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get_object(self, request, teacher_uuid):
        return get_object_or_404(
            Teacher,
            uuid=teacher_uuid,
            firm=request.user.firm,
        )

    def get(self, request, teacher_uuid):
        teacher = self.get_object(
            request,
            teacher_uuid,
        )

        return success_response(
            message="Teacher retrieved successfully",
            data=TeacherSerializer(teacher).data,
        )

    def patch(self, request, teacher_uuid):
        teacher = self.get_object(
            request,
            teacher_uuid,
        )

        serializer = TeacherSerializer(
            teacher,
            data=request.data,
            partial=True,
        )

        if not serializer.is_valid():
            return error_response(
                message="Teacher update failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        employee_id = serializer.validated_data.get(
            "employee_id"
        )

        if employee_id:
            duplicate = Teacher.objects.filter(
                firm=request.user.firm,
                employee_id=employee_id,
            ).exclude(
                pk=teacher.pk
            ).exists()

            if duplicate:
                return error_response(
                    message="Teacher update failed",
                    errors={
                        "employee_id": [
                            "Employee ID already exists."
                        ]
                    },
                    status_code=status.HTTP_400_BAD_REQUEST,
                )

        teacher = update_teacher(
            teacher,
            serializer.validated_data,
        )

        return success_response(
            message="Teacher updated successfully",
            data=TeacherSerializer(teacher).data,
        )


class TeacherActivateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def patch(self, request, teacher_uuid):
        teacher = get_object_or_404(
            Teacher,
            uuid=teacher_uuid,
            firm=request.user.firm,
        )

        if teacher.is_active:
            return error_response(
                message="Teacher is already active.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        teacher = activate_teacher(teacher)

        return success_response(
            message="Teacher activated successfully",
            data=TeacherSerializer(teacher).data,
        )


class TeacherDeactivateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def patch(self, request, teacher_uuid):
        teacher = get_object_or_404(
            Teacher,
            uuid=teacher_uuid,
            firm=request.user.firm,
        )

        if not teacher.is_active:
            return error_response(
                message="Teacher is already inactive.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        teacher = deactivate_teacher(teacher)

        return success_response(
            message="Teacher deactivated successfully",
            data=TeacherSerializer(teacher).data,
        )


class StaffListCreateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get(self, request):
        staff_members = Staff.objects.filter(
            firm=request.user.firm
        )

        search = request.query_params.get("search")

        if search:
            staff_members = staff_members.filter(
                Q(first_name__icontains=search)
                | Q(last_name__icontains=search)
                | Q(employee_id__icontains=search)
                | Q(email__icontains=search)
                | Q(phone__icontains=search)
                | Q(designation__icontains=search)
                | Q(department__icontains=search)
            )

        is_active = request.query_params.get(
            "is_active"
        )

        if is_active is not None:
            if is_active.lower() == "true":
                staff_members = staff_members.filter(
                    is_active=True
                )
            elif is_active.lower() == "false":
                staff_members = staff_members.filter(
                    is_active=False
                )

        staff_members = staff_members.order_by(
            "-created_at"
        )

        paginator = StandardResultsSetPagination()

        page = paginator.paginate_queryset(
            staff_members,
            request,
        )

        serializer = StaffListSerializer(
            page,
            many=True,
        )

        return paginator.get_paginated_response(
            serializer.data
        )

    def post(self, request):
        serializer = StaffSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                message="Staff creation failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        employee_id = serializer.validated_data[
            "employee_id"
        ]

        if Staff.objects.filter(
            firm=request.user.firm,
            employee_id=employee_id,
        ).exists():
            return error_response(
                message="Staff creation failed",
                errors={
                    "employee_id": [
                        "Employee ID already exists."
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        staff = create_staff(
            firm=request.user.firm,
            validated_data=serializer.validated_data,
        )

        return success_response(
            message="Staff created successfully",
            data=StaffSerializer(staff).data,
            status_code=status.HTTP_201_CREATED,
        )


class StaffDetailView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get_object(self, request, staff_uuid):
        return get_object_or_404(
            Staff,
            uuid=staff_uuid,
            firm=request.user.firm,
        )

    def get(self, request, staff_uuid):
        staff = self.get_object(
            request,
            staff_uuid,
        )

        return success_response(
            message="Staff retrieved successfully",
            data=StaffSerializer(staff).data,
        )

    def patch(self, request, staff_uuid):
        staff = self.get_object(
            request,
            staff_uuid,
        )

        serializer = StaffSerializer(
            staff,
            data=request.data,
            partial=True,
        )

        if not serializer.is_valid():
            return error_response(
                message="Staff update failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        employee_id = serializer.validated_data.get(
            "employee_id"
        )

        if employee_id:
            duplicate = Staff.objects.filter(
                firm=request.user.firm,
                employee_id=employee_id,
            ).exclude(
                pk=staff.pk
            ).exists()

            if duplicate:
                return error_response(
                    message="Staff update failed",
                    errors={
                        "employee_id": [
                            "Employee ID already exists."
                        ]
                    },
                    status_code=status.HTTP_400_BAD_REQUEST,
                )

        staff = update_staff(
            staff,
            serializer.validated_data,
        )

        return success_response(
            message="Staff updated successfully",
            data=StaffSerializer(staff).data,
        )


class StaffActivateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def patch(self, request, staff_uuid):
        staff = get_object_or_404(
            Staff,
            uuid=staff_uuid,
            firm=request.user.firm,
        )

        if staff.is_active:
            return error_response(
                message="Staff is already active.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        staff = activate_staff(staff)

        return success_response(
            message="Staff activated successfully",
            data=StaffSerializer(staff).data,
        )


class StaffDeactivateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def patch(self, request, staff_uuid):
        staff = get_object_or_404(
            Staff,
            uuid=staff_uuid,
            firm=request.user.firm,
        )

        if not staff.is_active:
            return error_response(
                message="Staff is already inactive.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        staff = deactivate_staff(staff)

        return success_response(
            message="Staff deactivated successfully",
            data=StaffSerializer(staff).data,
        )
        
        
        
        
        
        