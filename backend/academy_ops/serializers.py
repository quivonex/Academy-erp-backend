from rest_framework import serializers
from .models import Batch, JobOpening, JobApplication, AttendanceRecord


class StudentSelectionSerializer(serializers.Serializer):
    student_uuids = serializers.ListField(child=serializers.UUIDField(), min_length=1, max_length=500)
    access_start_at = serializers.DateTimeField(required=False)
    access_end_at = serializers.DateTimeField(required=False)

    def validate_student_uuids(self, values):
        if len(values) != len(set(values)):
            raise serializers.ValidationError("Select each student only once.")
        return values

    def validate(self, data):
        from django.utils import timezone
        start = data.get("access_start_at", timezone.now())
        if data.get("access_end_at") and data["access_end_at"] <= start:
            raise serializers.ValidationError({"access_end_at": "End must be after start."})
        return data


class BatchSerializer(serializers.ModelSerializer):
    course_uuid = serializers.UUIDField(write_only=True)
    course = serializers.UUIDField(source="course.uuid", read_only=True)
    course_name = serializers.CharField(source="course.name", read_only=True)

    class Meta:
        model = Batch
        fields = ["uuid", "course_uuid", "course", "course_name", "name", "start_date", "end_date", "is_active"]

    def validate(self, data):
        from courses.models import Course
        firm = self.context["request"].user.firm
        if "course_uuid" in data:
            course = Course.objects.filter(firm=firm, uuid=data.pop("course_uuid"), is_active=True).first()
            if not course or course.delivery_mode not in ["OFFLINE", "HYBRID"]:
                raise serializers.ValidationError({"course_uuid": "Select an active offline or hybrid course."})
            if self.instance and course.pk != self.instance.course_id:
                raise serializers.ValidationError({"course_uuid": "A batch cannot move to another course."})
            data["course"] = course
        start = data.get("start_date", getattr(self.instance, "start_date", None))
        end = data.get("end_date", getattr(self.instance, "end_date", None))
        if start and end and end < start:
            raise serializers.ValidationError({"end_date": "End must be on or after start."})
        if self.instance and self.instance.attendance_sessions.exists() and (
            start != self.instance.start_date or end != self.instance.end_date
        ):
            raise serializers.ValidationError("Cannot change batch dates after attendance has been recorded.")
        course = data.get("course", getattr(self.instance, "course", None))
        name = data.get("name", getattr(self.instance, "name", ""))
        duplicates = Batch.objects.filter(firm=firm, course=course, name=name)
        if self.instance:
            duplicates = duplicates.exclude(pk=self.instance.pk)
        if duplicates.exists():
            raise serializers.ValidationError({"name": "A batch with this name already exists for this course."})
        return data


class MembershipSelectionSerializer(serializers.Serializer):
    enrollment_uuids = serializers.ListField(child=serializers.UUIDField(), min_length=1, max_length=500)
    joined_on = serializers.DateField()

    def validate_enrollment_uuids(self, values):
        if len(values) != len(set(values)):
            raise serializers.ValidationError("Duplicate enrollments are not allowed.")
        return values


class AttendanceEntrySerializer(serializers.Serializer):
    student_uuid = serializers.UUIDField()
    status = serializers.ChoiceField(choices=AttendanceRecord.Status.choices)
    note = serializers.CharField(max_length=255, required=False, allow_blank=True)


class AttendanceMarkSerializer(serializers.Serializer):
    date = serializers.DateField()
    label = serializers.CharField(max_length=80, default="Daily")
    records = AttendanceEntrySerializer(many=True, allow_empty=False)

    def validate_records(self, values):
        ids = [v["student_uuid"] for v in values]
        if len(ids) > 500 or len(ids) != len(set(ids)):
            raise serializers.ValidationError("Use at most 500 unique students per request.")
        return values


class AttendanceQuerySerializer(serializers.Serializer):
    date = serializers.DateField(required=False)
    date_from = serializers.DateField(required=False)
    date_to = serializers.DateField(required=False)
    label = serializers.CharField(max_length=80, default="Daily")
    export = serializers.ChoiceField(choices=["csv", "xlsx", "pdf"], required=False)

    def validate(self, data):
        if data.get("date_from") and data.get("date_to") and data["date_to"] < data["date_from"]:
            raise serializers.ValidationError("date_to must be on or after date_from.")
        return data


class JobOpeningSerializer(serializers.ModelSerializer):
    class Meta:
        model = JobOpening
        fields = ["uuid", "title", "company_name", "description", "eligibility", "location", "application_deadline", "interview_at", "interview_end_at", "interview_venue", "interview_url", "is_published", "is_active", "created_at", "updated_at"]
        read_only_fields = ["uuid", "created_at", "updated_at"]

    def validate(self, data):
        from django.utils import timezone
        def value(key):
            return data.get(key, getattr(self.instance, key, None))
        if (self.instance is None or "application_deadline" in data) and value("application_deadline") <= timezone.now():
            raise serializers.ValidationError({"application_deadline": "Deadline must be in the future."})
        if value("interview_end_at") and (not value("interview_at") or value("interview_end_at") <= value("interview_at")):
            raise serializers.ValidationError({"interview_end_at": "Interview end must be after its start."})
        return data


class JobApplySerializer(serializers.Serializer):
    cover_letter = serializers.CharField(max_length=10000, required=False, allow_blank=True)
    resume_url = serializers.URLField(required=False, allow_blank=True)


class JobApplicationSerializer(serializers.ModelSerializer):
    opening_uuid = serializers.UUIDField(source="opening.uuid", read_only=True)
    opening_title = serializers.CharField(source="opening.title", read_only=True)
    student_uuid = serializers.UUIDField(source="student.uuid", read_only=True)
    student_name = serializers.CharField(source="student.full_name", read_only=True)
    admission_number = serializers.CharField(source="student.admission_number", read_only=True)

    class Meta:
        model = JobApplication
        fields = ["uuid", "opening_uuid", "opening_title", "student_uuid", "student_name", "admission_number", "cover_letter", "resume_url", "status", "admin_note", "interview_at", "created_at", "updated_at"]
        read_only_fields = fields


class ApplicationReviewSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=["SHORTLISTED", "INTERVIEW", "SELECTED", "REJECTED"])
    admin_note = serializers.CharField(max_length=10000, required=False, allow_blank=True)
    interview_at = serializers.DateTimeField(required=False, allow_null=True)

    def validate(self, data):
        if data.get("status") == "INTERVIEW" and not data.get("interview_at"):
            raise serializers.ValidationError({"interview_at": "Provide the candidate's interview time."})
        if data.get("interview_at"):
            from django.utils import timezone
            if data["interview_at"] <= timezone.now():
                raise serializers.ValidationError({"interview_at": "Interview must be in the future."})
        return data
