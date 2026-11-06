# Course setup and Firm Admin enrollment

## Course setup

Create a draft with a name, optional category, description and fee. Course codes
are generated once per form unless an optional code is supplied. Advanced
settings contain delivery mode, duration, certificates and featured ordering.

Creation saves only the course and opens its detail page. Add subjects, chapters,
lessons and materials after saving; a content failure no longer repeats course
creation. Preview the saved course before publishing.

Publishing updates both is_published and the existing is_purchasable_online
catalogue flag in one PATCH. The backend still requires those flags plus an active
course and academy for Explore visibility. The legacy flag does not authorize a
student to purchase or enroll. Unpublishing clears both visibility flags.

## Enrollment

Student journey: Register → Sign in → Explore → Course details → Contact academy
for UPI details → Firm Admin verifies payment and creates enrollment → My Courses
→ Course content.

There is no student Enroll action, enrollment-request list or automatic free-course
enrollment. UPI details are supplied by the academy; this change does not invent a
UPI ID, collect payment or mark a payment as verified.

The student enrollment POST endpoint now returns HTTP 403 without writing to the
database. This also prevents older self-enrollment APKs from creating records.
The local student request repository refuses submission without an HTTP call.
Existing enrollment records and chapter-only grants are preserved.

GET enrollment status endpoints remain read-only for compatibility. My Courses
uses the existing course-access API and shows content only after admin access
is granted. Students can refresh to see newly granted access.

## Validation and deployment

Run Flutter checks with flutter test and flutter analyze.

Backend enrollment tests use isolated in-memory SQLite settings, with no
production .env or database connection. From backend:

```powershell
..\frontend\.enrollment-test-venv\Scripts\python.exe -m django test students.test_enrollment --settings=students.enrollment_test_settings --noinput
```

Deploy the backend enrollment restriction before distributing the updated APK.
No database migration is required. Smoke-test course drafting, content setup,
preview/publish, UPI verification by the academy, admin enrollment and student
access in staging before production release.

No production deployment is performed by these source changes.
