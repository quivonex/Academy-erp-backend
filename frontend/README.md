# Academy ERP admin Flutter project

This is the user's full Flutter project with the existing Firms and Firm Admin screens preserved. The connected backend is the Django API at `/api/v1/`.

## Working API routes wired in the UI

- `POST /auth/login/`: reads `data.user` and `data.tokens`.
- `GET /auth/me/`: restores account and role from the server.
- `POST /auth/refresh/`: reads the standard SimpleJWT response (`access`; optional rotated `refresh`).
- `POST /auth/logout/`: sends the stored `refresh` token with Bearer access; clears local tokens after a successful response. If the access token has expired, the client refreshes once and retries logout.
- Firms: `GET/POST /firms/`, `GET/PATCH /firms/{uuid}/`, `PATCH /firms/{uuid}/activate/` and `/deactivate/`.
- Firm Admins: `GET /firms/firm-admins/`, `GET /firms/{uuid}/admins/`, `POST /firms/{uuid}/admins/create/`.
- Super Admin dashboard counts firms from `GET /firms/`; Firm Admin sees their own academy from login `/auth/me/`.

Firm Admin now has Students and Courses screens backed by the Django API:

- Students list/search/page: `GET /students/?search=&page=&page_size=20` (`data.results`).
- Add, view, activate/deactivate students: `POST /students/`, `GET /students/{uuid}/`, `PATCH /students/{uuid}/activate/` or `/deactivate/`.
- Enable student login: `POST /students/{uuid}/enable-login/` with email and confirmed password.
- Courses list/search/page: `GET /courses/?search=&page=&page_size=20` (`data.results`).
- Add, view, publish/unpublish courses: `POST /courses/`, `GET /courses/{uuid}/`, `PATCH /courses/{uuid}/`.

Super Admin cannot access those firm scoped routes in the current Django permissions, so the menus show only for Firm Admin. The older `lib/features/academies`, `enrollment`, and `attendance` source remains for later work; it targets another API and is not linked in navigation. No DELETE firm action is offered because the Django API does not provide it.

The current backend logout blacklists the refresh token sent in the request; it does not revoke every other device or immediately reject already-issued access tokens. That behavior requires a backend change.

## Android Studio setup

Open the `edusphere_admin_flutter` folder, run `flutter pub get`, and run the app. The default API URL is `http://192.168.31.86:8000/api/v1` as supplied. The phone and Django computer must be on the same reachable network. You can override it, for example for an Android emulator with a local Django server:

```bash
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

Start Django locally with `python manage.py runserver 0.0.0.0:8000`. The debug Android manifest allows local HTTP; use HTTPS for production. Run `flutter analyze` in Android Studio before shipping.

The workspace used to prepare this ZIP does not have the Flutter SDK or a running Django server, so an Android build and live API calls were not executed here.
