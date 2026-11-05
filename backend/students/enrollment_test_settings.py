"""Isolated SQLite settings for enrollment API tests; never loads production .env."""
SECRET_KEY = "enrollment-tests-only"
DEBUG = False
ALLOWED_HOSTS = ["testserver"]
INSTALLED_APPS = [
    "django.contrib.auth", "django.contrib.contenttypes",
    "rest_framework", "firms", "accounts", "students", "teachers", "courses",
]
DATABASES = {"default": {"ENGINE": "django.db.backends.sqlite3", "NAME": ":memory:"}}
AUTH_USER_MODEL = "accounts.User"
ROOT_URLCONF = "students.test_enrollment"
MIDDLEWARE = []
USE_TZ = True
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": ["rest_framework.authentication.BasicAuthentication"],
}
