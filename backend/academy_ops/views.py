"""Firm-scoped administration APIs; student actions are explicitly separated."""
from django.db import transaction, IntegrityError
from django.db.models import Q, Count, Avg
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework.views import APIView
from rest_framework import serializers
from rest_framework.exceptions import ValidationError
from common.permissions import IsFirmAdmin, IsStudent
from common.responses import success_response
from common.pagination import StandardResultsSetPagination
from courses.models import Course, Enrollment
from courses.services import create_enrollment
from students.models import Student
from students.serializers import StudentSerializer
from .models import Batch, BatchMembership, AttendanceSession, AttendanceRecord, JobOpening, JobApplication
from .serializers import (
    StudentSelectionSerializer, BatchSerializer, MembershipSelectionSerializer,
    AttendanceMarkSerializer, AttendanceQuerySerializer, JobOpeningSerializer,
    JobApplySerializer, JobApplicationSerializer, ApplicationReviewSerializer,
)


def page_response(request, queryset, serialize):
    paginator = StandardResultsSetPagination()
    page = paginator.paginate_queryset(queryset, request)
    return paginator.get_paginated_response([serialize(item) for item in page])


def course_for(request, course_uuid):
    course_uuid = serializers.UUIDField().run_validation(course_uuid)
    return get_object_or_404(Course, firm=request.user.firm, uuid=course_uuid, is_active=True)


def batch_for(request, batch_uuid):
    return get_object_or_404(Batch.objects.select_related("course"), firm=request.user.firm, uuid=batch_uuid)


def enrollment_block(enrollment):
    if enrollment and (enrollment.access_end_at is None or enrollment.access_end_at > timezone.now()):
        return "An unexpired enrollment already exists."
    return None


class EnrollmentCandidatesView(APIView):
    permission_classes = [IsFirmAdmin]

    def get(self, request, course_uuid):
        course = course_for(request, course_uuid)
        students = Student.objects.filter(firm=request.user.firm, is_active=True).order_by("first_name", "last_name", "pk")
        search = request.query_params.get("search", "").strip()
        for word in search.split():
            students = students.filter(Q(first_name__icontains=word) | Q(last_name__icontains=word) | Q(admission_number__icontains=word))
        enrollments = {e.student_id: e for e in Enrollment.objects.filter(firm=request.user.firm, course=course)}

        def serialize(student):
            enrollment = enrollments.get(student.pk)
            reason = enrollment_block(enrollment)
            return {"student_uuid": str(student.uuid), "full_name": student.full_name,
                    "admission_number": student.admission_number, "can_assign": reason is None,
                    "reason": reason, "access_end_at": enrollment.access_end_at if enrollment else None,
                    "enrollment_status": enrollment.status if enrollment else None}
        return page_response(request, students, serialize)


class BulkCourseAssignView(APIView):
    permission_classes = [IsFirmAdmin]

    @transaction.atomic
    def post(self, request, course_uuid):
        course = course_for(request, course_uuid)
        serializer = StudentSelectionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        students = list(Student.objects.select_for_update().filter(
            firm=request.user.firm, uuid__in=data["student_uuids"], is_active=True,
        ).order_by("pk"))
        if len(students) != len(data["student_uuids"]):
            raise ValidationError({"student_uuids": "One or more students are inactive or outside your academy."})
        assigned, skipped = [], []
        for student in students:
            enrollment = Enrollment.objects.filter(student=student, course=course).first()
            reason = enrollment_block(enrollment)
            if reason:
                skipped.append({"student_uuid": str(student.uuid), "full_name": student.full_name, "reason": reason})
                continue
            enrollment = create_enrollment(
                firm=request.user.firm, granted_by=request.user,
                validated_data={"student_uuid": student.uuid, "course_uuid": course.uuid, "status": "ACTIVE",
                                **{key: data[key] for key in ["access_start_at", "access_end_at"] if key in data}},
            )
            assigned.append({"student_uuid": str(student.uuid), "full_name": student.full_name,
                             "enrollment_uuid": str(enrollment.uuid), "access_end_at": enrollment.access_end_at})
        return success_response({"assigned": assigned, "skipped": skipped,
                                 "assigned_count": len(assigned), "skipped_count": len(skipped)})


class StudentOverviewView(APIView):
    permission_classes = [IsFirmAdmin]

    def get(self, request, student_uuid):
        student = get_object_or_404(Student.objects.prefetch_related("guardians"), firm=request.user.firm, uuid=student_uuid)
        from materials.models import LearningMaterial
        from progress.models import StudentMaterialProgress
        courses = []
        for enrollment in Enrollment.objects.filter(student=student, firm=request.user.firm).select_related("course", "fee_account").prefetch_related("renewals"):
            videos = LearningMaterial.objects.filter(firm=student.firm, course=enrollment.course, material_type="VIDEO", is_active=True)
            progress = StudentMaterialProgress.objects.filter(student=student, material__in=videos)
            total = videos.count()
            completed = progress.filter(is_verified_completed=True).count()
            average = progress.aggregate(value=Avg("verified_completion_percentage"))["value"] or 0
            # Missing video rows contribute zero to the mean.
            watch_percentage = float(average) * progress.count() / total if total else 0
            account = getattr(enrollment, "fee_account", None)
            fees = {key: getattr(account, key) for key in ["total_amount", "discount_amount", "paid_amount", "balance_amount", "status"]} if account else None
            attendance_counts = list(AttendanceRecord.objects.filter(membership__enrollment=enrollment, session__firm=student.firm).values("status").annotate(count=Count("id")))
            progress_by_material = {row.material_id: row for row in progress}
            video_details = []
            for video in videos.select_related("teacher").order_by("sequence", "created_at", "pk"):
                row = progress_by_material.get(video.pk)
                video_details.append({"material_uuid": str(video.uuid), "title": video.title,
                                      "sequence": video.sequence,
                                      "teacher_name": video.teacher.full_name if video.teacher else None,
                                      "is_completed": row.is_verified_completed if row else False,
                                      "verified_watch_percentage": str(row.verified_completion_percentage) if row else "0.00"})
            courses.append({"enrollment_uuid": str(enrollment.uuid), "course_uuid": str(enrollment.course.uuid),
                            "course_name": enrollment.course.name, "delivery_mode": enrollment.course.delivery_mode,
                            "status": enrollment.status, "enrolled_at": enrollment.enrolled_at,
                            "access_start_at": enrollment.access_start_at, "access_end_at": enrollment.access_end_at,
                            "total_videos": total, "completed_videos": completed, "pending_videos": total - completed,
                            "course_completion_percentage": round(completed * 100 / total, 2) if total else 0,
                            "verified_watch_percentage": round(watch_percentage, 2), "videos": video_details,
                            "fees": fees, "attendance_by_status": attendance_counts,
                            "renewal_history": [{"previous_start_at": r.previous_start_at, "previous_end_at": r.previous_end_at,
                                                 "previous_status": r.previous_status, "renewed_at": r.created_at}
                                                for r in enrollment.renewals.all()]})
        counts = list(AttendanceRecord.objects.filter(membership__enrollment__student=student, session__firm=student.firm).values("status").annotate(count=Count("id")))
        total = sum(row["count"] for row in counts)
        present = sum(row["count"] for row in counts if row["status"] in ["PRESENT", "LATE"])
        return success_response({"personal_details": StudentSerializer(student).data,
                                 "login_enabled": bool(student.user_id and student.user.is_active), "courses": courses,
                                 "attendance": {"total_marked": total, "by_status": counts,
                                                "attendance_percentage": round(present * 100 / total, 2) if total else 0}})


class BatchListCreateView(APIView):
    permission_classes = [IsFirmAdmin]

    def get(self, request):
        queryset = Batch.objects.filter(firm=request.user.firm).select_related("course")
        course_uuid = request.query_params.get("course_uuid")
        if course_uuid:
            course = course_for(request, course_uuid)
            queryset = queryset.filter(course=course)
        return page_response(request, queryset, lambda batch: BatchSerializer(batch).data)

    def post(self, request):
        serializer = BatchSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        try:
            with transaction.atomic():
                batch = serializer.save(firm=request.user.firm)
        except IntegrityError:
            raise ValidationError({"name": "Batch already exists."})
        return success_response(BatchSerializer(batch).data, status_code=201)


class BatchDetailView(APIView):
    permission_classes = [IsFirmAdmin]

    def get(self, request, batch_uuid):
        return success_response(BatchSerializer(batch_for(request, batch_uuid)).data)

    @transaction.atomic
    def patch(self, request, batch_uuid):
        batch = batch_for(request, batch_uuid)
        batch = Batch.objects.select_for_update().get(pk=batch.pk)
        serializer = BatchSerializer(batch, data=request.data, partial=True, context={"request": request})
        serializer.is_valid(raise_exception=True)
        try:
            with transaction.atomic():
                serializer.save()
        except IntegrityError:
            raise ValidationError({"name": "Batch already exists."})
        return success_response(serializer.data)


def membership_data(membership):
    student = membership.enrollment.student
    return {"uuid": str(membership.uuid), "student_uuid": str(student.uuid), "full_name": student.full_name,
            "admission_number": student.admission_number, "enrollment_uuid": str(membership.enrollment.uuid),
            "joined_on": membership.joined_on, "left_on": membership.left_on}


class BatchMembersView(APIView):
    permission_classes = [IsFirmAdmin]

    def get(self, request, batch_uuid):
        batch = batch_for(request, batch_uuid)
        members = batch.memberships.select_related("enrollment__student").order_by("enrollment__student__first_name", "pk")
        return page_response(request, members, membership_data)

    @transaction.atomic
    def post(self, request, batch_uuid):
        batch = batch_for(request, batch_uuid)
        Batch.objects.select_for_update().get(pk=batch.pk)
        if not batch.is_active or batch.course.delivery_mode not in ["OFFLINE", "HYBRID"]:
            raise ValidationError("Select an active offline/hybrid batch.")
        serializer = MembershipSelectionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        if not batch.start_date <= data["joined_on"] <= batch.end_date:
            raise ValidationError({"joined_on": "Date must be within batch duration."})
        enrollments = list(Enrollment.objects.select_for_update().filter(
            firm=request.user.firm, course=batch.course, uuid__in=data["enrollment_uuids"],
            status="ACTIVE", student__is_active=True,
        ).select_related("student").order_by("pk"))
        if len(enrollments) != len(data["enrollment_uuids"]):
            raise ValidationError({"enrollment_uuids": "Select active enrollments in this batch's course."})
        results = []
        for enrollment in enrollments:
            if enrollment.access_end_at and enrollment.access_end_at.date() < data["joined_on"]:
                raise ValidationError("Enrollment expires before the join date.")
            if enrollment.access_start_at and enrollment.access_start_at.date() > data["joined_on"]:
                raise ValidationError("Enrollment begins after the join date.")
            existing = BatchMembership.objects.filter(enrollment=enrollment, left_on__isnull=True).exclude(batch=batch)
            if existing.exists():
                raise ValidationError("Student already belongs to another active batch for this course.")
            membership, _ = BatchMembership.objects.get_or_create(
                batch=batch, enrollment=enrollment,
                defaults={"firm": request.user.firm, "joined_on": data["joined_on"]},
            )
            results.append(membership_data(membership))
        return success_response(results, status_code=201)


def roster(batch, date):
    return batch.memberships.filter(joined_on__lte=date).filter(
        Q(left_on__isnull=True) | Q(left_on__gte=date)
    ).filter(
        Q(enrollment__access_start_at__isnull=True) | Q(enrollment__access_start_at__date__lte=date)
    ).filter(
        Q(enrollment__access_end_at__isnull=True) | Q(enrollment__access_end_at__date__gte=date)
    ).filter(enrollment__student__is_active=True).exclude(enrollment__status="CANCELLED").select_related("enrollment__student").order_by("enrollment__student__first_name", "pk")


def validate_attendance_date(batch, date, marking=False):
    if not batch.start_date <= date <= batch.end_date:
        raise ValidationError({"date": "Date must be within batch duration."})
    if marking and date > timezone.localdate():
        raise ValidationError({"date": "Cannot mark future attendance."})


class BatchMemberDetailView(APIView):
    permission_classes = [IsFirmAdmin]

    @transaction.atomic
    def patch(self, request, batch_uuid, membership_uuid):
        batch = batch_for(request, batch_uuid)
        Batch.objects.select_for_update().get(pk=batch.pk)
        member = get_object_or_404(BatchMembership.objects.select_for_update().select_related("enrollment__student"), batch=batch, firm=request.user.firm, uuid=membership_uuid)
        left_on = serializers.DateField().run_validation(request.data.get("left_on"))
        if left_on < member.joined_on or left_on > batch.end_date:
            raise ValidationError({"left_on": "Leave date must be between join date and batch end."})
        if member.attendance_records.filter(session__date__gt=left_on).exists():
            raise ValidationError({"left_on": "Attendance exists after this date; correct attendance first."})
        member.left_on = left_on
        member.save()
        return success_response(membership_data(member))


class BatchAttendanceView(APIView):
    permission_classes = [IsFirmAdmin]

    def get(self, request, batch_uuid):
        batch = batch_for(request, batch_uuid)
        query = AttendanceQuerySerializer(data=request.query_params)
        query.is_valid(raise_exception=True)
        date = query.validated_data.get("date", timezone.localdate())
        validate_attendance_date(batch, date)
        session = AttendanceSession.objects.filter(batch=batch, date=date, label=query.validated_data["label"]).first()
        records = {r.membership_id: r for r in session.records.all()} if session else {}
        def serialize(member):
            record = records.get(member.pk)
            return {**membership_data(member), "status": record.status if record else "UNMARKED", "note": record.note if record else ""}
        return page_response(request, roster(batch, date), serialize)

    @transaction.atomic
    def post(self, request, batch_uuid):
        batch = batch_for(request, batch_uuid)
        Batch.objects.select_for_update().get(pk=batch.pk)
        if not batch.is_active or not batch.course.is_active or batch.course.delivery_mode not in ["OFFLINE", "HYBRID"]:
            raise ValidationError("Attendance requires an active offline/hybrid batch and course.")
        serializer = AttendanceMarkSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        validate_attendance_date(batch, data["date"], marking=True)
        members = {str(m.enrollment.student.uuid): m for m in roster(batch, data["date"])}
        if any(str(row["student_uuid"]) not in members for row in data["records"]):
            raise ValidationError({"records": "A student is not eligible for this batch on this date."})
        session, _ = AttendanceSession.objects.get_or_create(
            batch=batch, date=data["date"], label=data["label"], defaults={"firm": request.user.firm},
        )
        session.marked_by = request.user
        session.save()
        for row in data["records"]:
            AttendanceRecord.objects.update_or_create(
                session=session, membership=members[str(row["student_uuid"])],
                defaults={"status": row["status"], "note": row.get("note", "")},
            )
        return success_response({"session_uuid": str(session.uuid), "updated_count": len(data["records"]), "date": session.date})


class AttendanceReportView(APIView):
    permission_classes = [IsFirmAdmin]

    def get(self, request, batch_uuid):
        batch = batch_for(request, batch_uuid)
        query = AttendanceQuerySerializer(data=request.query_params)
        query.is_valid(raise_exception=True)
        data = query.validated_data
        records = AttendanceRecord.objects.filter(session__batch=batch, session__firm=request.user.firm).select_related("session", "membership__enrollment__student").order_by("session__date", "session__label", "membership__enrollment__student__first_name", "pk")
        if data.get("date_from"):
            records = records.filter(session__date__gte=data["date_from"])
        if data.get("date_to"):
            records = records.filter(session__date__lte=data["date_to"])
        def serialize(record):
            student = record.membership.enrollment.student
            return {"date": record.session.date, "session": record.session.label, "full_name": student.full_name,
                    "admission_number": student.admission_number, "status": record.status, "note": record.note}
        if data.get("export"):
            if records.count() > 10000:
                raise ValidationError("Export exceeds 10,000 records; narrow the date range.")
            from .exports import attendance_export
            return attendance_export(batch, [serialize(r) for r in records], data["export"])
        return page_response(request, records, serialize)


class JobListCreateView(APIView):
    permission_classes = [IsFirmAdmin]

    def get(self, request):
        return page_response(request, JobOpening.objects.filter(firm=request.user.firm), lambda job: JobOpeningSerializer(job).data)

    def post(self, request):
        serializer = JobOpeningSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save(firm=request.user.firm, created_by=request.user)
        return success_response(serializer.data, status_code=201)


class JobDetailView(APIView):
    permission_classes = [IsFirmAdmin]

    def get(self, request, opening_uuid):
        return success_response(JobOpeningSerializer(get_object_or_404(JobOpening, firm=request.user.firm, uuid=opening_uuid)).data)

    @transaction.atomic
    def patch(self, request, opening_uuid):
        opening = get_object_or_404(JobOpening.objects.select_for_update(), firm=request.user.firm, uuid=opening_uuid)
        serializer = JobOpeningSerializer(opening, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return success_response(serializer.data)


class JobApplicationsView(APIView):
    permission_classes = [IsFirmAdmin]

    def get(self, request, opening_uuid):
        opening = get_object_or_404(JobOpening, firm=request.user.firm, uuid=opening_uuid)
        applications = opening.applications.select_related("opening", "student")
        if request.query_params.get("status"):
            applications = applications.filter(status=request.query_params["status"])
        return page_response(request, applications, lambda app: JobApplicationSerializer(app).data)


class ApplicationReviewView(APIView):
    permission_classes = [IsFirmAdmin]

    @transaction.atomic
    def patch(self, request, application_uuid):
        application = get_object_or_404(JobApplication.objects.select_for_update().select_related("opening", "student"), firm=request.user.firm, uuid=application_uuid)
        if application.status == "WITHDRAWN":
            raise ValidationError("Cannot review a withdrawn application.")
        serializer = ApplicationReviewSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        for key, value in serializer.validated_data.items():
            setattr(application, key, value)
        application.save()
        return success_response(JobApplicationSerializer(application).data)


class StudentJobsView(APIView):
    permission_classes = [IsStudent]

    def get(self, request):
        jobs = JobOpening.objects.filter(firm=request.user.firm, is_active=True, is_published=True)
        return page_response(request, jobs, lambda job: JobOpeningSerializer(job).data)


class StudentJobDetailView(APIView):
    permission_classes = [IsStudent]

    def get(self, request, opening_uuid):
        job = get_object_or_404(JobOpening, firm=request.user.firm, uuid=opening_uuid, is_active=True, is_published=True)
        return success_response(JobOpeningSerializer(job).data)


class StudentJobApplyView(APIView):
    permission_classes = [IsStudent]

    @transaction.atomic
    def post(self, request, opening_uuid):
        job = get_object_or_404(JobOpening.objects.select_for_update(), firm=request.user.firm, uuid=opening_uuid, is_active=True, is_published=True)
        student = request.user.student_profile
        if not student.is_active:
            raise ValidationError("Your student profile is inactive.")
        if job.application_deadline <= timezone.now():
            raise ValidationError("The application deadline has passed.")
        serializer = JobApplySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        if JobApplication.objects.filter(opening=job, student=student).exists():
            raise ValidationError("You have already applied for this opening.")
        application = JobApplication.objects.create(firm=request.user.firm, opening=job, student=student, **serializer.validated_data)
        result = JobApplicationSerializer(application).data
        result.pop("admin_note", None)
        return success_response(result, status_code=201)


class StudentApplicationsView(APIView):
    permission_classes = [IsStudent]

    def get(self, request):
        applications = JobApplication.objects.filter(firm=request.user.firm, student=request.user.student_profile).select_related("opening", "student")
        def serialize(application):
            data = JobApplicationSerializer(application).data
            data.pop("admin_note", None)
            return data
        return page_response(request, applications, serialize)


class StudentWithdrawView(APIView):
    permission_classes = [IsStudent]

    @transaction.atomic
    def post(self, request, application_uuid):
        application = get_object_or_404(JobApplication.objects.select_for_update(), firm=request.user.firm, student=request.user.student_profile, uuid=application_uuid)
        if application.status in ["SELECTED", "REJECTED"]:
            raise ValidationError("A finalized application cannot be withdrawn.")
        application.status = "WITHDRAWN"
        application.save()
        return success_response({"uuid": str(application.uuid), "status": application.status})
