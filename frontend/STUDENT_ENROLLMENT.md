# Student enrollment

The journey is Register → Sign in → Explore → Course details → Enroll →
My Courses (pending approval) → Academy approval → Course content.

All self-service requests start as PENDING, including zero-price courses.
The academy confirms payment separately and activates enrollment through the
existing admin Enrollments screen. Submitting a request does not collect money,
mark fees as paid, or unlock course content.

Students can request published, active, online-purchasable courses within their
own active academy. Cross-academy enrollment is deliberately rejected. Registration
continues using the backend's DEFAULT_FIRM_CODE configuration.

## Backend API

- GET /api/v1/student/courses/{course_uuid}/enrollment/: status and has_access.
- POST the same URL with an empty JSON object: idempotently creates a PENDING
  enrollment for the authenticated student.
- GET /api/v1/student/enrollments/?page=1&page_size=20: paginated pending requests.

Identity, academy, fee and access overrides are rejected. Existing ACTIVE,
CANCELLED and COMPLETED records are preserved. No model migration is needed.

## Validation

Run Flutter tests with `flutter test`.

An isolated backend test environment was created at
`.enrollment-test-venv` under frontend. From backend, run:

```powershell
..\frontend\.enrollment-test-venv\Scripts\python.exe -m django test students.test_enrollment --settings=students.enrollment_test_settings --noinput
```

These settings use an in-memory SQLite database and do not load production .env.
They cover request authorization, tenant isolation, duplicate requests, pending
access restrictions, cancelled records, and the existing admin activation serializer.
Production uses MySQL; concurrent request handling should also be smoke-tested
against staging with that database.

## Deployment order

1. Deploy backend/students/enrollment_views.py and the updated portal_urls.py
   through the existing server deployment process, then restart the backend.
2. Validate the endpoints with a staging student account.
3. Build and distribute the new release APK after the backend is available.
4. Request a course as a student. Confirm PENDING in both My Courses and the
   admin enrollment list. Confirm content remains locked.
5. Activate the enrollment as the academy admin. Refresh My Courses and verify
   course materials are available.

Existing chapter-only grants remain supported. Existing APKs remain compatible
with the backend addition. A new APK requires the new backend endpoints.
No production deployment was performed as part of this implementation.
