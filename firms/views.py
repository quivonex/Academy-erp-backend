from django.shortcuts import get_object_or_404

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from common.permissions import IsSuperAdmin
from common.responses import (
    error_response,
    success_response,
)

from .models import Firm
from accounts.models import User
from accounts.serializers import (
    FirmAdminCreateSerializer,
    UserSerializer,)

from accounts.services import (create_firm_admin,)

from .serializers import (
    FirmListSerializer,
    FirmSerializer,
)
from .services import (
    activate_firm,
    create_firm,
    deactivate_firm,
    update_firm,
)


class FirmListCreateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsSuperAdmin,
    ]

    def get(self, request):
        firms = Firm.objects.all().order_by("-created_at")

        serializer = FirmListSerializer(
            firms,
            many=True,
        )

        return success_response(
            message="Firms retrieved successfully",
            data=serializer.data,
        )

    def post(self, request):
        serializer = FirmSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                message="Firm creation failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        firm = create_firm(
            serializer.validated_data
        )

        return success_response(
            message="Firm created successfully",
            data=FirmSerializer(firm).data,
            status_code=status.HTTP_201_CREATED,
        )


class FirmDetailView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsSuperAdmin,
    ]

    def get_object(self, firm_uuid):
        return get_object_or_404(
            Firm,
            uuid=firm_uuid,
        )

    def get(self, request, firm_uuid):
        firm = self.get_object(firm_uuid)

        return success_response(
            message="Firm retrieved successfully",
            data=FirmSerializer(firm).data,
        )

    def patch(self, request, firm_uuid):
        firm = self.get_object(firm_uuid)

        serializer = FirmSerializer(
            firm,
            data=request.data,
            partial=True,
        )

        if not serializer.is_valid():
            return error_response(
                message="Firm update failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        firm = update_firm(
            firm,
            serializer.validated_data,
        )

        return success_response(
            message="Firm updated successfully",
            data=FirmSerializer(firm).data,
        )
        

class FirmDeactivateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsSuperAdmin,
    ]

    def patch(self, request, firm_uuid):
        firm = get_object_or_404(
            Firm,
            uuid=firm_uuid,
        )

        if not firm.is_active:
            return error_response(
                message="Firm is already inactive.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        firm = deactivate_firm(firm)

        return success_response(
            message="Firm deactivated successfully",
            data=FirmSerializer(firm).data,
        )


class FirmActivateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsSuperAdmin,
    ]

    def patch(self, request, firm_uuid):
        firm = get_object_or_404(
            Firm,
            uuid=firm_uuid,
        )

        if firm.is_active:
            return error_response(
                message="Firm is already active.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        firm = activate_firm(firm)

        return success_response(
            message="Firm activated successfully",
            data=FirmSerializer(firm).data,
        )
        
        
class FirmAdminCreateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsSuperAdmin,
    ]

    def post(self, request, firm_uuid):
        firm = get_object_or_404(
            Firm,
            uuid=firm_uuid,
        )

        if not firm.is_active:
            return error_response(
                message=(
                    "Cannot create an admin for "
                    "an inactive firm."
                ),
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        serializer = FirmAdminCreateSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                message="Firm admin creation failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        user = create_firm_admin(
            firm=firm,
            validated_data=serializer.validated_data,
        )

        return success_response(
            message="Firm admin created successfully",
            data=UserSerializer(user).data,
            status_code=status.HTTP_201_CREATED,
        )
        
        
        
class FirmAdminListView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsSuperAdmin,
    ]

    def get(self, request, firm_uuid):
        firm = get_object_or_404(
            Firm,
            uuid=firm_uuid,
        )

        admins = User.objects.filter(
            firm=firm,
            user_type=User.UserType.FIRM_ADMIN,
        ).order_by("-date_joined")

        return success_response(
            message="Firm admins retrieved successfully",
            data=UserSerializer(
                admins,
                many=True,
            ).data,
        )
        
        