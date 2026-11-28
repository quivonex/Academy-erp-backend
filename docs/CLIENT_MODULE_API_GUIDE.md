# Backend handoff: client-requested modules

Base URL: `https://YOUR-API-HOST/api/v1`.
Use the existing JWT login and `Authorization: Bearer ACCESS_TOKEN`.
New administration workflows below require a Firm Admin of an active academy.
Course-material and existing material endpoints retain the existing Firm Admin/Staff permissions.
Student endpoints require an authenticated student in the same academy.
List responses use `data: {count, next, previous, results}`; support `page` and `page_size` (maximum 100).
UUIDs are public identifiers; never submit database IDs.

## 1. Course materials

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/courses/{course_uuid}/materials/` | List only this course's materials; supports search and material_type |
| POST | `/courses/{course_uuid}/materials/` | Create under this course; path course overrides body |
| GET/PATCH/DELETE | `/materials/{material_uuid}/` | Existing material operations |

Create uses multipart form-data for uploads. Fields: `title`, `description`, `material_type` (VIDEO/PDF/DOCUMENT/LINK), `teacher_uuid`, `sequence`, `duration_seconds`, `subject_uuid`, `chapter_uuid`, `lesson_uuid`, `source`, `file`. LINK uses `external_url` instead of a file. Optional fields remain optional. Teacher must be active and from this academy.
For videos, provide the actual positive duration for verified playback tracking. Sequence is course-wide, so use 1, 2, 3, ... across the course rather than restarting at each chapter.
The frontend embeds these actions inside Course Details and hides the separate Materials menu. No backend tab-removal operation exists.

## 2. Selected access and video unlocking

Grant access with module 4's selected enrollment API. Existing chapter-only grants remain supported.

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/student/courses/{course_uuid}/materials/` | Material rows include teacher_uuid, teacher_name, is_locked, lock_reason, prerequisite_material_uuid |
| GET | `/student/materials/{material_uuid}/` | Direct access; returns 403 while locked |
| POST | `/student/materials/{material_uuid}/watch-sessions/` | Start verified session; returns uuid and resume_position_seconds |
| POST | `/student/watch-sessions/{session_uuid}/heartbeat/` | Send `{"player_position_seconds": 15}` every 15 seconds during playback |
| POST | `/student/watch-sessions/{session_uuid}/end/` | End on pause/exit as appropriate; start a new session when resuming after ending |
| GET | `/student/materials/{material_uuid}/progress/` | Includes verified_watched_seconds, verified_completion_percentage, is_verified_completed |
| GET | `/student/courses/{course_uuid}/progress/` | Video completion uses verified progress; nonvideo completion uses existing flags |

Locked rows return `content_url: null`. Show the lock reason and do not open a player.
Seek position and the legacy direct progress POST do not unlock later videos. Completion uses the existing server threshold (90%). Refetch course material rows after verified completion to update the next lock.
Use signed URLs immediately; request fresh detail when a URL expires. Previously issued signed URLs remain usable until their storage expiry.

## 3. Full student overview

`GET /students/{student_uuid}/overview/`

Returns `personal_details` (including guardians), `login_enabled`, `courses`, and overall `attendance`.
Each course includes enrollment UUID/status, course UUID/name/mode, enrolled/access dates, total/completed/pending video counts, course completion percentage, verified watch percentage, per-video teacher/progress, fee summary when one exists, and attendance counts.
No passwords, tokens or other students' data are returned. Open this endpoint when an admin selects a student name.

## 4. Bulk course assignment using a student picker

`GET /courses/{course_uuid}/enrollment-candidates/?search=Asha%20Patil&page=1`

Each row contains `student_uuid`, `full_name`, `admission_number`, `can_assign`, `reason`, `enrollment_status`, `access_end_at`. Disable selection when `can_assign=false`.

`POST /courses/{course_uuid}/bulk-assign/`

```json
{
  "student_uuids": ["STUDENT_UUID_1", "STUDENT_UUID_2"],
  "access_start_at": "2026-12-01T09:00:00+05:30",
  "access_end_at": "2027-03-01T09:00:00+05:30"
}
```

Dates are optional; omit them to use current time and course duration.
Up to 500 distinct selected students per call. Invalid/cross-academy students reject the request atomically.
Unexpired enrollments are skipped with a reason; valid students are assigned. Response contains `assigned`, `skipped`, `assigned_count`, `skipped_count`. Refresh the picker after submission.
Expired enrollment is renewed in place with an audit record, preserving previous progress/fees. An enrollment with no expiry is indefinite and remains unavailable for another grant.

## 5. Batches and manual attendance

`POST /batches/`

```json
{
  "course_uuid": "COURSE_UUID",
  "name": "Python Morning Batch",
  "start_date": "2026-12-01",
  "end_date": "2027-02-28"
}
```

Only active OFFLINE/HYBRID courses are allowed. Names are unique per academy/course.
`GET /batches/?course_uuid={course_uuid}` lists batches. `GET/PATCH /batches/{batch_uuid}/` retrieves/updates one. Set `is_active=false` to archive it; historical attendance remains available. Course is immutable, and dates cannot change after attendance exists.

`POST /batches/{batch_uuid}/members/`

```json
{
  "enrollment_uuids": ["ENROLLMENT_UUID"],
  "joined_on": "2026-12-01"
}
```

Members must have active enrollment in the batch's course with access covering the join date.
`GET /batches/{batch_uuid}/members/` returns names, student/enrollment/membership UUIDs and join/leave dates.
`PATCH /batches/{batch_uuid}/members/{membership_uuid}/` with `{"left_on":"2027-01-15"}` closes membership without removing attendance.

`GET /batches/{batch_uuid}/attendance/?date=2026-12-02&label=Daily`

Returns the full-name roster for that batch/date and status `UNMARKED` when no attendance was saved. Show explicit Present/Absent/Late/Leave choices.

`POST /batches/{batch_uuid}/attendance/`

```json
{
  "date": "2026-12-02",
  "label": "Daily",
  "records": [
    {"student_uuid":"STUDENT_UUID_1","status":"PRESENT","note":""},
    {"student_uuid":"STUDENT_UUID_2","status":"ABSENT","note":""}
  ]
}
```

Dates must be within the batch and not in the future. All selected students must be eligible members on that date.
Repeated saves update submitted students only; no duplicated session/records. Up to 500 distinct students per call. Use `label` for multiple sessions on one day; it defaults to Daily.

Reports and downloads:

```text
GET /batches/{batch_uuid}/attendance/report/?date_from=2026-12-01&date_to=2026-12-31
GET /batches/{batch_uuid}/attendance/report/?date_from=2026-12-01&date_to=2026-12-31&export=csv
GET /batches/{batch_uuid}/attendance/report/?export=xlsx
GET /batches/{batch_uuid}/attendance/report/?export=pdf
```

Without `export`, response is paginated JSON. With `export`, read binary bytes (not JSON) and use Content-Disposition for the filename. XLSX includes frozen/styled headers and column widths; PDF includes wrapping, repeated table headings and page numbers. CSV uses UTF-8 BOM. CSV/XLSX escape formula-like user text. Use date filters for exports over 10,000 rows. Reports list saved marks only. PDF uses the standard Latin font; CSV/XLSX preserve Unicode names.

## 6. Job openings, applications and interviews

`POST /placements/openings/`

```json
{
  "title": "Junior Python Developer",
  "company_name": "Example Technologies",
  "description": "Entry-level Python/Django role.",
  "eligibility": "Python course students",
  "location": "Pune",
  "application_deadline": "2026-12-20T18:00:00+05:30",
  "interview_at": "2026-12-22T10:00:00+05:30",
  "interview_end_at": "2026-12-22T17:00:00+05:30",
  "interview_venue": "Company office, Pune",
  "interview_url": "",
  "is_published": true
}
```

| Actor | Method | Path |
| --- | --- | --- |
| Admin | GET | `/placements/openings/` |
| Admin | GET/PATCH | `/placements/openings/{opening_uuid}/` |
| Admin | GET | `/placements/openings/{opening_uuid}/applications/?status=APPLIED` |
| Admin | PATCH | `/placements/applications/{application_uuid}/` |
| Student | GET | `/student/jobs/` |
| Student | GET | `/student/jobs/{opening_uuid}/` |
| Student | POST | `/student/jobs/{opening_uuid}/apply/` |
| Student | GET | `/student/job-applications/` |
| Student | POST | `/student/job-applications/{application_uuid}/withdraw/` |

Student apply payload: `{"cover_letter":"I am interested.","resume_url":"https://example.com/my-resume.pdf"}`; both fields optional. This is a resume link, not a file upload. No application after deadline, no duplicate or cross-academy applications. Withdrawing does not allow applying twice to the same opening.

Admin review payload:

```json
{
  "status":"INTERVIEW",
  "interview_at":"2026-12-22T11:30:00+05:30",
  "admin_note":"Internal review note"
}
```

Allowed admin statuses: SHORTLISTED, INTERVIEW, SELECTED, REJECTED. INTERVIEW requires a future candidate interview time. Student sees status and their interview time but not admin_note. A withdrawn application cannot be reviewed; SELECTED/REJECTED cannot be withdrawn. Closing an opening uses `is_active=false`; existing applications remain in history. Eligibility text is informational; no automated academic eligibility engine is assumed.

## 7. MCQ template and prompt

`GET /assignments/mcq-template/` downloads the sample PDF.
`GET /assignments/mcq-template/prompt/` returns the prompt, sample and instructions.

Edit/export selectable text following this exact format:

```text
1. Which language is used with Django?
A. Java
B. Python
C. Swift
D. Kotlin
Answer: B
```

Then use the existing multipart `POST /assignments/import-pdf/` with `course_uuid`, `title`, and `pdf`.
No scanned images, multiple columns, separate answer keys or explanations. Keep all options and the answer with each question. The strict MCQ importer reports incomplete A-D options instead of silently skipping that question. Review imported questions before publishing.

## Errors and frontend acceptance order

- 401/403: authentication/role/access/lock failure; 404: resource is missing or outside the academy.
- 400: invalid UUID/date/status/selection or duplicate application; show the returned error text.
- Existing endpoints sometimes use `success/message/errors`; DRF validation errors on new endpoints are field-keyed. Do not assume every error uses a data envelope.
- Integrate modules 1-7 in the order above. Backend regression tests do not replace browser/device acceptance testing.
