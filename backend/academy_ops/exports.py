"""Downloadable attendance reports; exports are always generated from tenant-filtered rows."""
import csv
from io import BytesIO
from xml.sax.saxutils import escape
from django.http import HttpResponse
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, LongTable, TableStyle


def safe_cell(value):
    text = str(value or "")
    # Prevent spreadsheet formula execution in user-controlled text.
    if text.lstrip().startswith(("=", "+", "-", "@")):
        text = "'" + text
    return text


def attendance_export(batch, records, kind):
    headers = ["Academy", "Course", "Batch", "Date", "Session", "Admission number", "Student full name", "Status", "Note"]
    rows = [[batch.firm.name, batch.course.name, batch.name, str(row["date"]), row["session"], row["admission_number"], row["full_name"], row["status"], row["note"]] for row in records]
    filename = f"attendance_{batch.uuid}.{kind}"
    if kind == "csv":
        response = HttpResponse(content_type="text/csv; charset=utf-8")
        response.write("\ufeff")
        writer = csv.writer(response)
        writer.writerow(headers)
        writer.writerows([[safe_cell(value) for value in row] for row in rows])
    elif kind == "xlsx":
        from openpyxl import Workbook
        from openpyxl.styles import Font, PatternFill
        workbook = Workbook()
        sheet = workbook.active
        sheet.title = "Attendance"
        sheet.append(headers)
        for row in rows:
            sheet.append([safe_cell(value) for value in row])
        for cell in sheet[1]:
            cell.font = Font(bold=True, color="FFFFFF")
            cell.fill = PatternFill("solid", fgColor="008C95")
        sheet.freeze_panes = "A2"
        sheet.auto_filter.ref = sheet.dimensions
        for column, width in zip("ABCDEFGHI", [26, 26, 22, 14, 18, 20, 30, 16, 40]):
            sheet.column_dimensions[column].width = width
        buffer = BytesIO()
        workbook.save(buffer)
        response = HttpResponse(buffer.getvalue(), content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    else:
        buffer = BytesIO()
        styles = getSampleStyleSheet()
        from common.pdf_fonts import academy_pdf_font
        font = academy_pdf_font()
        for style in styles.byName.values():
            style.fontName = font
        small = styles["BodyText"]
        small.fontSize = 8
        small.leading = 10
        story = [Paragraph("Attendance report", styles["Title"]),
                 Paragraph(escape(f"{batch.firm.name} | {batch.course.name} | {batch.name}"), styles["BodyText"]), Spacer(1, 12)]
        # Academy/course/batch appear in the report title rather than every row.
        data = [[Paragraph(escape(value), small) for value in headers[3:]]]
        data += [[Paragraph(escape(str(value)), small) for value in row[3:]] for row in rows]
        table = LongTable(data, repeatRows=1, colWidths=[65, 75, 90, 150, 65, 300])
        table.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#DFF6F3")),
            ("GRID", (0, 0), (-1, -1), .3, colors.HexColor("#CBD5E1")),
            ("VALIGN", (0, 0), (-1, -1), "TOP"), ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
        ]))
        story.append(table)
        def footer(canvas, doc):
            canvas.setFont(font, 8)
            canvas.drawRightString(805, 20, f"Page {doc.page}")
        SimpleDocTemplate(buffer, pagesize=landscape(A4), leftMargin=24, rightMargin=24, topMargin=24, bottomMargin=32).build(story, onFirstPage=footer, onLaterPages=footer)
        response = HttpResponse(buffer.getvalue(), content_type="application/pdf")
    response["Content-Disposition"] = f'attachment; filename="{filename}"'
    return response
