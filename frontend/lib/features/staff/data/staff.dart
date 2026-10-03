class Staff {
  const Staff({
    required this.uuid,
    required this.employeeId,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.designation,
    required this.department,
    required this.isActive,
    this.firmUuid,
    this.firmName,
    this.address = '',
    this.joinedDate,
    this.createdAt,
    this.updatedAt,
  });

  final String uuid;
  final String? firmUuid;
  final String? firmName;

  final String employeeId;
  final String firstName;
  final String lastName;
  final String fullName;

  final String email;
  final String phone;

  final String designation;
  final String department;

  final String address;
  final String? joinedDate;

  final bool isActive;

  final String? createdAt;
  final String? updatedAt;

  factory Staff.fromJson(
    Map<String, dynamic> json,
  ) {
    return Staff(
      uuid: json['uuid']?.toString() ?? '',
      firmUuid: json['firm_uuid']?.toString(),
      firmName: json['firm_name']?.toString(),
      employeeId: json['employee_id']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      joinedDate: json['joined_date']?.toString(),
      isActive: json['is_active'] == true,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}

class StaffPage {
  const StaffPage({
    required this.results,
    required this.count,
  });

  final List<Staff> results;
  final int count;

  factory StaffPage.fromJson(
    Map<String, dynamic> json,
  ) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(
            json['data'] as Map,
          )
        : json;

    final raw = data['results'] as List<dynamic>? ?? [];

    return StaffPage(
      count: data['count'] as int? ?? raw.length,
      results: raw
          .map(
            (item) => Staff.fromJson(
              Map<String, dynamic>.from(
                item as Map,
              ),
            ),
          )
          .toList(),
    );
  }
}
