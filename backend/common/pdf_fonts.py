"""Embedded fonts avoid platform-dependent PDF font substitution."""
from pathlib import Path
import reportlab
from django.conf import settings
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont


def academy_pdf_font():
    name = "AcademySans"
    if name not in pdfmetrics.getRegisteredFontNames():
        bundled = Path(reportlab.__file__).parent / "fonts" / "Vera.ttf"
        font_path = getattr(settings, "ACADEMY_PDF_FONT_PATH", str(bundled))
        pdfmetrics.registerFont(TTFont(name, font_path))
    return name
