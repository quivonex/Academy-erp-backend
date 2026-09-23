from decimal import Decimal

from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone

from rest_framework import status
from rest_framework.views import APIView

from accounts.models import User
from common.pagination import StandardResultsSetPagination
from common.permissions import IsFirmAcademicStaff
from common.responses import (
    error_response,
    success_response,
)

from .models import (
    Assignment,
    AssignmentAnswer,
    AssignmentQuestion,
    AssignmentSubmission,
)
from .serializers import (
    AssignmentSubmissionGradeSerializer,
    AssignmentSubmissionListSerializer,
    AssignmentSubmissionReviewSerializer,
)


def can_review_assignment(
    *,
    user,
    assignment,
):
    """
    Admin and staff can review every assignment
    inside their own academy.

    A teacher can review only an assignment linked
    to the subject assigned to that teacher.
    """

    if user.user_type in [
        User.UserType.FIRM_ADMIN,
        User.UserType.FIRM_STAFF,
    ]:
        return True

    if user.user_type != User.UserType.TEACHER:
        return False

    teacher = getattr(
        user,
        "teacher_profile",
        None,
    )

    if not teacher or not teacher.is_active:
        return False

    if not assignment.subject_id:
        return False

    return (
        assignment.subject.teacher_id
        == teacher.id
    )


class AssignmentSubmissionListView(APIView):
    permission_classes = [
        IsFirmAcademicStaff,
    ]

    def get(
        self,
        request,
        assignment_uuid,
    ):
        assignment = get_object_or_404(
            Assignment.objects.select_related(
                "subject",
                "subject__teacher",
            ),
            uuid=assignment_uuid,
            firm=request.user.firm,
        )

        if not can_review_assignment(
            user=request.user,
            assignment=assignment,
        ):
            return error_response(
                message=(
                    "You do not have permission "
                    "to review this assignment."
                ),
                errors={},
                status_code=status.HTTP_403_FORBIDDEN,
            )

        submissions = (
            AssignmentSubmission.objects
            .filter(
                assignment=assignment,
            )
            .exclude(
                status=AssignmentSubmission.Status.DRAFT
            )
            .select_related(
                "student",
                "graded_by",
            )
            .order_by(
                "-submitted_at",
                "-created_at",
            )
        )

        status_value = request.query_params.get(
            "status"
        )

        if status_value:
            valid_statuses = [
                AssignmentSubmission.Status.SUBMITTED,
                AssignmentSubmission.Status.GRADED,
            ]

            if status_value not in valid_statuses:
                return error_response(
                    message="Invalid submission status.",
                    errors={
                        "status": [
                            "Use SUBMITTED or GRADED."
                        ]
                    },
                    status_code=status.HTTP_400_BAD_REQUEST,
                )

            submissions = submissions.filter(
                status=status_value
            )

        paginator = StandardResultsSetPagination()

        page = paginator.paginate_queryset(
            submissions,
            request,
        )

        serializer = AssignmentSubmissionListSerializer(
            page,
            many=True,
        )

        return paginator.get_paginated_response(
            serializer.data
        )


class AssignmentSubmissionDetailView(APIView):
    permission_classes = [
        IsFirmAcademicStaff,
    ]

    def get(
        self,
        request,
        submission_uuid,
    ):
        submission = get_object_or_404(
            AssignmentSubmission.objects
            .select_related(
                "assignment",
                "assignment__subject",
                "assignment__subject__teacher",
                "student",
                "graded_by",
            )
            .prefetch_related(
                "answers",
                "answers__question",
            ),
            uuid=submission_uuid,
            firm=request.user.firm,
        )

        if not can_review_assignment(
            user=request.user,
            assignment=submission.assignment,
        ):
            return error_response(
                message=(
                    "You do not have permission "
                    "to review this submission."
                ),
                errors={},
                status_code=status.HTTP_403_FORBIDDEN,
            )

        return success_response(
            message=(
                "Assignment submission retrieved "
                "successfully"
            ),
            data=AssignmentSubmissionReviewSerializer(
                submission
            ).data,
        )


class AssignmentSubmissionGradeView(APIView):
    permission_classes = [
        IsFirmAcademicStaff,
    ]

    @transaction.atomic
    def patch(
        self,
        request,
        submission_uuid,
    ):
        submission = get_object_or_404(
            AssignmentSubmission.objects
            .select_for_update()
            .select_related(
                "assignment",
                "assignment__subject",
                "assignment__subject__teacher",
                "student",
            ),
            uuid=submission_uuid,
            firm=request.user.firm,
        )

        if not can_review_assignment(
            user=request.user,
            assignment=submission.assignment,
        ):
            return error_response(
                message=(
                    "You do not have permission "
                    "to grade this submission."
                ),
                errors={},
                status_code=status.HTTP_403_FORBIDDEN,
            )

        if submission.status not in [
            AssignmentSubmission.Status.SUBMITTED,
            AssignmentSubmission.Status.GRADED,
        ]:
            return error_response(
                message="Grading failed",
                errors={
                    "submission": [
                        (
                            "Only submitted assignments "
                            "can be graded."
                        )
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        serializer = AssignmentSubmissionGradeSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                message="Grading failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        submitted_grades = (
            serializer.validated_data["answers"]
        )

        manual_answers = list(
            AssignmentAnswer.objects
            .select_for_update()
            .select_related("question")
            .filter(
                submission=submission,
                question__answer_type__in=[
                    AssignmentQuestion.AnswerType.TEXT,
                    AssignmentQuestion.AnswerType.FILE,
                ],
            )
        )

        if not manual_answers:
            return error_response(
                message="Grading failed",
                errors={
                    "submission": [
                        (
                            "This submission contains no "
                            "manual-grade answers."
                        )
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        manual_answer_map = {
            str(answer.uuid): answer
            for answer in manual_answers
        }

        submitted_answer_ids = [
            str(item["answer_uuid"])
            for item in submitted_grades
        ]

        if (
            len(submitted_answer_ids)
            != len(set(submitted_answer_ids))
        ):
            return error_response(
                message="Grading failed",
                errors={
                    "answers": [
                        (
                            "Duplicate answer grades "
                            "are not allowed."
                        )
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        invalid_answer_ids = [
            answer_uuid
            for answer_uuid in submitted_answer_ids
            if answer_uuid not in manual_answer_map
        ]

        if invalid_answer_ids:
            return error_response(
                message="Grading failed",
                errors={
                    "answers": [
                        (
                            "One or more answers do not "
                            "belong to this submission."
                        )
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        missing_answer_ids = (
            set(manual_answer_map.keys())
            - set(submitted_answer_ids)
        )

        if missing_answer_ids:
            return error_response(
                message="Grading failed",
                errors={
                    "answers": [
                        (
                            "Please provide marks for "
                            "every text or file answer."
                        )
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        for item in submitted_grades:
            answer_uuid = str(item["answer_uuid"])

            answer = manual_answer_map[
                answer_uuid
            ]

            marks_obtained = item["marks_obtained"]

            if marks_obtained > answer.question.marks:
                return error_response(
                    message="Grading failed",
                    errors={
                        "marks_obtained": [
                            (
                                "Marks cannot be greater "
                                "than the question's "
                                "maximum marks."
                            )
                        ]
                    },
                    status_code=status.HTTP_400_BAD_REQUEST,
                )

        for item in submitted_grades:
            answer_uuid = str(item["answer_uuid"])

            answer = manual_answer_map[
                answer_uuid
            ]

            answer.marks_obtained = item[
                "marks_obtained"
            ]

            answer.feedback = item.get(
                "feedback",
                "",
            )

            answer.save(
                update_fields=[
                    "marks_obtained",
                    "feedback",
                    "updated_at",
                ]
            )

        all_answers = (
            AssignmentAnswer.objects
            .filter(
                submission=submission
            )
        )

        total_marks = sum(
            (
                answer.marks_obtained
                or Decimal("0.00")
                for answer in all_answers
            ),
            Decimal("0.00"),
        )

        submission.total_marks_obtained = total_marks

        submission.feedback = (
            serializer.validated_data.get(
                "feedback",
                submission.feedback,
            )
        )

        submission.status = (
            AssignmentSubmission.Status.GRADED
        )

        submission.graded_by = request.user

        submission.graded_at = timezone.now()

        submission.save(
            update_fields=[
                "total_marks_obtained",
                "feedback",
                "status",
                "graded_by",
                "graded_at",
                "updated_at",
            ]
        )

        submission = (
            AssignmentSubmission.objects
            .select_related(
                "assignment",
                "student",
                "graded_by",
            )
            .prefetch_related(
                "answers",
                "answers__question",
            )
            .get(
                pk=submission.pk
            )
        )

        return success_response(
            message="Assignment graded successfully",
            data=AssignmentSubmissionReviewSerializer(
                submission
            ).data,
        )