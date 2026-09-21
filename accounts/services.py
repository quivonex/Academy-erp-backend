from rest_framework_simplejwt.tokens import RefreshToken
from django.db import transaction
from .models import User
from rest_framework.exceptions import ValidationError
from courses.models import Course
from students.models import Student
import uuid

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
    course_uuid = validated_data.pop("course_uuid")
    validated_data.pop("confirm_password")
    admission_number = (
    f"WEB-{uuid.uuid4().hex[:10].upper()}"
)
    password = validated_data.pop("password")

    try:
        course = Course.objects.select_related(
            "firm"
        ).get(
            uuid=course_uuid,
            is_active=True,
            is_published=True,
            is_purchasable_online=True,
            firm__is_active=True,
        )

    except Course.DoesNotExist:
        raise ValidationError({
            "course_uuid": [
                "Course is not available for online registration."
            ]
        })

    email = validated_data["email"]
    first_name = validated_data["first_name"]
    last_name = validated_data.get("last_name", "")
    phone = validated_data.get("phone", "")

    if User.objects.filter(
        email__iexact=email
    ).exists():
        raise ValidationError({
            "email": [
                "A user with this email already exists."
            ]
        })

    user = User.objects.create_user(
        email=email,
        password=password,
        first_name=first_name,
        last_name=last_name,
        phone=phone,
        firm=course.firm,
        user_type=User.UserType.STUDENT,
        is_active=True,
    )

    student = Student.objects.create(
        firm=course.firm,
        user=user,
        admission_number=admission_number,
        first_name=first_name,
        last_name=last_name,
        email=email,
        phone=phone,
        is_active=True,
    )
    return user, student, course


