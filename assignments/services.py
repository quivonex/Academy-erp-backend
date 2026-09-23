from django.db import transaction
import io
import re
import uuid
from django.core.files.storage import default_storage
from pypdf import PdfReader
from rest_framework.exceptions import ValidationError
from courses.models import (
    Course,
    Subject,
    Chapter,
    Lesson,
)

from .models import (
    Assignment,
    AssignmentQuestion,
)


def get_tenant_object(
    model,
    *,
    firm,
    object_uuid,
    field_name,
):
    try:
        return model.objects.get(
            uuid=object_uuid,
            firm=firm,
        )

    except model.DoesNotExist:
        raise ValidationError({
            field_name: [
                f"Invalid {field_name}."
            ]
        })


@transaction.atomic
def create_assignment(
    *,
    firm,
    created_by,
    validated_data,
):
    course_uuid = validated_data.pop(
        "course_uuid"
    )

    subject_uuid = validated_data.pop(
        "subject_uuid",
        None,
    )

    chapter_uuid = validated_data.pop(
        "chapter_uuid",
        None,
    )

    lesson_uuid = validated_data.pop(
        "lesson_uuid",
        None,
    )

    course = get_tenant_object(
        Course,
        firm=firm,
        object_uuid=course_uuid,
        field_name="course_uuid",
    )

    subject = None
    chapter = None
    lesson = None

    if subject_uuid:
        subject = get_tenant_object(
            Subject,
            firm=firm,
            object_uuid=subject_uuid,
            field_name="subject_uuid",
        )

        if subject.course_id != course.id:
            raise ValidationError({
                "subject_uuid": [
                    "Subject does not belong to this course."
                ]
            })

    if chapter_uuid:
        if not subject:
            raise ValidationError({
                "chapter_uuid": [
                    "subject_uuid is required."
                ]
            })

        chapter = get_tenant_object(
            Chapter,
            firm=firm,
            object_uuid=chapter_uuid,
            field_name="chapter_uuid",
        )

        if chapter.subject_id != subject.id:
            raise ValidationError({
                "chapter_uuid": [
                    "Chapter does not belong to this subject."
                ]
            })

    if lesson_uuid:
        if not chapter:
            raise ValidationError({
                "lesson_uuid": [
                    "chapter_uuid is required."
                ]
            })

        lesson = get_tenant_object(
            Lesson,
            firm=firm,
            object_uuid=lesson_uuid,
            field_name="lesson_uuid",
        )

        if lesson.chapter_id != chapter.id:
            raise ValidationError({
                "lesson_uuid": [
                    "Lesson does not belong to this chapter."
                ]
            })

    return Assignment.objects.create(
        firm=firm,
        course=course,
        subject=subject,
        chapter=chapter,
        lesson=lesson,
        created_by=created_by,
        **validated_data,
    )

def extract_pdf_text(uploaded_file):
    uploaded_file.seek(0)

    reader = PdfReader(uploaded_file)

    pages = []

    for page in reader.pages:
        text = page.extract_text()

        if text:
            pages.append(text)

    return "\n".join(pages).strip()

def parse_question_answers(text):
    if not text:
        return []

    text = text.replace("\r\n", "\n")
    text = text.replace("\r", "\n")

    pattern = re.compile(
        r"""
        (?:
            ^|\n
        )
        \s*
        (?:
            Q(?:uestion)?\s*
        )?
        (\d+)
        [\.\)\:\-]
        \s*
        (.*?)
        (?=
            \n\s*
            (?:
                Q(?:uestion)?\s*
            )?
            \d+
            [\.\)\:\-]
            |
            \Z
        )
        """,
        re.IGNORECASE
        | re.MULTILINE
        | re.DOTALL
        | re.VERBOSE,
    )

    questions = []

    for match in pattern.finditer(text):
        block = match.group(2).strip()

        if not block:
            continue

        answer_match = re.search(
            r"""
            \n?
            \s*
            (?:
                Answer
                |
                Ans
                |
                Solution
            )
            \s*[:\.\-]\s*
            """,
            block,
            re.IGNORECASE | re.VERBOSE,
        )

        question_text = block
        answer_text = ""

        if answer_match:
            question_text = block[
                :answer_match.start()
            ].strip()

            answer_text = block[
                answer_match.end():
            ].strip()

        if question_text:
            questions.append({
                "question_text": question_text,
                "answer_text": answer_text,
            })

    return questions

@transaction.atomic
def import_assignment_from_pdf(
    *,
    firm,
    created_by,
    validated_data,
):
    uploaded_pdf = validated_data.pop(
        "pdf"
    )

    course_uuid = validated_data.pop(
        "course_uuid"
    )

    subject_uuid = validated_data.pop(
        "subject_uuid",
        None,
    )

    chapter_uuid = validated_data.pop(
        "chapter_uuid",
        None,
    )

    lesson_uuid = validated_data.pop(
        "lesson_uuid",
        None,
    )

    course = get_tenant_object(
        Course,
        firm=firm,
        object_uuid=course_uuid,
        field_name="course_uuid",
    )

    subject = None
    chapter = None
    lesson = None

    if subject_uuid:
        subject = get_tenant_object(
            Subject,
            firm=firm,
            object_uuid=subject_uuid,
            field_name="subject_uuid",
        )

        if subject.course_id != course.id:
            raise ValidationError({
                "subject_uuid": [
                    "Subject does not belong to this course."
                ]
            })

    if chapter_uuid:
        if not subject:
            raise ValidationError({
                "chapter_uuid": [
                    "subject_uuid is required."
                ]
            })

        chapter = get_tenant_object(
            Chapter,
            firm=firm,
            object_uuid=chapter_uuid,
            field_name="chapter_uuid",
        )

        if chapter.subject_id != subject.id:
            raise ValidationError({
                "chapter_uuid": [
                    "Chapter does not belong to this subject."
                ]
            })

    if lesson_uuid:
        if not chapter:
            raise ValidationError({
                "lesson_uuid": [
                    "chapter_uuid is required."
                ]
            })

        lesson = get_tenant_object(
            Lesson,
            firm=firm,
            object_uuid=lesson_uuid,
            field_name="lesson_uuid",
        )

        if lesson.chapter_id != chapter.id:
            raise ValidationError({
                "lesson_uuid": [
                    "Lesson does not belong to this chapter."
                ]
            })

    try:
        extracted_text = extract_pdf_text(
            uploaded_pdf
        )

    except Exception as exc:
        raise ValidationError({
            "pdf": [
                f"Unable to read PDF: {str(exc)}"
            ]
        })

    if not extracted_text:
        raise ValidationError({
            "pdf": [
                (
                    "No readable text found in PDF. "
                    "Scanned PDFs require OCR."
                )
            ]
        })

    parsed_questions = parse_mcq_questions(
        extracted_text
    )
    
    if not parsed_questions:
        parsed_questions = parse_question_answers(
            extracted_text
        )

    if not parsed_questions:
        raise ValidationError({
            "pdf": [
                (
                    "No questions could be detected "
                    "in this PDF."
                )
            ]
        })

    storage_path = (
        f"assignments/"
        f"{firm.uuid}/"
        f"{course.uuid}/"
        f"{uuid.uuid4().hex}.pdf"
    )

    uploaded_pdf.seek(0)

    pdf_key = default_storage.save(
        storage_path,
        uploaded_pdf,
    )

    assignment = Assignment.objects.create(
        firm=firm,
        course=course,
        subject=subject,
        chapter=chapter,
        lesson=lesson,
        created_by=created_by,
        source_pdf_key=pdf_key,
        import_status="COMPLETED",
        is_published=False,
        **validated_data,
    )

    question_objects = []

    for index, item in enumerate(
        parsed_questions,
        start=1,
    ):
        question_objects.append(
            AssignmentQuestion(
                assignment=assignment,
                question_text=item[
                    "question_text"
                ],
                answer_text=item.get(
                    "answer_text",
                    "",
                ),
                answer_type=item.get(
                    "answer_type",
                    AssignmentQuestion.AnswerType.TEXT,
                ),
                option_a=item.get(
                    "option_a",
                    "",
                ),
                option_b=item.get(
                    "option_b",
                    "",
                ),
                option_c=item.get(
                    "option_c",
                    "",
                ),
                option_d=item.get(
                    "option_d",
                    "",
                ),
                correct_option=item.get(
                    "correct_option",
                    "",
                ),
                sequence=index,
                marks=1,
            )
        )

    AssignmentQuestion.objects.bulk_create(
        question_objects
    )

    total_marks = sum(
        (
            question.marks
            for question in question_objects
        ),
        0,
    )
    
    assignment.max_marks = total_marks
    assignment.save(
        update_fields=[
            "max_marks",
            "updated_at",
        ]
    )

    return assignment


@transaction.atomic
def create_assignment_question(
    *,
    assignment,
    validated_data,
):
    return AssignmentQuestion.objects.create(
        assignment=assignment,
        **validated_data,
    )
    
def parse_mcq_questions(text):
    if not text:
        return []

    text = text.replace("\r\n", "\n")
    text = text.replace("\r", "\n")

    question_pattern = re.compile(
        r"""
        (?:
            ^|\n
        )
        \s*
        (?:
            Q(?:uestion)?\s*
        )?
        (\d+)
        [\.\)\:\-]
        \s*
        (.*?)
        (?=
            \n\s*
            (?:
                Q(?:uestion)?\s*
            )?
            \d+
            [\.\)\:\-]
            |
            \Z
        )
        """,
        re.IGNORECASE
        | re.MULTILINE
        | re.DOTALL
        | re.VERBOSE,
    )

    questions = []

    for match in question_pattern.finditer(text):
        block = match.group(2).strip()

        option_a = re.search(
            r"(?:^|\n)\s*A[\.\)]\s*(.+)",
            block,
            re.IGNORECASE,
        )

        option_b = re.search(
            r"(?:^|\n)\s*B[\.\)]\s*(.+)",
            block,
            re.IGNORECASE,
        )

        option_c = re.search(
            r"(?:^|\n)\s*C[\.\)]\s*(.+)",
            block,
            re.IGNORECASE,
        )

        option_d = re.search(
            r"(?:^|\n)\s*D[\.\)]\s*(.+)",
            block,
            re.IGNORECASE,
        )

        if not all([
            option_a,
            option_b,
            option_c,
            option_d,
        ]):
            continue

        first_option_start = min(
            option_a.start(),
            option_b.start(),
            option_c.start(),
            option_d.start(),
        )

        question_text = block[
            :first_option_start
        ].strip()

        answer_match = re.search(
            r"""
            (?:
                Answer
                |
                Ans
                |
                Correct\s*Answer
            )
            \s*[:\.\-]?\s*
            ([ABCD])
            """,
            block,
            re.IGNORECASE | re.VERBOSE,
        )

        correct_option = ""

        if answer_match:
            correct_option = (
                answer_match.group(1).upper()
            )

        questions.append({
            "question_text": question_text,
            "answer_type": (
                AssignmentQuestion
                .AnswerType.MCQ
            ),
            "option_a": option_a.group(1).strip(),
            "option_b": option_b.group(1).strip(),
            "option_c": option_c.group(1).strip(),
            "option_d": option_d.group(1).strip(),
            "correct_option": correct_option,
            "answer_text": "",
        })

    return questions


