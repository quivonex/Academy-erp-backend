class Student {
  const Student({
    this.id = 0,
    required this.uuid,
    required this.admissionNumber,
    required this.firstName,
    required this.lastName,
    required this.isActive,
    this.email = '',
    this.phone = '',
    this.gender = '',
    this.address = '',
    this.firmName,
    this.dateOfBirth,
    this.joinedDate,
  });

  final int id;
  final String uuid;
  final String admissionNumber;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String gender;
  final String address;
  final String? firmName;
  final String? dateOfBirth;
  final String? joinedDate;
  final bool isActive;
  String get fullName => '$firstName $lastName'.trim();

  factory Student.fromJson(Map<String, dynamic> json) => Student(
    id: (json['id'] as num?)?.toInt() ?? int.tryParse(json['uuid']?.toString() ?? '') ?? 0,
    uuid: json['uuid']?.toString() ?? json['id']?.toString() ?? '',
    admissionNumber: json['admission_number']?.toString() ?? '',
    firstName: json['first_name']?.toString() ?? '',
    lastName: json['last_name']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    phone: json['phone']?.toString() ?? '',
    gender: json['gender']?.toString() ?? '',
    address: json['address']?.toString() ?? '',
    firmName: json['firm_name']?.toString(),
    dateOfBirth: json['date_of_birth']?.toString(),
    joinedDate: json['joined_date']?.toString(),
    isActive: json['is_active'] == true,
  );
}

class StudentPage {
  const StudentPage({required this.results, required this.count});
  final List<Student> results;
  final int count;

  factory StudentPage.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final raw = data['results'] as List<dynamic>? ?? [];
    return StudentPage(
      count: data['count'] as int? ?? raw.length,
      results: raw.map((item) => Student.fromJson(Map<String, dynamic>.from(item as Map))).toList(),
    );
  }
}
