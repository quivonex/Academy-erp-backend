from rest_framework_simplejwt.tokens import RefreshToken
from django.db import transaction
from .models import User
from rest_framework.exceptions import ValidationError
from students.models import Student
import uuid
from firms.models import Firm
from django.conf import settings


def generate_tokens_for_user(user):
    refresh = RefreshToken.for_user(user)
    refresh["auth_version"] = user.auth_version
    refresh["user_uuid"] = str(user.uuid)
    refresh["user_type"] = user.user_type

    if user.firm:
        refresh["firm_uuid"] = str(user.firm.uuid)

    return {
        "access": str(refresh.access_token),
        "refresh": str(refresh),
    }
    
    
@transaction.atomic
def create_firm_admin(firm, validated_data):
    validated_data.pop(
        "confirm_password",
        None,
    )

    password = validated_data.pop(
        "password"
    )

    user = User.objects.create_user(
        firm=firm,
        user_type=User.UserType.FIRM_ADMIN,
        password=password,
        **validated_data,
    )

    return user

    
@transaction.atomic
def register_student(validated_data):
    validated_data.pop(
        "confirm_password",
        None,
    )

    password = validated_data.pop(
        "password"
    )

    firm_code = settings.DEFAULT_FIRM_CODE

    if not firm_code:
        raise ValidationError({
            "firm": [
                "Default academy is not configured."
            ]
        })

    try:
        firm = Firm.objects.get(
            code=firm_code,
            is_active=True,
            status=Firm.Status.ACTIVE,
        )

    except Firm.DoesNotExist:
        raise ValidationError({
            "firm": [
                "Configured academy was not found or is inactive."
            ]
        })

    email = validated_data["email"]
    first_name = validated_data["first_name"]

    last_name = validated_data.get(
        "last_name",
        "",
    )

    phone = validated_data.get(
        "phone",
        "",
    )

    if User.objects.filter(
        email__iexact=email
    ).exists():
        raise ValidationError({
            "email": [
                "A user with this email already exists."
            ]
        })

    admission_number = (
        f"WEB-{uuid.uuid4().hex[:10].upper()}"
    )

    user = User.objects.create_user(
        email=email,
        password=password,
        first_name=first_name,
        last_name=last_name,
        phone=phone,
        firm=firm,
        user_type=User.UserType.STUDENT,
        is_active=True,
    )

    student = Student.objects.create(
        firm=firm,
        user=user,
        admission_number=admission_number,
        first_name=first_name,
        last_name=last_name,
        email=email,
        phone=phone,
        is_active=True,
    )

    return user, student



import secrets
from datetime import timedelta

from django.conf import settings
from django.contrib.auth.hashers import check_password, make_password
from django.core.mail import send_mail
from django.db import transaction
from django.utils import timezone
from rest_framework_simplejwt.token_blacklist.models import (
    BlacklistedToken,
    OutstandingToken,
)

from .models import PasswordResetOTP


class PasswordResetError(Exception):
    pass


def send_password_reset_otp(email):
    user = User.objects.filter(
        email__iexact=email.strip().lower(),
        is_active=True,
    ).first()

    # Never reveal whether an email exists.
    if user is None:
        return

    now = timezone.now()

    PasswordResetOTP.objects.filter(
        user=user,
        used_at__isnull=True,
    ).update(used_at=now)

    otp = f"{secrets.randbelow(1000000):06d}"

    reset_otp = PasswordResetOTP.objects.create(
        user=user,
        otp_hash=make_password(otp),
        expires_at=now + timedelta(
            minutes=settings.PASSWORD_RESET_OTP_MINUTES,
        ),
    )

    try:
        send_mail(
            subject="Your VidyaSetu password reset code",
            message=(
                f"Hello {user.full_name or user.email},\n\n"
                f"Your password reset OTP is: {otp}\n\n"
                f"This OTP expires in "
                f"{settings.PASSWORD_RESET_OTP_MINUTES} minutes.\n"
                "Do not share this OTP with anyone.\n\n"
                "If you did not request this, you can ignore this email."
            ),
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[user.email],
            fail_silently=False,
        )
    except Exception:
        reset_otp.delete()
        raise


@transaction.atomic
def reset_password_with_otp(email, otp, new_password):
    user = User.objects.filter(
        email__iexact=email.strip().lower(),
        is_active=True,
    ).first()

    if user is None:
        raise PasswordResetError("Invalid or expired OTP.")

    reset_otp = (
        PasswordResetOTP.objects
        .filter(user=user)
        .order_by("-created_at")
        .first()
    )

    now = timezone.now()

    if (
        reset_otp is None
        or reset_otp.used_at is not None
        or reset_otp.expires_at <= now
        or reset_otp.attempts >= settings.PASSWORD_RESET_OTP_MAX_ATTEMPTS
    ):
        raise PasswordResetError("Invalid or expired OTP.")

    if not check_password(otp, reset_otp.otp_hash):
        reset_otp.attempts += 1
        reset_otp.save(update_fields=["attempts"])

        raise PasswordResetError("Invalid or expired OTP.")

    user.set_password(new_password)
    user.auth_version += 1
    user.save(update_fields=[
        "password",
        "auth_version",
        "updated_at",
    ])

    reset_otp.used_at = now
    reset_otp.save(update_fields=["used_at"])

    PasswordResetOTP.objects.filter(
        user=user,
        used_at__isnull=True,
    ).exclude(pk=reset_otp.pk).update(used_at=now)

    for token in OutstandingToken.objects.filter(user=user):
        BlacklistedToken.objects.get_or_create(token=token)