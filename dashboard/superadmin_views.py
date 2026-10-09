from django.db.models import Count, Q

from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from common.permissions import IsSuperAdmin
from common.responses import success_response
from courses.models import Course, Enrollment
from firms.models import Firm
from payments.models import EnrollmentFeeAccount
from students.models import Student


class SuperAdminDashboardSummaryView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsSuperAdmin,
    ]

    def get(self, request):
        firm_queryset = (
            Firm.objects
            .annotate(
                total_students=Count(
                    "students",
                    distinct=True,
                ),
                active_students=Count(
                    "students",
                    filter=Q(students__is_active=True),
                    distinct=True,
                ),
                total_courses=Count(
                    "courses",
                    distinct=True,
                ),
                active_courses=Count(
                    "courses",
                    filter=Q(courses__is_active=True),
                    distinct=True,
                ),
                total_enrollments=Count(
                    "enrollments",
                    distinct=True,
                ),
                active_enrollments=Count(
                    "enrollments",
                    filter=Q(
                        enrollments__status=Enrollment.Status.ACTIVE,
                    ),
                    distinct=True,
                ),
                students_with_active_course_access=Count(
                    "enrollments__student",
                    filter=Q(
                        enrollments__status=Enrollment.Status.ACTIVE,
                    ),
                    distinct=True,
                ),
                students_with_online_purchases=Count(
                    "enrollments__student",
                    filter=Q(
                        enrollments__source=(
                            Enrollment.Source.ONLINE_PURCHASE
                        ),
                    ),
                    distinct=True,
                ),
                paid_enrollments=Count(
                    "fee_accounts",
                    filter=Q(
                        fee_accounts__status=(
                            EnrollmentFeeAccount.Status.PAID
                        ),
                    ),
                    distinct=True,
                ),
                students_with_paid_enrollments=Count(
                    "fee_accounts__enrollment__student",
                    filter=Q(
                        fee_accounts__status=(
                            EnrollmentFeeAccount.Status.PAID
                        ),
                    ),
                    distinct=True,
                ),
            )
            .order_by("name")
        )

        course_rows = (
            Course.objects
            .select_related("firm")
            .annotate(
                enrolled_students=Count(
                    "enrollments__student",
                    distinct=True,
                ),
                active_enrollments=Count(
                    "enrollments",
                    filter=Q(
                        enrollments__status=Enrollment.Status.ACTIVE,
                    ),
                    distinct=True,
                ),
            )
            .order_by("firm__name", "name")
        )

        courses_by_firm = {}

        for course in course_rows:
            courses_by_firm.setdefault(
                course.firm_id,
                [],
            ).append({
                "uuid": str(course.uuid),
                "name": course.name,
                "code": course.code,
                "is_active": course.is_active,
                "is_published": course.is_published,
                "enrolled_students": course.enrolled_students,
                "active_enrollments": (
                    course.active_enrollments
                ),
            })

        firms = []

        for firm in firm_queryset:
            firms.append({
                "uuid": str(firm.uuid),
                "name": firm.name,
                "code": firm.code,
                "status": firm.status,
                "is_active": firm.is_active,
                "total_students": firm.total_students,
                "active_students": firm.active_students,
                "total_courses": firm.total_courses,
                "active_courses": firm.active_courses,
                "total_enrollments": firm.total_enrollments,
                "active_enrollments": (
                    firm.active_enrollments
                ),
                "students_with_active_course_access": (
                    firm.students_with_active_course_access
                ),
                "students_with_online_purchases": (
                    firm.students_with_online_purchases
                ),
                "paid_enrollments": firm.paid_enrollments,
                "students_with_paid_enrollments": (
                    firm.students_with_paid_enrollments
                ),
                "courses": courses_by_firm.get(
                    firm.id,
                    [],
                ),
            })

        return success_response(
            message=(
                "Super admin dashboard retrieved successfully"
            ),
            data={
                "summary": {
                    "total_firms": Firm.objects.count(),
                    "active_firms": Firm.objects.filter(
                        is_active=True,
                    ).count(),
                    "inactive_firms": Firm.objects.filter(
                        is_active=False,
                    ).count(),
                    "total_students": Student.objects.count(),
                    "active_students": Student.objects.filter(
                        is_active=True,
                    ).count(),
                    "total_courses": Course.objects.count(),
                    "active_courses": Course.objects.filter(
                        is_active=True,
                    ).count(),
                    "total_enrollments": Enrollment.objects.count(),
                    "active_enrollments": Enrollment.objects.filter(
                        status=Enrollment.Status.ACTIVE,
                    ).count(),
                    "students_with_active_course_access": (
                        Enrollment.objects
                        .filter(
                            status=Enrollment.Status.ACTIVE,
                        )
                        .values("student_id")
                        .distinct()
                        .count()
                    ),
                    "students_with_online_purchases": (
                        Enrollment.objects
                        .filter(
                            source=Enrollment.Source.ONLINE_PURCHASE,
                        )
                        .values("student_id")
                        .distinct()
                        .count()
                    ),
                    "paid_enrollments": (
                        EnrollmentFeeAccount.objects
                        .filter(
                            status=EnrollmentFeeAccount.Status.PAID,
                        )
                        .count()
                    ),
                    "students_with_paid_enrollments": (
                        EnrollmentFeeAccount.objects
                        .filter(
                            status=EnrollmentFeeAccount.Status.PAID,
                        )
                        .values("enrollment__student_id")
                        .distinct()
                        .count()
                    ),
                },
                "firms": firms,
            },
        )