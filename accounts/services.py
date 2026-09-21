from rest_framework_simplejwt.tokens import RefreshToken
from django.db import transaction
from .models import User
from rest_framework.exceptions import ValidationError
from courses.models import Course
from students.models import Student
import uuid
from firms.models import Firm


def generate_tokens_for_user(user):
    refresh = RefreshToken.for_user(user)

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

    firms = Firm.objects.filter(
        is_active=True
    )

    if not firms.exists():
        raise ValidationError({
            "firm": [
                "No active academy is configured."
            ]
        })

    if firms.count() > 1:
        raise ValidationError({
            "firm": [
                "Multiple active academies are configured. "
                "Please contact the administrator."
            ]
        })

    firm = firms.first()

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

