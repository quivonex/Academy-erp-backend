from io import BytesIO
from django.http import HttpResponse
from rest_framework.views import APIView
from common.permissions import IsFirmAdmin
from common.responses import success_response

MCQ_SAMPLE = """1. Which language is used with Django?
A. Java
B. Python
C. Swift
D. Kotlin
Answer: B

2. What is 2 + 2?
A. 3
B. 5
C. 4
D. 6
Answer: C
"""

MCQ_PROMPT = """Create [NUMBER] multiple-choice questions on [TOPIC] for [LEVEL].
Use plain text and exactly this structure for every question:
1. Question text
A. First option
B. Second option
C. Third option
D. Fourth option
Answer: B

Number questions sequentially. Each question and each option must occupy a single
paragraph. Include exactly four options A-D and exactly one correct Answer: A/B/C/D
line immediately after the options. Separate questions with a blank line.
Do not include markdown, tables, columns, explanations, an answer-key section,
page headers, numbered instructions, images or scanned text. Use selectable text.
Use a Unicode-capable font if another language is required. Export the questions
as a text-based PDF. Keep all options and the answer with their question.
"""


def mcq_template_pdf():
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import getSampleStyleSheet
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Preformatted
    buffer = BytesIO()
    styles = getSampleStyleSheet()
    from common.pdf_fonts import academy_pdf_font
    font = academy_pdf_font()
    for style in styles.byName.values():
        style.fontName = font
    styles["Code"].fontSize = 11
    styles["Code"].leading = 16
    story = [Paragraph("MCQ assignment template", styles["Title"]),
             Paragraph("Replace the sample questions. Keep numbering, A-D option labels and the Answer line exactly as shown. Use selectable text, one column and no images.", styles["BodyText"]),
             Spacer(1, 20), Preformatted(MCQ_SAMPLE, styles["Code"])]
    SimpleDocTemplate(buffer, pagesize=A4, rightMargin=42, leftMargin=42).build(story)
    return buffer.getvalue()


class MCQTemplateView(APIView):
    permission_classes = [IsFirmAdmin]

    def get(self, request):
        response = HttpResponse(mcq_template_pdf(), content_type="application/pdf")
        response["Content-Disposition"] = 'attachment; filename="mcq_assignment_template.pdf"'
        return response


class MCQTemplatePromptView(APIView):
    permission_classes = [IsFirmAdmin]

    def get(self, request):
        return success_response({"prompt": MCQ_PROMPT, "sample": MCQ_SAMPLE,
                                 "instructions": "Export selectable text to PDF; do not scan or photograph it."})
