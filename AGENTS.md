# Academy ERP development continuity

Before changing a module, read `docs/DEVELOPMENT_CHECKPOINT.md` and the relevant
section of `docs/CLIENT_MODULE_API_GUIDE.md`. Compare changes since the recorded
base; inspect the affected modules rather than repeating an unrelated full audit.

Keep module state, API changes, migrations, test results and remaining work updated
in the checkpoint whenever implementation changes. Record integration history in
the associated pull request. Never mark a database migration or deployment complete
unless it has actually been run in that environment.

For backend client-module regressions, run from `backend/`:

```bash
python manage.py test academy_ops students.test_enrollment --settings=academy_ops.test_settings --noinput
python manage.py makemigrations --check --dry-run --settings=academy_ops.test_settings
```

The test settings are isolated SQLite settings and must not be used on a server.
Preserve unrelated work. Source comments must be in English.
