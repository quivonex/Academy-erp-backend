from django.test import TestCase
from rest_framework.test import APIRequestFactory, force_authenticate
from accounts.models import User
from courses.models import Course, Enrollment
from firms.models import Firm
from students.models import Student
from students.enrollment_views import StudentCourseEnrollmentView

urlpatterns = []


class StudentEnrollmentTests(TestCase):
    def setUp(self):
        self.factory = APIRequestFactory()
        self.firm = Firm.objects.create(name="Academy", code="ACADEMY")
        self.user = User.objects.create_user(
            email="student@example.com", user_type=User.UserType.STUDENT,
            firm=self.firm,
        )
        self.student = Student.objects.create(
            user=self.user, firm=self.firm, admission_number="S1", first_name="Student",
        )
        self.course = Course.objects.create(
            firm=self.firm, name="Course", code="C1", price=100,
            is_published=True, is_purchasable_online=True,
        )

    def request(self, method="post", data=None, course=None):
        request = getattr(self.factory, method)("/", data or {}, format="json")
        force_authenticate(request, user=self.user)
        return StudentCourseEnrollmentView.as_view()(
            request, course_uuid=(course or self.course).uuid,
        )

    def test_students_cannot_enroll_in_paid_or_free_courses(self):
        for price in (100, 0):
            self.course.price = price
            self.course.save()
            self.assertEqual(self.request().status_code, 403)
        self.assertFalse(Enrollment.objects.exists())

    def test_student_cannot_override_status_or_create_pending_request(self):
        for payload in ({}, {"status": "ACTIVE"}, {"status": "PENDING"}):
            self.assertEqual(self.request(data=payload).status_code, 403)
        self.assertFalse(Enrollment.objects.exists())

    def test_existing_enrollment_is_not_modified_by_student(self):
        enrollment = Enrollment.objects.create(
            firm=self.firm, student=self.student, course=self.course,
            status=Enrollment.Status.CANCELLED,
        )
        self.assertEqual(self.request().status_code, 403)
        enrollment.refresh_from_db()
        self.assertEqual(enrollment.status, Enrollment.Status.CANCELLED)

    def test_admin_activation_unlocks_access(self):
        enrollment = Enrollment.objects.create(
            firm=self.firm, student=self.student, course=self.course,
            status=Enrollment.Status.PENDING,
        )
        self.assertFalse(self.request("get").data["data"]["has_access"])
        from courses.serializers import EnrollmentSerializer
        serializer = EnrollmentSerializer(
            enrollment, data={"status": Enrollment.Status.ACTIVE}, partial=True,
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        self.assertTrue(self.request("get").data["data"]["has_access"])

    def test_status_is_scoped_to_own_academy(self):
        other = Firm.objects.create(name="Other", code="OTHER")
        course = Course.objects.create(
            firm=other, name="Other course", code="C2",
            is_published=True, is_purchasable_online=True,
        )
        self.assertEqual(self.request("get", course=course).status_code, 404)

    def test_unauthenticated_enrollment_is_rejected(self):
        request = self.factory.post("/", {}, format="json")
        response = StudentCourseEnrollmentView.as_view()(
            request, course_uuid=self.course.uuid,
        )
        self.assertIn(response.status_code, (401, 403))
