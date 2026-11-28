"""Generate the downloadable MCQ sample, prompt, Postman collection and export previews."""
import json
import os
import sys
import subprocess
import zipfile
from pathlib import Path
from datetime import date
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "academy_ops.test_settings")
import django
django.setup()
from assignments.template_views import mcq_template_pdf, MCQ_PROMPT, MCQ_SAMPLE
from academy_ops.exports import attendance_export


def main(destination):
    destination.mkdir(parents=True, exist_ok=True)
    (destination / "mcq_assignment_template.pdf").write_bytes(mcq_template_pdf())
    (destination / "mcq_ai_prompt.txt").write_text(MCQ_PROMPT, encoding="utf-8")
    (destination / "mcq_editable_sample.txt").write_text(MCQ_SAMPLE, encoding="utf-8")
    sample_batch = SimpleNamespace(uuid="sample", name="Python Morning Batch", course=SimpleNamespace(name="Python - Hybrid"), firm=SimpleNamespace(name="Rolex Academy"))
    rows = [dict(date=date(2026, 11, 28), session="Daily", full_name="Asha Patil", admission_number="S001", status="PRESENT", note=""),
            dict(date=date(2026, 11, 28), session="Daily", full_name="Ravi Jadhav", admission_number="S002", status="LATE", note="Arrived ten minutes late")]
    for kind in ["pdf", "xlsx", "csv"]:
        (destination / f"attendance_example.{kind}").write_bytes(attendance_export(sample_batch, rows, kind).content)

    def request(name, method, path, body=None, student=False, capture=None):
        value = {"name": name, "request": {"method": method, "url": "{{base_url}}" + path,
                 "auth": {"type": "bearer", "bearer": [{"key": "token", "value": "{{student_token}}" if student else "{{admin_token}}", "type": "string"}]}}}
        if body is not None:
            value["request"]["header"] = [{"key": "Content-Type", "value": "application/json"}]
            value["request"]["body"] = {"mode": "raw", "raw": json.dumps(body, indent=2), "options": {"raw": {"language": "json"}}}
        if capture:
            value["event"] = [{"listen": "test", "script": {"type": "text/javascript", "exec": ["if (pm.response.code < 300) {", "  const data = pm.response.json().data;", f"  if (data && data.uuid) pm.collectionVariables.set('{capture}', data.uuid);", "}"]}}]
        return value

    groups = [
        {"name": "1 - Course materials", "item": [
            request("Course material list", "GET", "/courses/{{course_uuid}}/materials/"),
            request("Create course link material", "POST", "/courses/{{course_uuid}}/materials/", {"title": "Course documentation", "material_type": "LINK", "external_url": "https://docs.python.org/3/", "sequence": 1}),
            request("Assign video teacher", "PATCH", "/materials/{{material_uuid}}/", {"teacher_uuid": "{{teacher_uuid}}"}),
        ]},
        {"name": "2 - Verified video sequence", "item": [
            request("Student course materials and locks", "GET", "/student/courses/{{course_uuid}}/materials/", student=True),
            request("Student material detail", "GET", "/student/materials/{{material_uuid}}/", student=True),
            request("Start watch session", "POST", "/student/materials/{{material_uuid}}/watch-sessions/", student=True, capture="session_uuid"),
            request("Watch heartbeat - advance with real time", "POST", "/student/watch-sessions/{{session_uuid}}/heartbeat/", {"player_position_seconds": 15}, student=True),
            request("End watch session", "POST", "/student/watch-sessions/{{session_uuid}}/end/", student=True),
            request("Course progress", "GET", "/student/courses/{{course_uuid}}/progress/", student=True),
        ]},
        {"name": "3 - Student overview", "item": [request("Full student overview", "GET", "/students/{{student_uuid}}/overview/")]},
        {"name": "4 - Selected bulk access", "item": [
            request("Search candidate students", "GET", "/courses/{{course_uuid}}/enrollment-candidates/?search=&page=1"),
            request("Grant selected student access", "POST", "/courses/{{course_uuid}}/bulk-assign/", {"student_uuids": ["{{student_uuid}}"]}),
        ]},
        {"name": "5 - Batches and attendance", "item": [
            request("List course batches", "GET", "/batches/?course_uuid={{course_uuid}}"),
            request("Create batch", "POST", "/batches/", {"course_uuid": "{{course_uuid}}", "name": "Morning batch", "start_date": "{{batch_start_date}}", "end_date": "{{batch_end_date}}"}, capture="batch_uuid"),
            request("Add enrollment to batch", "POST", "/batches/{{batch_uuid}}/members/", {"enrollment_uuids": ["{{enrollment_uuid}}"], "joined_on": "{{attendance_date}}"}),
            request("Batch members", "GET", "/batches/{{batch_uuid}}/members/"),
            request("Attendance roster", "GET", "/batches/{{batch_uuid}}/attendance/?date={{attendance_date}}"),
            request("Mark attendance", "POST", "/batches/{{batch_uuid}}/attendance/", {"date": "{{attendance_date}}", "label": "Daily", "records": [{"student_uuid": "{{student_uuid}}", "status": "PRESENT", "note": ""}]}),
            request("Attendance JSON report", "GET", "/batches/{{batch_uuid}}/attendance/report/"),
            *[request(f"Download attendance {kind.upper()}", "GET", f"/batches/{{{{batch_uuid}}}}/attendance/report/?export={kind}") for kind in ["csv", "xlsx", "pdf"]],
        ]},
        {"name": "6 - Placements and applications", "item": [
            request("Create published opening", "POST", "/placements/openings/", {"title": "Junior Python Developer", "company_name": "Example Technologies", "description": "Python/Django role", "location": "Pune", "application_deadline": "{{job_deadline}}", "is_published": True}, capture="opening_uuid"),
            request("Admin openings", "GET", "/placements/openings/"),
            request("Student openings", "GET", "/student/jobs/", student=True),
            request("Apply as student", "POST", "/student/jobs/{{opening_uuid}}/apply/", {"cover_letter": "I am interested in this role."}, student=True, capture="application_uuid"),
            request("Admin applications", "GET", "/placements/openings/{{opening_uuid}}/applications/"),
            request("Schedule candidate interview", "PATCH", "/placements/applications/{{application_uuid}}/", {"status": "INTERVIEW", "interview_at": "{{interview_at}}", "admin_note": "Internal review"}),
            request("My applications", "GET", "/student/job-applications/", student=True),
            request("Withdraw my application", "POST", "/student/job-applications/{{application_uuid}}/withdraw/", student=True),
        ]},
        {"name": "7 - MCQ template", "item": [
            request("Download MCQ PDF", "GET", "/assignments/mcq-template/"),
            request("MCQ AI prompt", "GET", "/assignments/mcq-template/prompt/"),
        ]},
    ]
    variables = {"base_url": "http://127.0.0.1:8000/api/v1", "admin_token": "", "student_token": "",
                 **{name: "" for name in ["course_uuid", "student_uuid", "enrollment_uuid", "teacher_uuid", "material_uuid", "session_uuid", "batch_uuid", "opening_uuid", "application_uuid"]},
                 "attendance_date": "2026-11-28", "batch_start_date": "2026-11-28", "batch_end_date": "2027-02-28",
                 "job_deadline": "2026-12-20T18:00:00+05:30", "interview_at": "2026-12-22T11:30:00+05:30"}
    collection = {"info": {"name": "Academy ERP - Client backend modules", "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json", "description": "Set JWT tokens and UUID variables. Use an OFFLINE/HYBRID course for batches; use a current, enrolled student. Change example dates when necessary."},
                  "variable": [{"key": key, "value": value} for key, value in variables.items()], "item": groups}
    (destination / "Academy_Client_Modules.postman_collection.json").write_text(json.dumps(collection, indent=2), encoding="utf-8")
    if "--package" in sys.argv:
        base = "9e4dca2165476e4f24f61c437c49cc0591f887c1"
        changed = subprocess.check_output(["git", "diff", "--name-only", base, "HEAD"], cwd=ROOT, text=True).splitlines()
        package = destination / "academy_backend_client_modules.zip"
        with zipfile.ZipFile(package, "w", zipfile.ZIP_DEFLATED) as archive:
            for name in changed:
                archive.write(ROOT / name, name)
            for name in ["mcq_assignment_template.pdf", "mcq_ai_prompt.txt", "mcq_editable_sample.txt", "Academy_Client_Modules.postman_collection.json", "attendance_example.pdf", "attendance_example.xlsx", "attendance_example.csv"]:
                archive.write(destination / name, "handoff/" + name)
            for patch in destination.glob("*.patch"):
                archive.write(patch, patch.name)
            archive.write(ROOT / "docs" / "CLIENT_MODULE_INSTALL.md", "START_HERE.md")
        print(package)
    print(destination)


if __name__ == "__main__":
    main(Path(sys.argv[1]).resolve())
