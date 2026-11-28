from datetime import timedelta
from io import BytesIO
from unittest.mock import patch
from django.utils import timezone
from rest_framework.test import APITestCase
from accounts.models import User
from firms.models import Firm
from students.models import Student
from courses.models import Course, Enrollment
from materials.models import LearningMaterial
from progress.models import StudentMaterialProgress, StudentVideoWatchSession
from .models import Batch, BatchMembership, AttendanceRecord, EnrollmentRenewal, JobOpening, JobApplication


class WorkflowTests(APITestCase):
    def setUp(self):
        self.firm = Firm.objects.create(name="Test Academy", code="OPS")
        self.other = Firm.objects.create(name="Other Academy", code="OTHER")
        self.admin = User.objects.create_user(email="admin@ops.test", password="secret123", user_type="FIRM_ADMIN", firm=self.firm)
        self.user = User.objects.create_user(email="student@ops.test", password="secret123", user_type="STUDENT", firm=self.firm)
        self.student = Student.objects.create(firm=self.firm, user=self.user, admission_number="S001", first_name="Asha", last_name="Patil")
        self.student2 = Student.objects.create(firm=self.firm, admission_number="S002", first_name="Ravi", last_name="Jadhav")
        self.course = Course.objects.create(firm=self.firm, name="Python", code="PY", delivery_mode="HYBRID", access_duration_days=90)
        self.now = timezone.now()
        self.today = timezone.localdate()
        self.enrollment = Enrollment.objects.create(firm=self.firm, student=self.student, course=self.course, status="ACTIVE", access_start_at=self.now - timedelta(days=10), access_end_at=self.now + timedelta(days=80))
        self.first = LearningMaterial.objects.create(firm=self.firm, course=self.course, title="First", material_type="VIDEO", sequence=1, duration_seconds=100, file_key="first.mp4")
        self.second = LearningMaterial.objects.create(firm=self.firm, course=self.course, title="Second", material_type="VIDEO", sequence=2, duration_seconds=100, file_key="second.mp4")
        self.batch = Batch.objects.create(firm=self.firm, course=self.course, name="Morning", start_date=self.today - timedelta(days=10), end_date=self.today + timedelta(days=60))
        self.member = BatchMembership.objects.create(firm=self.firm, batch=self.batch, enrollment=self.enrollment, joined_on=self.today - timedelta(days=10))
        self.client.force_authenticate(self.admin)

    def url(self, suffix):
        return "/api/v1/" + suffix

    def job(self, **extra):
        data = dict(firm=self.firm, title="Developer", company_name="Test Co", description="Python role", location="Pune", application_deadline=self.now + timedelta(days=4), is_published=True)
        data.update(extra)
        return JobOpening.objects.create(**data)

    def mark(self, **extra):
        data = {"date": str(self.today), "records": [{"student_uuid": str(self.student.uuid), "status": "PRESENT"}]}
        data.update(extra)
        return self.client.post(self.url(f"batches/{self.batch.uuid}/attendance/"), data, format="json")

    def test_course_material_list_is_scoped(self):
        other = Course.objects.create(firm=self.firm, name="Java", code="JAVA")
        LearningMaterial.objects.create(firm=self.firm, course=other, title="Other", material_type="PDF")
        response = self.client.get(self.url(f"courses/{self.course.uuid}/materials/"))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["data"]["count"], 2)

    def test_course_material_path_overrides_body_course(self):
        other = Course.objects.create(firm=self.other, name="Other", code="X")
        response = self.client.post(self.url(f"courses/{self.course.uuid}/materials/"), {"course_uuid": str(other.uuid), "title": "Docs", "material_type": "LINK", "external_url": "https://example.com/docs"}, format="json")
        self.assertEqual(response.status_code, 201, response.data)
        self.assertTrue(LearningMaterial.objects.filter(course=self.course, title="Docs").exists())

    def test_locked_video_does_not_expose_url(self):
        self.client.force_authenticate(self.user)
        response = self.client.get(self.url(f"student/courses/{self.course.uuid}/materials/"))
        videos = response.data["data"]["results"]
        self.assertFalse(videos[0]["is_locked"])
        self.assertTrue(videos[1]["is_locked"])
        self.assertIsNone(videos[1]["content_url"])
        self.assertEqual(videos[1]["prerequisite_material_uuid"], str(self.first.uuid))

    def test_locked_video_detail_and_session_are_denied(self):
        self.client.force_authenticate(self.user)
        self.assertEqual(self.client.get(self.url(f"student/materials/{self.second.uuid}/")).status_code, 403)
        self.assertEqual(self.client.post(self.url(f"student/materials/{self.second.uuid}/watch-sessions/")).status_code, 403)

    def test_unverified_progress_cannot_unlock(self):
        StudentMaterialProgress.objects.create(firm=self.firm, student=self.student, course=self.course, material=self.first, is_completed=True, watched_seconds=100)
        self.client.force_authenticate(self.user)
        self.assertEqual(self.client.get(self.url(f"student/materials/{self.second.uuid}/")).status_code, 403)

    def test_verified_progress_unlocks_next(self):
        StudentMaterialProgress.objects.create(firm=self.firm, student=self.student, course=self.course, material=self.first, is_verified_completed=True, verified_watched_seconds=100)
        self.client.force_authenticate(self.user)
        self.assertEqual(self.client.get(self.url(f"student/materials/{self.second.uuid}/")).status_code, 200)

    def test_heartbeat_rechecks_revoked_enrollment(self):
        self.client.force_authenticate(self.user)
        response = self.client.post(self.url(f"student/materials/{self.first.uuid}/watch-sessions/"))
        self.assertEqual(response.status_code, 201, response.data)
        self.enrollment.status = "CANCELLED"
        self.enrollment.save()
        response = self.client.post(self.url(f"student/watch-sessions/{response.data['data']['uuid']}/heartbeat/"), {"player_position_seconds": 10})
        self.assertEqual(response.status_code, 403)

    def test_candidate_full_name_and_duplicate_reason(self):
        response = self.client.get(self.url(f"courses/{self.course.uuid}/enrollment-candidates/"))
        rows = response.data["data"]["results"]
        self.assertEqual(rows[0]["full_name"], "Asha Patil")
        self.assertFalse(rows[0]["can_assign"])
        self.assertTrue(rows[1]["can_assign"])

    def test_bulk_skips_active_assigns_selected_only(self):
        response = self.client.post(self.url(f"courses/{self.course.uuid}/bulk-assign/"), {"student_uuids": [str(self.student.uuid), str(self.student2.uuid)]}, format="json")
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data["data"]["assigned_count"], 1)
        self.assertEqual(response.data["data"]["skipped_count"], 1)
        enrollment = Enrollment.objects.get(student=self.student2)
        self.assertEqual((enrollment.access_end_at - enrollment.access_start_at).days, 90)

    def test_expired_enrollment_renews_with_audit(self):
        self.enrollment.access_end_at = self.now - timedelta(days=1)
        self.enrollment.save()
        response = self.client.post(self.url(f"courses/{self.course.uuid}/bulk-assign/"), {"student_uuids": [str(self.student.uuid)]}, format="json")
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(Enrollment.objects.filter(student=self.student).count(), 1)
        self.assertEqual(EnrollmentRenewal.objects.count(), 1)

    def test_bulk_cross_tenant_selection_is_atomic(self):
        stranger = Student.objects.create(firm=self.other, admission_number="X", first_name="Other")
        response = self.client.post(self.url(f"courses/{self.course.uuid}/bulk-assign/"), {"student_uuids": [str(self.student2.uuid), str(stranger.uuid)]}, format="json")
        self.assertEqual(response.status_code, 400)
        self.assertFalse(Enrollment.objects.filter(student=self.student2).exists())

    def test_bulk_duplicate_ids_rejected(self):
        response = self.client.post(self.url(f"courses/{self.course.uuid}/bulk-assign/"), {"student_uuids": [str(self.student2.uuid)] * 2}, format="json")
        self.assertEqual(response.status_code, 400)

    def test_student_overview_counts_verified_only(self):
        StudentMaterialProgress.objects.create(firm=self.firm, student=self.student, course=self.course, material=self.first, is_verified_completed=True, verified_completion_percentage=100)
        response = self.client.get(self.url(f"students/{self.student.uuid}/overview/"))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["data"]["personal_details"]["full_name"], "Asha Patil")
        self.assertEqual(response.data["data"]["courses"][0]["course_completion_percentage"], 50)

    def test_cross_tenant_student_is_hidden(self):
        self.admin.firm = self.other
        self.admin.save()
        self.assertEqual(self.client.get(self.url(f"students/{self.student.uuid}/overview/")).status_code, 404)

    def test_online_batch_rejected(self):
        self.course.delivery_mode = "ONLINE"
        self.course.save()
        response = self.client.post(self.url("batches/"), {"course_uuid": str(self.course.uuid), "name": "Online", "start_date": str(self.today), "end_date": str(self.today + timedelta(days=30))})
        self.assertEqual(response.status_code, 400)

    def test_membership_wrong_course_rejected(self):
        other = Course.objects.create(firm=self.firm, name="Other", code="X")
        enrollment = Enrollment.objects.create(firm=self.firm, course=other, student=self.student2, status="ACTIVE")
        response = self.client.post(self.url(f"batches/{self.batch.uuid}/members/"), {"enrollment_uuids": [str(enrollment.uuid)], "joined_on": str(self.today)}, format="json")
        self.assertEqual(response.status_code, 400)

    def test_roster_unmarked_then_marked(self):
        response = self.client.get(self.url(f"batches/{self.batch.uuid}/attendance/?date={self.today}"))
        self.assertEqual(response.data["data"]["results"][0]["status"], "UNMARKED")
        self.assertEqual(self.mark().status_code, 200)
        response = self.client.get(self.url(f"batches/{self.batch.uuid}/attendance/?date={self.today}"))
        self.assertEqual(response.data["data"]["results"][0]["status"], "PRESENT")

    def test_attendance_repeated_save_updates_no_duplicate(self):
        self.mark()
        response = self.mark(records=[{"student_uuid": str(self.student.uuid), "status": "ABSENT"}])
        self.assertEqual(response.status_code, 200)
        self.assertEqual(AttendanceRecord.objects.count(), 1)
        self.assertEqual(AttendanceRecord.objects.get().status, "ABSENT")

    def test_future_attendance_rejected(self):
        self.assertEqual(self.mark(date=str(self.today + timedelta(days=1))).status_code, 400)

    def test_nonmember_attendance_rejected_without_partial_write(self):
        response = self.mark(records=[{"student_uuid": str(self.student.uuid), "status": "PRESENT"}, {"student_uuid": str(self.student2.uuid), "status": "PRESENT"}])
        self.assertEqual(response.status_code, 400)
        self.assertEqual(AttendanceRecord.objects.count(), 0)

    def test_attendance_exports(self):
        self.mark()
        for kind in ["csv", "xlsx", "pdf"]:
            response = self.client.get(self.url(f"batches/{self.batch.uuid}/attendance/report/?export={kind}"))
            self.assertEqual(response.status_code, 200)
            if kind == "csv":
                self.assertIn(b"Asha Patil", response.content)
            elif kind == "xlsx":
                from openpyxl import load_workbook
                sheet = load_workbook(BytesIO(response.content)).active
                self.assertEqual(sheet.cell(2, 7).value, "Asha Patil")
            else:
                from pypdf import PdfReader
                self.assertIn("Asha Patil", PdfReader(BytesIO(response.content)).pages[0].extract_text())

    def test_template_round_trip(self):
        response = self.client.get(self.url("assignments/mcq-template/"))
        self.assertEqual(response.status_code, 200)
        from pypdf import PdfReader
        from assignments.services import parse_mcq_questions
        text = "\n".join(p.extract_text() for p in PdfReader(BytesIO(response.content)).pages)
        questions = parse_mcq_questions(text)
        self.assertEqual(len(questions), 2)
        self.assertEqual(questions[0]["correct_option"], "B")

    def test_student_cannot_download_admin_answer_template(self):
        self.client.force_authenticate(self.user)
        self.assertEqual(self.client.get(self.url("assignments/mcq-template/")).status_code, 403)

    def test_student_cannot_mark_attendance(self):
        self.client.force_authenticate(self.user)
        self.assertEqual(self.mark().status_code, 403)

    def test_student_cannot_bulk_assign(self):
        self.client.force_authenticate(self.user)
        response = self.client.post(self.url(f"courses/{self.course.uuid}/bulk-assign/"), {"student_uuids": [str(self.student2.uuid)]}, format="json")
        self.assertEqual(response.status_code, 403)

    def test_student_applies_once(self):
        job = self.job()
        self.client.force_authenticate(self.user)
        url = self.url(f"student/jobs/{job.uuid}/apply/")
        response = self.client.post(url, {"cover_letter": "Interested"}, format="json")
        self.assertEqual(response.status_code, 201)
        self.assertNotIn("admin_note", response.data["data"])
        self.assertEqual(self.client.post(url, {}, format="json").status_code, 400)

    def test_expired_job_application_rejected(self):
        job = self.job(application_deadline=self.now - timedelta(seconds=1))
        self.client.force_authenticate(self.user)
        self.assertEqual(self.client.post(self.url(f"student/jobs/{job.uuid}/apply/"), {}, format="json").status_code, 400)

    def test_draft_and_other_firm_job_hidden(self):
        job = self.job(is_published=False)
        other = self.job(firm=self.other)
        self.client.force_authenticate(self.user)
        self.assertEqual(self.client.get(self.url(f"student/jobs/{job.uuid}/")).status_code, 404)
        self.assertEqual(self.client.post(self.url(f"student/jobs/{other.uuid}/apply/"), {}, format="json").status_code, 404)

    def test_admin_reviews_application_and_student_sees_status(self):
        application = JobApplication.objects.create(firm=self.firm, opening=self.job(), student=self.student)
        response = self.client.patch(self.url(f"placements/applications/{application.uuid}/"), {"status": "INTERVIEW", "interview_at": (self.now + timedelta(days=2)).isoformat(), "admin_note": "Private"}, format="json")
        self.assertEqual(response.status_code, 200)
        self.client.force_authenticate(self.user)
        response = self.client.get(self.url("student/job-applications/"))
        self.assertEqual(response.data["data"]["results"][0]["status"], "INTERVIEW")
        self.assertNotIn("admin_note", response.data["data"]["results"][0])

    def test_student_cannot_withdraw_others_application(self):
        application = JobApplication.objects.create(firm=self.firm, opening=self.job(), student=self.student2)
        self.client.force_authenticate(self.user)
        self.assertEqual(self.client.post(self.url(f"student/job-applications/{application.uuid}/withdraw/")).status_code, 404)

    def test_withdrawn_application_cannot_be_reviewed(self):
        application = JobApplication.objects.create(firm=self.firm, opening=self.job(), student=self.student, status="WITHDRAWN")
        response = self.client.patch(self.url(f"placements/applications/{application.uuid}/"), {"status": "SHORTLISTED"}, format="json")
        self.assertEqual(response.status_code, 400)

    def test_verified_heartbeats_unlock_next_end_to_end(self):
        self.client.force_authenticate(self.user)
        response = self.client.post(self.url(f"student/materials/{self.first.uuid}/watch-sessions/"))
        session_uuid = response.data["data"]["uuid"]
        session = StudentVideoWatchSession.objects.get(uuid=session_uuid)
        start = session.started_at
        for position in [15, 30, 45, 60, 75, 90]:
            with patch("progress.services.timezone.now", return_value=start + timedelta(seconds=position)):
                response = self.client.post(self.url(f"student/watch-sessions/{session_uuid}/heartbeat/"), {"player_position_seconds": position})
            self.assertEqual(response.status_code, 200, response.data)
        self.assertTrue(response.data["data"]["is_verified_completed"])
        self.assertEqual(self.client.post(self.url(f"student/materials/{self.second.uuid}/watch-sessions/")).status_code, 201)

    def test_seeking_cannot_unlock_next_video(self):
        self.client.force_authenticate(self.user)
        response = self.client.post(self.url(f"student/materials/{self.first.uuid}/watch-sessions/"))
        session_uuid = response.data["data"]["uuid"]
        response = self.client.post(self.url(f"student/watch-sessions/{session_uuid}/heartbeat/"), {"player_position_seconds": 100})
        self.assertEqual(response.status_code, 200)
        self.assertFalse(response.data["data"]["is_verified_completed"])
        self.assertEqual(self.client.post(self.url(f"student/materials/{self.second.uuid}/watch-sessions/")).status_code, 403)

    def test_progress_read_contains_verified_fields(self):
        self.client.force_authenticate(self.user)
        self.client.post(self.url(f"student/materials/{self.first.uuid}/watch-sessions/"))
        response = self.client.get(self.url(f"student/materials/{self.first.uuid}/progress/"))
        self.assertIn("is_verified_completed", response.data["data"])

    def test_secure_progress_used_in_course_summary(self):
        StudentMaterialProgress.objects.create(firm=self.firm, student=self.student, course=self.course, material=self.first, is_verified_completed=True)
        self.client.force_authenticate(self.user)
        response = self.client.get(self.url(f"student/courses/{self.course.uuid}/progress/"))
        self.assertEqual(response.data["data"]["completed_materials"], 1)

    def test_expired_course_denies_video(self):
        self.enrollment.access_end_at = self.now - timedelta(seconds=1)
        self.enrollment.save()
        self.client.force_authenticate(self.user)
        self.assertEqual(self.client.get(self.url(f"student/materials/{self.first.uuid}/")).status_code, 403)

    def test_full_name_candidate_search(self):
        response = self.client.get(self.url(f"courses/{self.course.uuid}/enrollment-candidates/?search=Asha%20Patil"))
        self.assertEqual(response.data["data"]["count"], 1)

    def test_invalid_batch_course_query_returns_validation(self):
        self.assertEqual(self.client.get(self.url("batches/?course_uuid=invalid")).status_code, 400)

    def test_batch_date_order_rejected(self):
        response = self.client.post(self.url("batches/"), {"course_uuid": str(self.course.uuid), "name": "Wrong", "start_date": str(self.today), "end_date": str(self.today - timedelta(days=1))})
        self.assertEqual(response.status_code, 400)

    def test_membership_leave_excludes_later_roster(self):
        yesterday = self.today - timedelta(days=1)
        response = self.client.patch(self.url(f"batches/{self.batch.uuid}/members/{self.member.uuid}/"), {"left_on": str(yesterday)}, format="json")
        self.assertEqual(response.status_code, 200)
        response = self.client.get(self.url(f"batches/{self.batch.uuid}/attendance/?date={self.today}"))
        self.assertEqual(response.data["data"]["count"], 0)

    def test_attendance_bad_status_rejected(self):
        self.assertEqual(self.mark(records=[{"student_uuid": str(self.student.uuid), "status": "UNKNOWN"}]).status_code, 400)

    def test_cross_tenant_attendance_report_hidden(self):
        self.admin.firm = self.other
        self.admin.save()
        self.assertEqual(self.client.get(self.url(f"batches/{self.batch.uuid}/attendance/report/?export=csv")).status_code, 404)

    def test_attendance_exports_escape_formulas(self):
        self.student.first_name = "=HYPERLINK(1)"
        self.student.save()
        self.mark()
        response = self.client.get(self.url(f"batches/{self.batch.uuid}/attendance/report/?export=csv"))
        self.assertIn(b"'=HYPERLINK(1)", response.content)

    def test_mcq_template_import_creates_assignment(self):
        from assignments.template_views import mcq_template_pdf
        from django.core.files.uploadedfile import SimpleUploadedFile
        pdf = SimpleUploadedFile("questions.pdf", mcq_template_pdf(), content_type="application/pdf")
        with patch("assignments.services.default_storage.save", return_value="assignments/sample.pdf"):
            response = self.client.post(self.url("assignments/import-pdf/"), {"course_uuid": str(self.course.uuid), "title": "Template import", "pdf": pdf}, format="multipart")
        self.assertEqual(response.status_code, 201, response.data)
        from assignments.models import AssignmentQuestion
        self.assertEqual(AssignmentQuestion.objects.count(), 2)

    def test_incomplete_mcq_reports_original_number(self):
        from assignments.services import parse_mcq_questions
        from rest_framework.exceptions import ValidationError
        with self.assertRaises(ValidationError) as error:
            parse_mcq_questions("7. Missing option\nA. One\nB. Two\nC. Three\nAnswer: A", strict=True)
        self.assertIn("Question 7", str(error.exception))

    def test_cross_tenant_application_review_hidden(self):
        application = JobApplication.objects.create(firm=self.firm, opening=self.job(), student=self.student)
        self.admin.firm = self.other
        self.admin.save()
        response = self.client.patch(self.url(f"placements/applications/{application.uuid}/"), {"status": "SELECTED"}, format="json")
        self.assertEqual(response.status_code, 404)

    def test_interview_requires_schedule(self):
        application = JobApplication.objects.create(firm=self.firm, opening=self.job(), student=self.student)
        response = self.client.patch(self.url(f"placements/applications/{application.uuid}/"), {"status": "INTERVIEW"}, format="json")
        self.assertEqual(response.status_code, 400)

    def test_unauthenticated_new_apis_rejected(self):
        self.client.force_authenticate(None)
        for path in ["batches/", "placements/openings/", "student/jobs/", "assignments/mcq-template/"]:
            self.assertIn(self.client.get(self.url(path)).status_code, [401, 403])

    def test_renewal_without_course_duration_clears_old_expiry(self):
        self.course.access_duration_days = None
        self.course.duration_months = None
        self.course.save()
        self.enrollment.access_end_at = self.now - timedelta(days=1)
        self.enrollment.save()
        response = self.client.post(self.url(f"courses/{self.course.uuid}/bulk-assign/"), {"student_uuids": [str(self.student.uuid)]}, format="json")
        self.assertEqual(response.status_code, 200)
        self.enrollment.refresh_from_db()
        self.assertIsNone(self.enrollment.access_end_at)

    def test_month_duration_fallback(self):
        self.course.access_duration_days = None
        self.course.duration_months = 3
        self.course.save()
        response = self.client.post(self.url(f"courses/{self.course.uuid}/bulk-assign/"), {"student_uuids": [str(self.student2.uuid)]}, format="json")
        self.assertEqual(response.status_code, 200)
        enrollment = Enrollment.objects.get(student=self.student2)
        from dateutil.relativedelta import relativedelta
        self.assertEqual(enrollment.access_end_at, enrollment.access_start_at + relativedelta(months=3))

    def test_chapter_only_access_can_start_verified_session(self):
        from courses.models import Subject, Chapter, StudentChapterVideoAccess
        subject = Subject.objects.create(firm=self.firm, course=self.course, name="Basics")
        chapter = Chapter.objects.create(firm=self.firm, subject=subject, title="Intro")
        self.first.chapter = chapter
        self.first.subject = subject
        self.first.save()
        self.enrollment.status = "CANCELLED"
        self.enrollment.save()
        StudentChapterVideoAccess.objects.create(firm=self.firm, student=self.student, course=self.course, chapter=chapter)
        self.client.force_authenticate(self.user)
        response = self.client.post(self.url(f"student/materials/{self.first.uuid}/watch-sessions/"))
        self.assertEqual(response.status_code, 201, response.data)

    def test_video_teacher_name_is_exposed_to_student(self):
        from teachers.models import Teacher
        teacher = Teacher.objects.create(firm=self.firm, employee_id="T1", first_name="Vidya", last_name="Patil")
        self.first.teacher = teacher
        self.first.save()
        self.client.force_authenticate(self.user)
        response = self.client.get(self.url(f"student/courses/{self.course.uuid}/materials/"))
        self.assertEqual(response.data["data"]["results"][0]["teacher_name"], "Vidya Patil")

    def test_teacher_from_other_academy_is_rejected(self):
        from teachers.models import Teacher
        teacher = Teacher.objects.create(firm=self.other, employee_id="T1", first_name="Other")
        response = self.client.patch(self.url(f"materials/{self.first.uuid}/"), {"teacher_uuid": str(teacher.uuid)}, format="json")
        self.assertEqual(response.status_code, 400)
