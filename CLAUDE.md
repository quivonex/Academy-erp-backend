#Rolex Academy ERP — Backend

## Project Overview
Multi-tenant coaching academy SaaS. Django 5.2 + DRF + MySQL + Redis + Celery + S3.

## Quick Start
```bash
cd backend
pip install -r ../requirements.txt
python manage.py runserver
```

## Architecture Rules
- **Multi-tenant**: Every queryset MUST filter by `request.user.firm`. Never return cross-firm data.
- **Auth**: JWT via SimpleJWT with `auth_version` — incrementing it invalidates all existing tokens.
- **User types**: SUPER_ADMIN, FIRM_ADMIN, FIRM_STAFF, TEACHER, STUDENT. Use permission classes from `common/permissions.py`.
- **UUIDs**: All models expose `uuid` for external APIs. Never expose integer PKs in URLs or responses.
- **File storage**: Use `file_key` (S3 key) fields, not Django FileField. Presigned URLs generated in views.

## Code Conventions
- **Service layer**: Business logic lives in `services.py`, not in views or serializers.
- **Views**: DRF ViewSets and APIViews. Keep views thin — validate, call service, return response.
- **Serializers**: Validation only. No side effects.
- **URLs**: Versioned at `/api/v1/`. Student portal at `/api/v1/student/`. Public at `/api/v1/public/`.
- **DB tables**: Explicit `db_table` in every Meta. Snake_case table names.
- **Firm scoping**: Services accept `firm` as first parameter. Views pass `request.user.firm`.

## Module Development Sessions
This project uses separate Claude Code sessions per module. Read the development plan from memory before starting work. Each session should:
1. Focus on ONE module only
2. Run tests before and after changes
3. Commit with module-tagged messages (e.g., `[accounts] Add JWT auth tests`)

## Dependencies
- Python 3.11, Django 5.2, MySQL, Redis
- See requirements.txt for full list
