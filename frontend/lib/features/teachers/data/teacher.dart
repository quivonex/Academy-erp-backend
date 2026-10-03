class Teacher {
  const Teacher({
    required this.uuid,
    required this.employeeId,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.specialization,
    required this.experienceYears,
    required this.isActive,
    this.gender,
    this.qualification,
    this.address,
    this.joinedDate,
    this.firmName,
  });

  final String uuid;
  final String employeeId;
  final String firstName;
  final String lastName;
  final String fullName;
  final String email;
  final String phone;
  final String specialization;
  final int experienceYears;
  final bool isActive;
  final String? gender;
  final String? qualification;
  final String? address;
  final String? joinedDate;
  final String? firmName;

  factory Teacher.fromJson(Map<String, dynamic> json) {
    final fn = json['first_name']?.toString() ?? '';
    final ln = json['last_name']?.toString() ?? '';
    final full = json['full_name']?.toString() ?? '';
    final computedFull = full.isNotEmpty ? full : '$fn $ln'.trim();

    return Teacher(
      uuid: json['uuid']?.toString() ?? json['id']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      firstName: fn,
      lastName: ln,
      fullName: computedFull.isNotEmpty ? computedFull : 'Teacher',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      specialization: json['specialization']?.toString() ?? '',
      experienceYears: int.tryParse(json['experience_years']?.toString() ?? '0') ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      gender: json['gender']?.toString(),
      qualification: json['qualification']?.toString(),
      address: json['address']?.toString(),
      joinedDate: json['joined_date']?.toString(),
      firmName: json['firm_name']?.toString(),
    );
  }
}

class TeacherPage {
  const TeacherPage({
    required this.count,
    required this.results,
  });

  final int count;
  final List<Teacher> results;

  factory TeacherPage.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> data = json;
    if (json['data'] is Map<String, dynamic>) {
      data = json['data'] as Map<String, dynamic>;
    }

    List<dynamic> list = [];
    if (data['results'] is List) {
      list = data['results'] as List<dynamic>;
    } else if (json['results'] is List) {
      list = json['results'] as List<dynamic>;
    } else if (json['data'] is List) {
      list = json['data'] as List<dynamic>;
    }

    final count = data['count'] as int? ?? json['count'] as int? ?? list.length;

    return TeacherPage(
      count: count,
      results: list
          .map((item) => Teacher.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}
