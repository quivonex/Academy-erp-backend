/// Mirrors app.schemas.academy.AcademyOut on the backend.
class Academy {
  const Academy({
    required this.id,
    required this.name,
    required this.code,
    this.city,
    this.address,
    this.logoUrl,
    required this.status,
  });

  final int id;
  final String name;
  final String code;
  final String? city;
  final String? address;
  final String? logoUrl;
  final String status; // active | suspended | onboarding

  factory Academy.fromJson(Map<String, dynamic> json) {
    return Academy(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String,
      city: json['city'] as String?,
      address: json['address'] as String?,
      logoUrl: json['logo_url'] as String?,
      status: json['status'] as String,
    );
  }
}

class AcademyCreateRequest {
  const AcademyCreateRequest({required this.name, required this.code, this.city, this.address});

  final String name;
  final String code;
  final String? city;
  final String? address;

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': code,
        if (city != null) 'city': city,
        if (address != null) 'address': address,
      };
}
