from decimal import Decimal

from django.db import models, transaction
from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.utils import timezone

from rest_framework import status
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from common.pagination import StandardResultsSetPagination
from common.permissions import (
    IsFirmAdminOrStaff,
    IsStudent,
)
from common.responses import (
    error_response,
    success_response,
)

from courses.access import get_student_active_enrollment
from courses.models import Course

from .models import (
    Assignment,
    AssignmentAnswer,
    AssignmentQuestion,
    AssignmentSubmission,
)
from .serializers import (
    AssignmentPDFImportSerializer,
    AssignmentQuestionSerializer,
    AssignmentSerializer,
    AssignmentUpdateSerializer,
    StudentAssignmentQuestionSerializer,
    StudentAssignmentSubmitSerializer,
)
from .services import (
    create_assignment,
    create_assignment_question,
    import_assignment_from_pdf,
)


# =========================================================
# ADMIN / STAFF - ASSIGNMENT LIST + CREATE
# =========================================================


class AssignmentListCreateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get(self, request):
        queryset = (
            Assignment.objects
            .filter(
                firm=request.user.firm
            )
            .select_related(
                "course",
                "subject",
                "chapter",
                "lesson",
                "created_by",
            )
        )

        course_uuid = request.query_params.get(
            "course_uuid"
        )

        search = request.query_params.get(
            "search"
        )

        if course_uuid:
            queryset = queryset.filter(
                course__uuid=course_uuid
            )

        if search:
            queryset = queryset.filter(
                Q(title__icontains=search)
                | Q(description__icontains=search)
            )

        paginator = StandardResultsSetPagination()

        page = paginator.paginate_queryset(
            queryset,
            request,
        )

        serializer = AssignmentSerializer(
            page,
            many=True,
        )

        return paginator.get_paginated_response(
            serializer.data
        )

    def post(self, request):
        serializer = AssignmentSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                message="Assignment creation failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        try:
            assignment = create_assignment(
                firm=request.user.firm,
                created_by=request.user,
                validated_data=serializer.validated_data,
            )

        except ValidationError as exc:
            return error_response(
                message="Assignment creation failed",
                errors=exc.detail,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        return success_response(
            message="Assignment created successfully",
            data=AssignmentSerializer(
                assignment
            ).data,
            status_code=status.HTTP_201_CREATED,
        )


# =========================================================
# ADMIN / STAFF - ASSIGNMENT DETAIL
# =========================================================


class AssignmentDetailView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get(
        self,
        request,
        assignment_uuid,
    ):
        assignment = get_object_or_404(
            Assignment.objects.select_related(
                "course",
                "subject",
                "chapter",
                "lesson",
                "created_by",
            ),
            uuid=assignment_uuid,
            firm=request.user.firm,
        )

        return success_response(
            message="Assignment retrieved successfully",
            data=AssignmentSerializer(
                assignment
            ).data,
        )


# =========================================================
# ADMIN / STAFF - QUESTIONS
# =========================================================


class AssignmentQuestionListCreateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get(
        self,
        request,
        assignment_uuid,
    ):
        assignment = get_object_or_404(
            Assignment,
            uuid=assignment_uuid,
            firm=request.user.firm,
        )

        questions = (
            assignment.questions
            .all()
            .order_by(
                "sequence",
                "created_at",
            )
        )

        return success_response(
            message=(
                "Assignment questions "
                "retrieved successfully"
            ),
            data=AssignmentQuestionSerializer(
                questions,
                many=True,
            ).data,
        )

    def post(
        self,
        request,
        assignment_uuid,
    ):
        assignment = get_object_or_404(
            Assignment,
            uuid=assignment_uuid,
            firm=request.user.firm,
        )

        if assignment.is_published:
            return error_response(
                message="Question creation failed",
                errors={
                    "assignment": [
                        (
                            "Unpublish the assignment "
                            "before adding questions."
                        )
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        if assignment.submissions.exists():
            return error_response(
                message="Question creation failed",
                errors={
                    "assignment": [
                        (
                            "Questions cannot be changed "
                            "after student submission."
                        )
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        serializer = AssignmentQuestionSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                message="Question creation failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        question = create_assignment_question(
            assignment=assignment,
            validated_data=serializer.validated_data,
        )

        return success_response(
            message="Question created successfully",
            data=AssignmentQuestionSerializer(
                question
            ).data,
            status_code=status.HTTP_201_CREATED,
        )
        
        
class AssignmentQuestionDetailView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get_object(
        self,
        request,
        assignment_uuid,
        question_uuid,
    ):
        return get_object_or_404(
            AssignmentQuestion.objects.select_related(
                "assignment"
            ),
            uuid=question_uuid,
            assignment__uuid=assignment_uuid,
            assignment__firm=request.user.firm,
        )

    def patch(
        self,
        request,
        assignment_uuid,
        question_uuid,
    ):
        question = self.get_object(
            request,
            assignment_uuid,
            question_uuid,
        )

        assignment = question.assignment

        if assignment.is_published:
            return error_response(
                message="Question update failed",
                errors={
                    "assignment": [
                        (
                            "Unpublish the assignment "
                            "before editing questions."
                        )
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        if assignment.submissions.exists():
            return error_response(
                message="Question update failed",
                errors={
                    "assignment": [
                        (
                            "Questions cannot be changed "
                            "after student submission."
                        )
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        serializer = AssignmentQuestionSerializer(
            question,
            data=request.data,
            partial=True,
        )

        if not serializer.is_valid():
            return error_response(
                message="Question update failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        question = serializer.save()

        return success_response(
            message="Question updated successfully",
            data=AssignmentQuestionSerializer(
                question
            ).data,
        )

    def delete(
        self,
        request,
        assignment_uuid,
        question_uuid,
    ):
        question = self.get_object(
            request,
            assignment_uuid,
            question_uuid,
        )

        assignment = question.assignment

        if assignment.is_published:
            return error_response(
                message="Question deletion failed",
                errors={
                    "assignment": [
                        (
                            "Unpublish the assignment "
                            "before deleting questions."
                        )
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        if assignment.submissions.exists():
            return error_response(
                message="Question deletion failed",
                errors={
                    "assignment": [
                        (
                            "Questions cannot be deleted "
                            "after student submission."
                        )
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        question.delete()

        return success_response(
            message="Question deleted successfully",
            data={},
        )
        


# =========================================================
# ADMIN / STAFF - PDF IMPORT
# =========================================================


class AssignmentPDFImportView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def post(self, request):
        serializer = AssignmentPDFImportSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                message="PDF import failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        try:
            assignment = import_assignment_from_pdf(
                firm=request.user.firm,
                created_by=request.user,
                validated_data=serializer.validated_data,
            )

        except ValidationError as exc:
            return error_response(
                message="PDF import failed",
                errors=exc.detail,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        questions = (
            assignment.questions
            .all()
            .order_by(
                "sequence",
                "created_at",
            )
        )

        return success_response(
            message=(
                "PDF imported successfully. "
                "Please review questions before publishing."
            ),
            data={
                "assignment": (
                    AssignmentSerializer(
                        assignment
                    ).data
                ),
                "questions": (
                    AssignmentQuestionSerializer(
                        questions,
                        many=True,
                    ).data
                ),
                "question_count": (
                    questions.count()
                ),
            },
            status_code=status.HTTP_201_CREATED,
        )


# =========================================================
# STUDENT - COURSE ASSIGNMENTS
# =========================================================


class StudentCourseAssignmentListView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsStudent,
    ]

    def get(
        self,
        request,
        course_uuid,
    ):
        student = request.user.student_profile

        course = get_object_or_404(
            Course,
            uuid=course_uuid,
            firm=request.user.firm,
            is_active=True,
        )

        enrollment = get_student_active_enrollment(
            student=student,
            course=course,
        )

        if not enrollment:
            return error_response(
                message=(
                    "You do not have access "
                    "to this course."
                ),
                errors={},
                status_code=status.HTTP_403_FORBIDDEN,
            )

        assignments = (
            Assignment.objects
            .filter(
                firm=request.user.firm,
                course=course,
                is_active=True,
                is_published=True,
            )
            .select_related(
                "course",
                "subject",
                "chapter",
                "lesson",
                "created_by",
            )
            .order_by(
                "-created_at"
            )
        )

        return success_response(
            message="Assignments retrieved successfully",
            data=AssignmentSerializer(
                assignments,
                many=True,
            ).data,
        )


# =========================================================
# STUDENT - ASSIGNMENT DETAIL
# =========================================================


class StudentAssignmentDetailView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsStudent,
    ]

    def get(
        self,
        request,
        assignment_uuid,
    ):
        student = request.user.student_profile

        assignment = get_object_or_404(
            Assignment.objects.select_related(
                "course",
                "subject",
                "chapter",
                "lesson",
            ),
            uuid=assignment_uuid,
            firm=request.user.firm,
            is_active=True,
            is_published=True,
        )

        enrollment = get_student_active_enrollment(
            student=student,
            course=assignment.course,
        )

        if not enrollment:
            return error_response(
                message=(
                    "You do not have access "
                    "to this assignment."
                ),
                errors={},
                status_code=status.HTTP_403_FORBIDDEN,
            )

        questions = (
            assignment.questions
            .all()
            .order_by(
                "sequence",
                "created_at",
            )
        )

        submission = (
            AssignmentSubmission.objects
            .filter(
                assignment=assignment,
                student=student,
            )
            .first()
        )

        return success_response(
            message="Assignment retrieved successfully",
            data={
                "uuid": str(
                    assignment.uuid
                ),
                "title": assignment.title,
                "description": (
                    assignment.description
                ),
                "instructions": (
                    assignment.instructions
                ),
                "max_marks": (
                    assignment.max_marks
                ),
                "due_at": (
                    assignment.due_at
                ),
                "allow_late_submission": (
                    assignment.allow_late_submission
                ),
                "submission_status": (
                    submission.status
                    if submission
                    else None
                ),
                "questions": (
                    StudentAssignmentQuestionSerializer(
                        questions,
                        many=True,
                    ).data
                ),
            },
        )


# =========================================================
# STUDENT - SUBMIT ASSIGNMENT / MCQ TEST
# =========================================================


class StudentAssignmentSubmitView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsStudent,
    ]

    @transaction.atomic
    def post(
        self,
        request,
        assignment_uuid,
    ):
        student = request.user.student_profile

        assignment = get_object_or_404(
            Assignment.objects.select_related(
                "course"
            ),
            uuid=assignment_uuid,
            firm=request.user.firm,
            is_active=True,
            is_published=True,
        )

        enrollment = get_student_active_enrollment(
            student=student,
            course=assignment.course,
        )

        if not enrollment:
            return error_response(
                message=(
                    "You do not have access "
                    "to this assignment."
                ),
                errors={},
                status_code=status.HTTP_403_FORBIDDEN,
            )

        # ---------------------------------------------
        # DEADLINE VALIDATION
        # ---------------------------------------------

        if (
            assignment.due_at
            and timezone.now() > assignment.due_at
            and not assignment.allow_late_submission
        ):
            return error_response(
                message="Assignment deadline has passed.",
                errors={},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        # ---------------------------------------------
        # ALREADY SUBMITTED VALIDATION
        # ---------------------------------------------

        existing_submission = (
            AssignmentSubmission.objects
            .filter(
                assignment=assignment,
                student=student,
            )
            .first()
        )

        if (
            existing_submission
            and existing_submission.status
            in [
                AssignmentSubmission.Status.SUBMITTED,
                AssignmentSubmission.Status.GRADED,
            ]
        ):
            return error_response(
                message="Assignment already submitted.",
                errors={},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        # ---------------------------------------------
        # REQUEST SERIALIZER
        # ---------------------------------------------

        serializer = StudentAssignmentSubmitSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return error_response(
                message="Submission failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        submitted_answers = (
            serializer.validated_data[
                "answers"
            ]
        )

        if not submitted_answers:
            return error_response(
                message="Submission failed",
                errors={
                    "answers": [
                        "At least one answer is required."
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        # ---------------------------------------------
        # GET ALL ASSIGNMENT QUESTIONS
        # ---------------------------------------------

        questions = list(
            assignment.questions.all()
        )

        if not questions:
            return error_response(
                message="Submission failed",
                errors={
                    "assignment": [
                        (
                            "This assignment does not "
                            "contain any questions."
                        )
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        question_map = {
            str(question.uuid): question
            for question in questions
        }

        # ---------------------------------------------
        # DUPLICATE QUESTION VALIDATION
        # ---------------------------------------------

        submitted_question_ids = [
            str(
                answer[
                    "question_uuid"
                ]
            )
            for answer in submitted_answers
        ]

        if (
            len(submitted_question_ids)
            != len(
                set(
                    submitted_question_ids
                )
            )
        ):
            return error_response(
                message="Submission failed",
                errors={
                    "answers": [
                        (
                            "Duplicate question answers "
                            "are not allowed."
                        )
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        # ---------------------------------------------
        # INVALID QUESTION VALIDATION
        # ---------------------------------------------

        invalid_question_ids = [
            question_uuid
            for question_uuid
            in submitted_question_ids
            if question_uuid not in question_map
        ]

        if invalid_question_ids:
            return error_response(
                message="Submission failed",
                errors={
                    "answers": [
                        (
                            "One or more questions do "
                            "not belong to this assignment."
                        )
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        # ---------------------------------------------
        # REQUIRED QUESTION VALIDATION
        # ---------------------------------------------

        required_question_ids = {
            str(question.uuid)
            for question in questions
            if question.is_required
        }

        missing_questions = (
            required_question_ids
            - set(
                submitted_question_ids
            )
        )

        if missing_questions:
            return error_response(
                message="Submission failed",
                errors={
                    "answers": [
                        (
                            "Please answer all required "
                            "questions before submitting."
                        )
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        # ---------------------------------------------
        # VALIDATE ANSWER CONTENT BEFORE DB WRITE
        # ---------------------------------------------

        for answer_data in submitted_answers:
            question_uuid = str(
                answer_data[
                    "question_uuid"
                ]
            )

            question = question_map[
                question_uuid
            ]

            if (
                question.answer_type
                == AssignmentQuestion.AnswerType.MCQ
            ):
                selected_option = (
                    answer_data
                    .get(
                        "selected_option",
                        "",
                    )
                    .strip()
                    .upper()
                )

                if selected_option not in [
                    "A",
                    "B",
                    "C",
                    "D",
                ]:
                    return error_response(
                        message="Submission failed",
                        errors={
                            "selected_option": [
                                (
                                    "MCQ answer must be "
                                    "A, B, C, or D."
                                )
                            ]
                        },
                        status_code=(
                            status.HTTP_400_BAD_REQUEST
                        ),
                    )

                # Important:
                # Never auto-grade an MCQ if
                # correct answer was not configured.

                if question.correct_option not in [
                    "A",
                    "B",
                    "C",
                    "D",
                ]:
                    return error_response(
                        message="Submission failed",
                        errors={
                            "assignment": [
                                (
                                    "The answer key for "
                                    "one or more MCQ "
                                    "questions is missing. "
                                    "Please contact the academy."
                                )
                            ]
                        },
                        status_code=(
                            status.HTTP_400_BAD_REQUEST
                        ),
                    )

            elif (
                question.answer_type
                == AssignmentQuestion.AnswerType.TEXT
            ):
                text_answer = (
                    answer_data
                    .get(
                        "text_answer",
                        "",
                    )
                    .strip()
                )

                if (
                    question.is_required
                    and not text_answer
                ):
                    return error_response(
                        message="Submission failed",
                        errors={
                            "text_answer": [
                                (
                                    "Answer is required "
                                    "for this question."
                                )
                            ]
                        },
                        status_code=(
                            status.HTTP_400_BAD_REQUEST
                        ),
                    )

        # ---------------------------------------------
        # CREATE / GET SUBMISSION
        # ---------------------------------------------

        submission, created = (
            AssignmentSubmission.objects
            .get_or_create(
                assignment=assignment,
                student=student,
                defaults={
                    "firm": request.user.firm,
                },
            )
        )

        # ---------------------------------------------
        # CALCULATE / SAVE ANSWERS
        # ---------------------------------------------

        total_marks = Decimal(
            "0.00"
        )

        correct_answers = 0
        wrong_answers = 0

        mcq_only = all(
            question.answer_type
            == AssignmentQuestion.AnswerType.MCQ
            for question in questions
        )

        for answer_data in submitted_answers:
            question_uuid = str(
                answer_data[
                    "question_uuid"
                ]
            )

            question = question_map[
                question_uuid
            ]

            selected_option = (
                answer_data
                .get(
                    "selected_option",
                    "",
                )
                .strip()
                .upper()
            )

            text_answer = (
                answer_data
                .get(
                    "text_answer",
                    "",
                )
                .strip()
            )

            marks_obtained = None

            if (
                question.answer_type
                == AssignmentQuestion.AnswerType.MCQ
            ):
                if (
                    selected_option
                    == question.correct_option.upper()
                ):
                    marks_obtained = (
                        question.marks
                    )

                    total_marks += (
                        question.marks
                    )

                    correct_answers += 1

                else:
                    marks_obtained = Decimal(
                        "0.00"
                    )

                    wrong_answers += 1

            AssignmentAnswer.objects.update_or_create(
                submission=submission,
                question=question,
                defaults={
                    "text_answer": (
                        text_answer
                    ),
                    "selected_option": (
                        selected_option
                    ),
                    "marks_obtained": (
                        marks_obtained
                    ),
                },
            )

        submission.submitted_at = (
            timezone.now()
        )

        # ---------------------------------------------
        # MCQ = AUTO GRADE
        # TEXT / FILE = MANUAL GRADE
        # ---------------------------------------------

        if mcq_only:
            submission.status = (
                AssignmentSubmission
                .Status
                .GRADED
            )

            submission.total_marks_obtained = (
                total_marks
            )

            submission.graded_at = (
                timezone.now()
            )

        else:
            submission.status = (
                AssignmentSubmission
                .Status
                .SUBMITTED
            )

            submission.total_marks_obtained = (
                None
            )

        submission.save()

        # ---------------------------------------------
        # AUTO-GRADED MCQ RESPONSE
        # ---------------------------------------------

        if mcq_only:
            max_marks = (
                assignment.max_marks
            )

            # Fallback for older assignments
            # where max_marks may still be zero.

            if not max_marks:
                max_marks = sum(
                    (
                        question.marks
                        for question
                        in questions
                    ),
                    Decimal("0.00"),
                )

            percentage = Decimal(
                "0.00"
            )

            if max_marks:
                percentage = (
                    total_marks
                    / max_marks
                ) * Decimal(
                    "100"
                )

            return success_response(
                message=(
                    "Test submitted and "
                    "graded successfully"
                ),
                data={
                    "submission_uuid": str(
                        submission.uuid
                    ),
                    "total_questions": len(
                        questions
                    ),
                    "answered_questions": len(
                        submitted_answers
                    ),
                    "correct_answers": (
                        correct_answers
                    ),
                    "wrong_answers": (
                        wrong_answers
                    ),
                    "marks_obtained": (
                        total_marks
                    ),
                    "max_marks": (
                        max_marks
                    ),
                    "percentage": round(
                        percentage,
                        2,
                    ),
                    "status": (
                        submission.status
                    ),
                },
            )

        # ---------------------------------------------
        # MANUAL GRADING RESPONSE
        # ---------------------------------------------

        return success_response(
            message="Assignment submitted successfully",
            data={
                "submission_uuid": str(
                    submission.uuid
                ),
                "status": (
                    submission.status
                ),
            },
        )


# =========================================================
# STUDENT - RESULT
# =========================================================


class StudentAssignmentResultView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsStudent,
    ]

    def get(
        self,
        request,
        assignment_uuid,
    ):
        student = request.user.student_profile

        submission = get_object_or_404(
            AssignmentSubmission.objects
            .select_related(
                "assignment",
                "assignment__course",
            ),
            assignment__uuid=assignment_uuid,
            assignment__firm=request.user.firm,
            student=student,
        )

        enrollment = get_student_active_enrollment(
            student=student,
            course=submission.assignment.course,
        )

        if not enrollment:
            return error_response(
                message=(
                    "You do not have access "
                    "to this assignment result."
                ),
                errors={},
                status_code=status.HTTP_403_FORBIDDEN,
            )

        if (
            submission.status
            != AssignmentSubmission.Status.GRADED
        ):
            return success_response(
                message="Result is not available yet.",
                data={
                    "status": (
                        submission.status
                    ),
                },
            )

        answers = (
            submission.answers
            .select_related(
                "question"
            )
            .all()
        )

        mcq_answers = answers.filter(
            question__answer_type=(
                AssignmentQuestion
                .AnswerType
                .MCQ
            )
        )

        correct_answers = (
            mcq_answers
            .filter(
                selected_option=models.F(
                    "question__correct_option"
                )
            )
            .count()
        )

        mcq_count = (
            mcq_answers.count()
        )

        wrong_answers = (
            mcq_count
            - correct_answers
        )

        max_marks = (
            submission.assignment.max_marks
        )

        # Safety fallback for old imported
        # assignments where max_marks = 0.

        if not max_marks:
            max_marks = sum(
                (
                    question.marks
                    for question
                    in submission.assignment
                    .questions
                    .all()
                ),
                Decimal("0.00"),
            )

        marks_obtained = (
            submission.total_marks_obtained
            or Decimal("0.00")
        )

        percentage = Decimal(
            "0.00"
        )

        if max_marks:
            percentage = (
                marks_obtained
                / max_marks
            ) * Decimal(
                "100"
            )

        return success_response(
            message=(
                "Assignment result "
                "retrieved successfully"
            ),
            data={
                "assignment_uuid": str(
                    submission.assignment.uuid
                ),
                "assignment_title": (
                    submission.assignment.title
                ),
                "marks_obtained": (
                    marks_obtained
                ),
                "max_marks": (
                    max_marks
                ),
                "percentage": round(
                    percentage,
                    2,
                ),
                "correct_answers": (
                    correct_answers
                ),
                "wrong_answers": (
                    wrong_answers
                ),
                "status": (
                    submission.status
                ),
                "submitted_at": (
                    submission.submitted_at
                ),
                "graded_at": (
                    submission.graded_at
                ),
                "feedback": (
                    submission.feedback
                ),
            },
        )
        


class AssignmentDetailView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get_object(
        self,
        request,
        assignment_uuid,
    ):
        return get_object_or_404(
            Assignment.objects.select_related(
                "course",
                "subject",
                "chapter",
                "lesson",
                "created_by",
            ),
            uuid=assignment_uuid,
            firm=request.user.firm,
        )

    def get(
        self,
        request,
        assignment_uuid,
    ):
        assignment = self.get_object(
            request,
            assignment_uuid,
        )

        return success_response(
            message="Assignment retrieved successfully",
            data=AssignmentSerializer(
                assignment
            ).data,
        )

    def patch(
        self,
        request,
        assignment_uuid,
    ):
        assignment = self.get_object(
            request,
            assignment_uuid,
        )

        if assignment.submissions.exists():
            return error_response(
                message="Assignment update failed",
                errors={
                    "assignment": [
                        (
                            "This assignment cannot be "
                            "edited because students have "
                            "already submitted it."
                        )
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        serializer = AssignmentUpdateSerializer(
            assignment,
            data=request.data,
            partial=True,
        )

        if not serializer.is_valid():
            return error_response(
                message="Assignment update failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        assignment = serializer.save()

        return success_response(
            message="Assignment updated successfully",
            data=AssignmentSerializer(
                assignment
            ).data,
        )

    def delete(
        self,
        request,
        assignment_uuid,
    ):
        assignment = self.get_object(
            request,
            assignment_uuid,
        )

        if assignment.submissions.exists():
            return error_response(
                message="Assignment deletion failed",
                errors={
                    "assignment": [
                        (
                            "This assignment cannot be "
                            "deleted because students have "
                            "already submitted it."
                        )
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        assignment.delete()

        return success_response(
            message="Assignment deleted successfully",
            data={},
        )
        
        
        
        
        
class AssignmentPublishView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def patch(
        self,
        request,
        assignment_uuid,
    ):
        assignment = get_object_or_404(
            Assignment,
            uuid=assignment_uuid,
            firm=request.user.firm,
        )

        if assignment.is_published:
            return error_response(
                message="Assignment is already published.",
                errors={},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        if not assignment.is_active:
            return error_response(
                message="Assignment publishing failed",
                errors={
                    "assignment": [
                        "Inactive assignment cannot be published."
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        questions = list(
            assignment.questions.all()
        )

        if not questions:
            return error_response(
                message="Assignment publishing failed",
                errors={
                    "questions": [
                        (
                            "Add at least one question "
                            "before publishing."
                        )
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        total_question_marks = sum(
            (
                question.marks
                for question in questions
            ),
            Decimal("0.00"),
        )

        if total_question_marks != assignment.max_marks:
            return error_response(
                message="Assignment publishing failed",
                errors={
                    "max_marks": [
                        (
                            "Assignment max_marks must equal "
                            "the total marks of all questions. "
                            f"Question total is "
                            f"{total_question_marks}."
                        )
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        assignment.is_published = True

        assignment.save(
            update_fields=[
                "is_published",
                "updated_at",
            ]
        )

        return success_response(
            message="Assignment published successfully",
            data=AssignmentSerializer(
                assignment
            ).data,
        )


class AssignmentUnpublishView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def patch(
        self,
        request,
        assignment_uuid,
    ):
        assignment = get_object_or_404(
            Assignment,
            uuid=assignment_uuid,
            firm=request.user.firm,
        )

        if not assignment.is_published:
            return error_response(
                message="Assignment is already unpublished.",
                errors={},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        if assignment.submissions.exists():
            return error_response(
                message="Assignment unpublish failed",
                errors={
                    "assignment": [
                        (
                            "This assignment cannot be "
                            "unpublished because students "
                            "have already submitted it."
                        )
                    ]
                },
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        assignment.is_published = False

        assignment.save(
            update_fields=[
                "is_published",
                "updated_at",
            ]
        )

        return success_response(
            message="Assignment unpublished successfully",
            data=AssignmentSerializer(
                assignment
            ).data,
        )
        
        
        
