class AdminCourseCategory {
  const AdminCourseCategory({
    required this.uuid,
    required this.name,
    required this.description,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  final String uuid;
  final String name;
  final String description;
  final bool isActive;

  final String? createdAt;
  final String? updatedAt;

  factory AdminCourseCategory.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminCourseCategory(
      uuid: json['uuid']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      isActive: json['is_active'] == true,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}

class AdminCourseCategoryPage {
  const AdminCourseCategoryPage({
    required this.count,
    required this.results,
  });

  final int count;
  final List<AdminCourseCategory> results;

  factory AdminCourseCategoryPage.fromJson(
    Map<String, dynamic> json,
  ) {
    Map<String, dynamic> data = json;

    if (json['data'] is Map) {
      data = Map<String, dynamic>.from(
        json['data'] as Map,
      );
    }

    final raw = data['results'] as List<dynamic>? ?? [];

    return AdminCourseCategoryPage(
      count: data['count'] as int? ?? raw.length,
      results: raw
          .map(
            (item) => AdminCourseCategory.fromJson(
              Map<String, dynamic>.from(
                item as Map,
              ),
            ),
          )
          .toList(),
    );
  }
}
