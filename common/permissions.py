from rest_framework.permissions import BasePermission

from accounts.models import User


class IsSuperAdmin(BasePermission):
    message = "Only super admin can perform this action."

    def has_permission(self, request, view):
        return (
            request.user
            and request.user.is_authenticated
            and request.user.user_type
            == User.UserType.SUPER_ADMIN
        )


class IsFirmAdmin(BasePermission):
    message = "Only firm admin can perform this action."

    def has_permission(self, request, view):
        return (
            request.user
            and request.user.is_authenticated
            and request.user.user_type
            == User.UserType.FIRM_ADMIN
            and request.user.firm_id is not None
            and request.user.firm.is_active
        )


class IsFirmStaffOrAdmin(BasePermission):
    message = "You do not have permission to perform this action."

    def has_permission(self, request, view):
        return (
            request.user
            and request.user.is_authenticated
            and request.user.user_type
            in [
                User.UserType.FIRM_ADMIN,
                User.UserType.FIRM_STAFF,
            ]
            and request.user.firm_id is not None
            and request.user.firm.is_active
        )


class IsFirmAdminOrStaff(BasePermission):
    message = "Only firm admin or firm staff can perform this action."

    def has_permission(self, request, view):
        if not (
            request.user
            and request.user.is_authenticated
        ):
            return False

        if request.user.user_type not in [
            User.UserType.FIRM_ADMIN,
            User.UserType.FIRM_STAFF,
        ]:
            return False

        if not request.user.firm_id:
            return False

        return request.user.firm.is_active


class IsFirmAcademicStaff(BasePermission):
    """
    Allows firm admin, firm staff, and teacher users.

    Assignment review views add an extra rule:
    a teacher can review only assignments linked to
    the subject assigned to that teacher.
    """

    message = (
        "Only academy admin, staff, or teacher "
        "can access this resource."
    )

    def has_permission(self, request, view):
        if not (
            request.user
            and request.user.is_authenticated
        ):
            return False

        if request.user.user_type not in [
            User.UserType.FIRM_ADMIN,
            User.UserType.FIRM_STAFF,
            User.UserType.TEACHER,
        ]:
            return False

        if not request.user.firm_id:
            return False

        if not request.user.firm.is_active:
            return False

        if (
            request.user.user_type
            == User.UserType.TEACHER
        ):
            return hasattr(
                request.user,
                "teacher_profile",
            )

        return True


class IsStudent(BasePermission):
    message = "Only students can access this resource."

    def has_permission(self, request, view):
        if not (
            request.user
            and request.user.is_authenticated
        ):
            return False

        if (
            request.user.user_type
            != User.UserType.STUDENT
        ):
            return False

        if not request.user.firm_id:
            return False

        if not request.user.firm.is_active:
            return False

        return hasattr(
            request.user,
            "student_profile",
        )
        
        
        