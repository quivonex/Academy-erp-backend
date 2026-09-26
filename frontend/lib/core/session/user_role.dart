/// Mirrors app.models.enums.UserRole in the backend.
///
/// The backend currently emits UPPERCASE with underscores — e.g.
/// `SUPER_ADMIN`, `FIRM_ADMIN` — while an older seed used lowercase.
/// `fromApi` normalizes the casing so both forms keep working.
enum UserRole {
  superAdmin('SUPER_ADMIN'),
  academyAdmin('FIRM_ADMIN'),
  teacher('TEACHER'),
  student('STUDENT'),
  firmStaff('FIRM_STAFF');

  const UserRole(this.apiValue);
  final String apiValue;

  /// Case-insensitive lookup. Accepts `SUPER_ADMIN`, `super_admin`, etc.
  static UserRole fromApi(String value) {
    final normalized = value.trim().toUpperCase();
    return UserRole.values.firstWhere(
          (r) => r.apiValue == normalized,
      orElse: () => throw ArgumentError('Unknown role: $value'),
    );
  }

  /// Whether this role uses the Enterprise ERP shell (vs. Faculty Workspace).
  bool get isEnterpriseShell =>
      this == UserRole.superAdmin || this == UserRole.academyAdmin;

  bool get isFacultyShell => this == UserRole.teacher;
}