/// Domain model mirroring the `firm` object returned by GET/POST /firms/.
class Firm {
  const Firm({
    required this.uuid,
    required this.name,
    required this.code,
    this.email,
    this.phone,
    this.address,
    this.logo,
    required this.status,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  final String uuid;
  final String name;
  final String code;
  final String? email;
  final String? phone;
  final String? address;
  final String? logo; // URL or null
  final String status; // ACTIVE | INACTIVE | SUSPENDED
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory Firm.fromJson(Map<String, dynamic> json) {
    return Firm(
      uuid: json['uuid'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      logo: json['logo'] as String?,
      status: json['status'] as String? ?? 'INACTIVE',
      isActive: json['is_active'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'name': name,
    'code': code,
    'email': email,
    'phone': phone,
    'address': address,
    'logo': logo,
    'status': status,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}

/// Request DTO for POST /firms/  (create).
class FirmCreateRequest {
  const FirmCreateRequest({
    required this.name,
    required this.code,
    this.email,
    this.phone,
    this.address,
    this.status = 'ACTIVE',
    this.isActive = true,
  });

  final String name;
  final String code;
  final String? email;
  final String? phone;
  final String? address;
  final String status;
  final bool isActive;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'code': code,
      'status': status,
      'is_active': isActive,
    };
    if (email != null && email!.isNotEmpty) map['email'] = email;
    if (phone != null && phone!.isNotEmpty) map['phone'] = phone;
    if (address != null && address!.isNotEmpty) map['address'] = address;
    return map;
  }
}

/// Envelope returned by list endpoints (GET /firms/).
class FirmsListResponse {
  const FirmsListResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  final bool success;
  final String message;
  final List<Firm> data;

  factory FirmsListResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return FirmsListResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: rawData is List
          ? rawData
          .whereType<Map<String, dynamic>>()
          .map(Firm.fromJson)
          .toList()
          : const [],
    );
  }
}

/// Envelope returned by single-firm endpoints
/// (GET /firms/{uuid}/, POST /firms/, PATCH /firms/{uuid}/).
class FirmDetailResponse {
  const FirmDetailResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  final bool success;
  final String message;
  final Firm data;

  factory FirmDetailResponse.fromJson(Map<String, dynamic> json) {
    final dataRaw = json['data'];
    if (dataRaw is! Map<String, dynamic>) {
      throw FormatException(
        'Expected "data" to be a Map, got ${dataRaw.runtimeType}',
      );
    }
    return FirmDetailResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: Firm.fromJson(dataRaw),
    );
  }
}

/// Request DTO for PATCH /firms/{uuid}/ — partial update.
/// Only non-null fields are serialized, so you can PATCH one field.
class FirmUpdateRequest {
  const FirmUpdateRequest({
    this.name,
    this.code,
    this.email,
    this.phone,
    this.address,
    this.logo,
    this.status,
    this.isActive,
  });

  final String? name;
  final String? code;
  final String? email;
  final String? phone;
  final String? address;
  final String? logo;
  final String? status;
  final bool? isActive;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (code != null) map['code'] = code;
    if (email != null) map['email'] = email;
    if (phone != null) map['phone'] = phone;
    if (address != null) map['address'] = address;
    if (logo != null) map['logo'] = logo;
    if (status != null) map['status'] = status;
    if (isActive != null) map['is_active'] = isActive;
    return map;
  }
}

/// Response envelope for PATCH /firms/{uuid}/activate/ and
/// /deactivate/ — the body shape differs per endpoint, so we only
/// capture the fields every response is guaranteed to share.
class FirmStatusResponse {
  const FirmStatusResponse({
    required this.success,
    required this.message,
    required this.isActive,
    this.firm,
  });

  final bool success;
  final String message;
  final bool isActive;

  /// Populated when the endpoint returns a full firm (activate), null
  /// when the endpoint returns a partial stub (deactivate).
  final Firm? firm;

  factory FirmStatusResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final isActive = data['is_active'] as bool? ?? false;

    // Activate returns the full firm; deactivate returns a stub with
    // name == "" and no uuid. Only build a Firm when uuid is present.
    final hasUuid =
        data['uuid'] is String && (data['uuid'] as String).isNotEmpty;
    return FirmStatusResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      isActive: isActive,
      firm: hasUuid ? Firm.fromJson(data) : null,
    );
  }
}