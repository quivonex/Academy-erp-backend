class LoginRequest {
  const LoginRequest({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
  };
}

class LoginResponse {
  const LoginResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  final bool success;
  final String message;
  final LoginData data;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: LoginData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }
}

class LoginData {
  const LoginData({
    required this.user,
    required this.tokens,
  });

  final AuthUser user;
  final AuthTokens tokens;

  factory LoginData.fromJson(Map<String, dynamic> json) {
    return LoginData(
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      tokens: AuthTokens.fromJson(json['tokens'] as Map<String, dynamic>),
    );
  }
}

class AuthUser {
  const AuthUser({
    required this.uuid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.phone,
    required this.userType,
    this.firmUuid,
    this.firmName,
    required this.isActive,
    required this.dateJoined,
  });

  final String uuid;
  final String email;
  final String firstName;
  final String lastName;
  final String fullName;
  final String phone;
  final String userType;
  final String? firmUuid;
  final String? firmName;
  final bool isActive;
  final DateTime dateJoined;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      uuid: json['uuid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      userType: json['user_type'] as String? ?? '',
      firmUuid: json['firm_uuid'] as String?,
      firmName: json['firm_name'] as String?,
      isActive: json['is_active'] as bool? ?? false,
      dateJoined: DateTime.tryParse(json['date_joined'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class AuthTokens {
  const AuthTokens({
    required this.access,
    required this.refresh,
  });

  final String access;
  final String refresh;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      access: json['access'] as String? ?? '',
      refresh: json['refresh'] as String? ?? '',
    );
  }
}