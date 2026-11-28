# Academy ERP backend checkpoint

Updated: 2026-11-28. Base: `9e4dca2165476e4f24f61c437c49cc0591f887c1`.
Scope: backend only. Frontend developers own UI changes.

## Revision record

| Date | Revision | Integration and deployment state |
| --- | --- | --- |
| 2026-11-28 | Initial seven backend client modules; 59 tests passing | Integration branch `client-backend-modules-20261128`; associated pull request records the merge. Production migration and deployment remain pending. |

The repository root `AGENTS.md` directs future development to this checkpoint.

Read this file first on the next development turn, then `docs/CLIENT_MODULE_API_GUIDE.md`.
Inspect only the files for the module being changed; a full-repository audit is unnecessary unless the base or contracts changed.

| Module | State | Main implementation |
| --- | --- | --- |
| 1. Materials inside course | Implemented API | `materials/views.py`, `academy_ops/urls.py` |
| 2. Teacher + sequential videos | Existing teacher field retained; lock enforcement added | `materials/access.py`, `students/portal_serializers.py`, `students/portal_views.py`, `progress/views.py`, `progress/services.py`, `progress/serializers.py` |
| 3. Student overview | Implemented | `academy_ops/views.py:StudentOverviewView` |
| 4. Selected bulk enrollment | Implemented; no duplicate unexpired access | `academy_ops/views.py:EnrollmentCandidatesView`, `BulkCourseAssignView`, `courses/services.py:create_enrollment` |
| 5. Offline/hybrid batch attendance | Implemented; CSV/XLSX/PDF exports | `academy_ops/models.py`, `serializers.py`, `views.py`, `exports.py` |
| 6. Openings + interview + applications | Implemented | `academy_ops/models.py`, `serializers.py`, `views.py` |
| 7. Download MCQ template + AI prompt | Implemented; template round-trip tested | `assignments/template_views.py`, `assignments/services.py` |

## Decisions to preserve

- Firm Admin permissions apply to the new administration endpoints. Students use only their academy and own applications.
- Existing material/fee/enrollment endpoints remain available; removing a sidebar entry is frontend work.
- Video ordering is course-wide `(sequence, created_at, pk)`. Every earlier available video in the student's access scope must be verified-complete, including optional videos. A chapter-only grant considers only the granted chapters.
- Verified completion uses the existing 90% watch threshold in `progress/services.py`; it does not use frontend `mark_completed` or seek position. Heartbeats should be sent every 15 seconds while playing.
- Locked material rows contain metadata but no content URL; direct detail and watch/progress requests are denied. Heartbeats recheck access after revocation.
- New active enrollment expiry uses explicit `access_end_at`, else `access_duration_days`, else calendar `duration_months`. If none is set, access is indefinite and cannot be renewed automatically.
- The existing unique `(student, course)` enrollment constraint is retained. An expired enrollment is renewed in place, and its former access period is recorded in `EnrollmentRenewal`. Previous learning progress and fee ledger are retained. Renewal does not charge fees or reset learning. A separate paid re-enrollment/history redesign would be a new requirement.
- Any unexpired enrollment, including pending or completed, is unavailable for a second grant. Pending access without an end date must be activated through the existing enrollment update API rather than assigned again.
- New bulk assignment takes explicit selected student UUIDs. The older admission-date bulk endpoint remains compatible; use the new endpoint for this client requirement.
- Attendance marks are explicit; unmarked students are not silently treated as absent. Reposting the same batch/date/session updates the submitted students without creating duplicates. Missing records in an update retain their previous values.
- Batch memberships preserve join/leave dates. A student can belong to one open batch per course enrollment. Renewing expired access closes its previous open batch memberships; assign the renewed enrollment to its new batch explicitly.
- Reports contain recorded attendance only, not inferred absences. Overall attendance counts PRESENT and LATE as attended; ABSENT and LEAVE remain in the denominator.
- Job applications accept an optional resume URL and cover letter. This release does not add a resume-upload service, employer login or automated interview messages.
- Item 8 in the client's list was blank; no additional scope was inferred.

## Verification and limits

`python manage.py test academy_ops students.test_enrollment --settings=academy_ops.test_settings --noinput`

59 tests passed in the last recorded run. Includes end-to-end verified heartbeat unlocking, seek rejection, chapter-only tracking, teacher scoping, existing enrollment tests, duplicate/expired grants, calendar-duration fallback, tenant isolation, attendance idempotency, CSV/XLSX/PDF contents, full template import, applications and interviews.
`makemigrations --check --dry-run` and Django system checks passed.

SQLite tests run against isolated settings and do not read production `.env`. No live MySQL migration, concurrent MySQL request test, S3 playback or frontend test was performed. Deploy to a test environment before production.

## Schema/dependencies

- Add `academy_ops` to installed apps (included in changed settings).
- Apply `academy_ops/migrations/0001_initial.py` after the existing migrations.
- New dependency: `openpyxl>=3.1,<4`. Existing reportlab, pypdf and python-dateutil are reused.
- `requirements.txt` is UTF-16 and was deliberately preserved. Install the additive `requirements-client-modules.txt`.
- Do not use `academy_ops.test_settings` on a running server.

## Next development work

Frontend integration and client acceptance testing, module by module, using the API guide and Postman collection. Preserve the Rolex teal theme on the frontend. Keep source comments in English.
When a module changes, update this file's state, API guide, migrations and its test cases together.
