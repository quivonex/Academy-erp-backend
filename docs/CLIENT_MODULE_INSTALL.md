# Install backend module update

Base commit: `9e4dca2165476e4f24f61c437c49cc0591f887c1` from quivonex/Academy-erp-backend.

The ZIP contains only changed/new backend files and documentation, plus MCQ template samples. Frontend code is not included.

1. Commit or back up current local work. Compare the supplied files if your branch has advanced or contains unpushed changes, especially config/settings.py and config/urls.py. The patch in this package is an alternative to copying full files; do not apply both.
2. Copy the included backend and docs paths into matching project paths. Do not overwrite `.env` or database settings with test settings. No environment files or secrets are included.
3. Activate your existing Python virtual environment and go to backend/.
4. Install the additional spreadsheet dependency:

   ```bash
   python -m pip install -r requirements-client-modules.txt
   ```

5. Run isolated regression tests (does not contact the live database):

   ```bash
   python manage.py test academy_ops students.test_enrollment --settings=academy_ops.test_settings --noinput
   ```

6. Check and inspect the migration using your normal development settings:

   ```bash
   python manage.py check
   python manage.py migrate --plan
   python manage.py migrate
   ```

7. Start the backend on the test server and test JWT requests with a Firm Admin and a Student. Use docs/CLIENT_MODULE_API_GUIDE.md and the included Postman collection.
8. Hand the API guide and docs/DEVELOPMENT_CHECKPOINT.md to the frontend developer. Materials menu placement remains their responsibility.

The production MySQL database and deployed services were not changed by preparing this update.
SQLite tests validate migrations and API behaviour, but cannot prove MySQL row-lock behaviour under concurrent traffic.
