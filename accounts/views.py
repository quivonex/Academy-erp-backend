from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.views import APIView
from rest_framework import status
from rest_framework.exceptions import ValidationError
from rest_framework_simplejwt.views import TokenRefreshView

from common.responses import (
    error_response,
    success_response,
)

from .serializers import (
    LoginSerializer,
    LogoutSerializer,
    UserSerializer,
    FirmAdminCreateSerializer,
    StudentRegisterSerializer,

)

from .services import (
    generate_tokens_for_user,
    register_student,
)
from accounts.services import (create_firm_admin,)

class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = LoginSerializer(
            data=request.data,
            context={"request": request},
        )

        if not serializer.is_valid():
            return error_response(
                message="Login failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        user = serializer.validated_data["user"]

        tokens = generate_tokens_for_user(user)

        return success_response(
            message="Login successful",
            data={
                "user": UserSerializer(user).data,
                "tokens": tokens,
            },
        )


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = LogoutSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                message="Logout failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        try:
            serializer.save()

        except Exception:
            return error_response(
                message="Invalid or expired refresh token.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        return success_response(
            message="Logout successful"
        )


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return success_response(
            message="User profile retrieved successfully",
            data=UserSerializer(request.user).data,
        )
        
        
        
class StudentRegisterView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        serializer = StudentRegisterSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                message="Registration failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        try:
            user, student = register_student(
                serializer.validated_data
            )

        except ValidationError as exc:
            return error_response(
                message="Registration failed",
                errors=exc.detail,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        return success_response(
            message="Student account created successfully",
            data={
                "user": UserSerializer(user).data,
                "student_uuid": str(student.uuid),
                "admission_number": student.admission_number,
            },
            status_code=status.HTTP_201_CREATED,
        )        
        

        
