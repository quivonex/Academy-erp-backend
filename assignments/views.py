from django.db.models import Q
from django.db import transaction
from django.db import models
from django.shortcuts import get_object_or_404
from decimal import Decimal
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

from .models import (
    Assignment,
    AssignmentQuestion,
    AssignmentSubmission,
    AssignmentAnswer,
)
from .serializers import (
    AssignmentSerializer,
    AssignmentQuestionSerializer,
    AssignmentPDFImportSerializer,
    StudentAssignmentQuestionSerializer,
    StudentAssignmentSubmitSerializer,
)
from courses.access import (
    get_student_active_enrollment,
)
from .services import (
    create_assignment,
    create_assignment_question,
    import_assignment_from_pdf,
)


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


class AssignmentDetailView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get(self, request, assignment_uuid):
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


class AssignmentQuestionListCreateView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsFirmAdminOrStaff,
    ]

    def get(self, request, assignment_uuid):
        assignment = get_object_or_404(
            Assignment,
            uuid=assignment_uuid,
            firm=request.user.firm,
        )

        questions = assignment.questions.all()

        return success_response(
            message="Assignment questions retrieved successfully",
            data=AssignmentQuestionSerializer(
                questions,
                many=True,
            ).data,
        )

    def post(self, request, assignment_uuid):
        assignment = get_object_or_404(
            Assignment,
            uuid=assignment_uuid,
            firm=request.user.firm,
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

        questions = assignment.questions.all()

        return success_response(
            message=(
                "PDF imported successfully. "
                "Please review questions before publishing."
            ),
            data={
                "assignment": AssignmentSerializer(
                    assignment
                ).data,
                "questions": (
                    AssignmentQuestionSerializer(
                        questions,
                        many=True,
                    ).data
                ),
                "question_count": questions.count(),
            },
            status_code=status.HTTP_201_CREATED,
        )
        
        
class StudentCourseAssignmentListView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsStudent,
    ]

    def get(self, request, course_uuid):
        student = request.user.student_profile

        assignment = Assignment.objects.filter(
            course__uuid=course_uuid,
            firm=request.user.firm,
            is_active=True,
            is_published=True,
        ).select_related(
            "course",
            "subject",
            "chapter",
            "lesson",
        )

        course = assignment.first()

        if not course:
            return success_response(
                message="No assignments found.",
                data=[],
            )

        enrollment = get_student_active_enrollment(
            student=student,
            course=course.course,
        )

        if not enrollment:
            return error_response(
                message=(
                    "You do not have access "
                    "to this course."
                ),
                errors={},
                status_code=(
                    status.HTTP_403_FORBIDDEN
                ),
            )

        return success_response(
            message="Assignments retrieved successfully",
            data=AssignmentSerializer(
                assignment,
                many=True,
            ).data,
        )
        
        
        
class StudentAssignmentDetailView(APIView):
    permission_classes = [
        IsAuthenticated,
        IsStudent,
    ]

    def get(self, request, assignment_uuid):
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
                status_code=(
                    status.HTTP_403_FORBIDDEN
                ),
            )

        questions = assignment.questions.all()

        return success_response(
            message="Assignment retrieved successfully",
            data={
                "uuid": str(assignment.uuid),
                "title": assignment.title,
                "description": assignment.description,
                "instructions": assignment.instructions,
                "max_marks": assignment.max_marks,
                "due_at": assignment.due_at,
                "questions": (
                    StudentAssignmentQuestionSerializer(
                        questions,
                        many=True,
                    ).data
                ),
            },
        )
        
        
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
            Assignment,
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
                status_code=(
                    status.HTTP_403_FORBIDDEN
                ),
            )

        if (
            assignment.due_at
            and timezone.now() > assignment.due_at
            and not assignment.allow_late_submission
        ):
            return error_response(
                message="Assignment deadline has passed.",
                errors={},
                status_code=(
                    status.HTTP_400_BAD_REQUEST
                ),
            )

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
                message=(
                    "Assignment already submitted."
                ),
                errors={},
                status_code=(
                    status.HTTP_400_BAD_REQUEST
                ),
            )

        serializer = (
            StudentAssignmentSubmitSerializer(
                data=request.data
            )
        )

        if not serializer.is_valid():
            return error_response(
                message="Submission failed",
                errors=serializer.errors,
                status_code=(
                    status.HTTP_400_BAD_REQUEST
                ),
            )

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

        total_marks = Decimal("0.00")
        correct_answers = 0
        wrong_answers = 0
        mcq_only = True

        submitted_answers = (
            serializer.validated_data[
                "answers"
            ]
        )

        for answer_data in submitted_answers:
            question = get_object_or_404(
                AssignmentQuestion,
                uuid=answer_data[
                    "question_uuid"
                ],
                assignment=assignment,
            )

            selected_option = (
                answer_data
                .get(
                    "selected_option",
                    "",
                )
                .upper()
            )

            text_answer = answer_data.get(
                "text_answer",
                "",
            )

            marks_obtained = None

            if (
                question.answer_type
                == AssignmentQuestion.AnswerType.MCQ
            ):
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
                                    "MCQ answer must "
                                    "be A, B, C, or D."
                                )
                            ]
                        },
                        status_code=(
                            status.HTTP_400_BAD_REQUEST
                        ),
                    )

                if (
                    selected_option
                    == question.correct_option
                ):
                    marks_obtained = question.marks

                    total_marks += (
                        question.marks
                    )

                    correct_answers += 1

                else:
                    marks_obtained = Decimal(
                        "0.00"
                    )

                    wrong_answers += 1

            else:
                mcq_only = False

            AssignmentAnswer.objects.update_or_create(
                submission=submission,
                question=question,
                defaults={
                    "text_answer": text_answer,
                    "selected_option": (
                        selected_option
                    ),
                    "marks_obtained": (
                        marks_obtained
                    ),
                },
            )

        submission.submitted_at = timezone.now()

        if mcq_only:
            submission.status = (
                AssignmentSubmission.Status.GRADED
            )

            submission.total_marks_obtained = (
                total_marks
            )

            submission.graded_at = timezone.now()

        else:
            submission.status = (
                AssignmentSubmission.Status.SUBMITTED
            )

        submission.save()

        if mcq_only:
            max_marks = assignment.max_marks

            if max_marks == 0:
                max_marks = sum(
                    (
                        question.marks
                        for question
                        in assignment.questions.all()
                    ),
                    Decimal("0.00"),
                )

            percentage = Decimal("0.00")

            if max_marks:
                percentage = (
                    total_marks
                    / max_marks
                ) * Decimal("100")

            return success_response(
                message=(
                    "Test submitted and "
                    "graded successfully"
                ),
                data={
                    "submission_uuid": str(
                        submission.uuid
                    ),
                    "total_questions": (
                        len(submitted_answers)
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
                    "max_marks": max_marks,
                    "percentage": round(
                        percentage,
                        2,
                    ),
                    "status": (
                        submission.status
                    ),
                },
            )

        return success_response(
            message="Assignment submitted successfully",
            data={
                "submission_uuid": str(
                    submission.uuid
                ),
                "status": submission.status,
            },
        )
        
        

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
            ),
            assignment__uuid=assignment_uuid,
            assignment__firm=request.user.firm,
            student=student,
        )

        if (
            submission.status
            != AssignmentSubmission.Status.GRADED
        ):
            return success_response(
                message="Result is not available yet.",
                data={
                    "status": submission.status,
                },
            )

        answers = (
            submission.answers
            .select_related(
                "question"
            )
            .all()
        )

        correct_answers = answers.filter(
            question__answer_type=(
                AssignmentQuestion.AnswerType.MCQ
            ),
            selected_option=(
                models.F(
                    "question__correct_option"
                )
            ),
        ).count()

        mcq_count = answers.filter(
            question__answer_type=(
                AssignmentQuestion.AnswerType.MCQ
            )
        ).count()

        wrong_answers = (
            mcq_count - correct_answers
        )

        max_marks = (
            submission.assignment.max_marks
        )

        percentage = Decimal("0.00")

        if max_marks:
            percentage = (
                submission.total_marks_obtained
                / max_marks
            ) * Decimal("100")

        return success_response(
            message="Assignment result retrieved successfully",
            data={
                "assignment_uuid": str(
                    submission.assignment.uuid
                ),
                "marks_obtained": (
                    submission.total_marks_obtained
                ),
                "max_marks": max_marks,
                "percentage": round(
                    percentage,
                    2,
                ),
                "correct_answers": correct_answers,
                "wrong_answers": wrong_answers,
                "status": submission.status,
            },
        )
        
        
    