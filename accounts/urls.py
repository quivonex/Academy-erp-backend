from django.urls import path

from rest_framework_simplejwt.views import TokenRefreshView

from .views import (
    LoginView,
    LogoutView,
    MeView,
    StudentRegisterView,
    PasswordResetRequestView,
    PasswordResetConfirmView,

)


urlpatterns = [
    path("login/", LoginView.as_view(), name="login",),
    path("refresh/", TokenRefreshView.as_view(), name="token-refresh",),
    path("logout/", LogoutView.as_view(), name="logout",),
    path("me/", MeView.as_view(), name="me",),  
    
    path("student/register/", StudentRegisterView.as_view(), name="student-register",),
    
    path("password-reset/request/", PasswordResetRequestView.as_view(), name="password-reset-request",),
    path("password-reset/confirm/", PasswordResetConfirmView.as_view(), name="password-reset-confirm",),
    
]