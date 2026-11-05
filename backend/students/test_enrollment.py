from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIRequestFactory, force_authenticate

from accounts.models import User
from courses.access import student_has_course_access
from courses.models import Course, Enrollment
from firms.models import Firm
from students.models import Student
from students.enrollment_views import StudentCourseEnrollmentView, StudentEnrollmentRequestsView

urlpatterns = []


class StudentEnrollmentTests(TestCase):
    def setUp(self):
        self.factory = APIRequestFactory()
        self.firm = Firm.objects.create(name="Academy", code="ACADEMY")
        self.user = User.objects.create_user(
            email="student@example.com", password="test",
            user_type=User.UserType.STUDENT, firm=self.firm,
        )
        self.student = Student.objects.create(
            user=self.user, firm=self.firm,
            admission_number="S1", first_name="Student",
        )
        self.course = Course.objects.create(
            firm=self.firm, name="Course", code="C1", price=100,
            is_published=True, is_purchasable_online=True,
        )

    def request(self, method="post", data=None, user=None, course=None):
        request = getattr(self.factory, method)("/", data or {}, format="json")
        force_authenticate(request, user=user or self.user)
        return StudentCourseEnrollmentView.as_view()(
            request, course_uuid=(course or self.course).uuid,
        )

    def test_request_is_pending_idempotent_and_does_not_grant_content(self):
        self.assertEqual(self.request().status_code, 201)
        response = self.request()
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["data"]["status"], "PENDING")
        self.assertFalse(response.data["data"]["has_access"])
        self.assertEqual(Enrollment.objects.count(), 1)
        enrollment = Enrollment.objects.get()
        self.assertIsNone(enrollment.granted_by)
        self.assertIsNone(enrollment.access_start_at)
        self.assertFalse(student_has_course_access(student=self.student, course=self.course))

    def test_client_cannot_choose_identity_or_access(self):
        response = self.request(data={"status": "ACTIVE", "student_uuid": "other"})
        self.assertEqual(response.status_code, 400)
        self.assertFalse(Enrollment.objects.exists())

    def test_other_academy_and_unpublished_courses_are_rejected(self):
        other = Firm.objects.create(name="Other", code="OTHER")
        foreign = Course.objects.create(
            firm=other, name="Other course", code="C2",
            is_published=True, is_purchasable_online=True,
        )
        self.assertEqual(self.request(course=foreign).status_code, 404)
        self.course.is_published = False
        self.course.save()
        self.assertEqual(self.request().status_code, 404)
        self.assertFalse(Enrollment.objects.exists())

    def test_inactive_student_and_nonstudent_cannot_request(self):
        self.student.is_active = False
        self.student.save()
        self.assertEqual(self.request().status_code, 404)
        admin = User.objects.create_user(
            email="admin@example.com", user_type=User.UserType.FIRM_ADMIN,
            firm=self.firm,
        )
        self.assertEqual(self.request(user=admin).status_code, 403)

    def test_unauthenticated_request_is_rejected(self):
        request = self.factory.post("/", {}, format="json")
        response = StudentCourseEnrollmentView.as_view()(request, course_uuid=self.course.uuid)
        self.assertIn(response.status_code, (401, 403))

    def test_approved_request_has_access_and_is_not_pending(self):
        self.request()
        enrollment = Enrollment.objects.get()
        from courses.serializers import EnrollmentSerializer
        serializer = EnrollmentSerializer(
            enrollment, data={"status": Enrollment.Status.ACTIVE}, partial=True,
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        enrollment.refresh_from_db()
        self.assertIsNotNone(enrollment.access_start_at)
        response = self.request("get")
        self.assertTrue(response.data["data"]["has_access"])
        request = self.factory.get("/")
        force_authenticate(request, user=self.user)
        response = StudentEnrollmentRequestsView.as_view()(request)
        self.assertEqual(response.data["data"]["count"], 0)

    def test_pending_list_is_scoped_to_signed_in_student(self):
        self.request()
        other_user = User.objects.create_user(
            email="other@example.com", user_type=User.UserType.STUDENT, firm=self.firm,
        )
        Student.objects.create(
            user=other_user, firm=self.firm, admission_number="S2", first_name="Other",
        )
        request = self.factory.get("/")
        force_authenticate(request, user=other_user)
        response = StudentEnrollmentRequestsView.as_view()(request)
        self.assertEqual(response.data["data"]["count"], 0)

    def test_cancelled_enrollment_is_not_reactivated_by_student(self):
        self.request()
        enrollment = Enrollment.objects.get()
        enrollment.status = Enrollment.Status.CANCELLED
        enrollment.save()
        response = self.request()
        self.assertEqual(response.data["data"]["status"], "CANCELLED")
        self.assertFalse(response.data["data"]["has_access"])
