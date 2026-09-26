/// A firm-admin user as returned by every admins endpoint.
class FirmAdmin {
  const FirmAdmin({
    required this.uuid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    this.phone,
    required this.userType, // always 'FIRM_ADMIN'
    required this.firmUuid,
    required this.firmName,
    required this.isActive,
    required this.dateJoined,
  });

  final String uuid;
  final String email;
  final String firstName;
  final String lastName;
  final String fullName;
  final String? phone;
  final String userType;
  final String firmUuid;
  final String firmName;
  final bool isActive;
  final DateTime dateJoined;

  factory FirmAdmin.fromJson(Map<String, dynamic> json) {
    return FirmAdmin(
      uuid: json['uuid'] as String,
      email: json['email'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String?,
      userType: json['user_type'] as String? ?? 'FIRM_ADMIN',
      firmUuid: json['firm_uuid'] as String,
      firmName: json['firm_name'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      dateJoined: DateTime.parse(json['date_joined'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'email': email,
    'first_name': firstName,
    'last_name': lastName,
    'full_name': fullName,
    'phone': phone,
    'user_type': userType,
    'firm_uuid': firmUuid,
    'firm_name': firmName,
    'is_active': isActive,
    'date_joined': dateJoined.toIso8601String(),
  };
}

/// Request DTO for POST /firms/{uuid}/admins/create/
class FirmAdminCreateRequest {
  const FirmAdminCreateRequest({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.password,
    required this.confirmPassword,
    this.phone,
  });

  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String password;
  final String confirmPassword;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'password': password,
      'confirm_password': confirmPassword,
    };
    if (phone != null && phone!.isNotEmpty) map['phone'] = phone;
    return map;
  }
}

/// Envelope for GET /firms/{uuid}/admins/ and /firms/firm-admins/
class FirmAdminsListResponse {
  const FirmAdminsListResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  final bool success;
  final String message;
  final List<FirmAdmin> data;

  factory FirmAdminsListResponse.fromJson(Map<String, dynamic> json) {
    return FirmAdminsListResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: (json['data'] as List<dynamic>? ?? [])
          .map((e) => FirmAdmin.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Envelope for POST /firms/{uuid}/admins/create/
class FirmAdminDetailResponse {
  const FirmAdminDetailResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  final bool success;
  final String message;
  final FirmAdmin data;

  factory FirmAdminDetailResponse.fromJson(Map<String, dynamic> json) {
    return FirmAdminDetailResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: FirmAdmin.fromJson(json['data'] as Map<String, dynamic>),
    );
  }
}