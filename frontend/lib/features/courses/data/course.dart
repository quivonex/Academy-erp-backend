class Course {
  const Course({required this.uuid, required this.name, required this.code,
    required this.price, required this.deliveryMode, required this.isActive,
    required this.isPublished, required this.isPurchasableOnline,
    this.description = '', this.categoryName, this.durationMonths, this.accessDurationDays});

  final String uuid;
  final String name;
  final String code;
  final String description;
  final String price;
  final String deliveryMode;
  final bool isActive;
  final bool isPublished;
  final bool isPurchasableOnline;
  final String? categoryName;
  final int? durationMonths;
  final int? accessDurationDays;

  factory Course.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    return Course(
      uuid: json['uuid'].toString(), name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: json['price']?.toString() ?? '0.00',
      deliveryMode: json['delivery_mode']?.toString() ?? 'ONLINE',
      isActive: json['is_active'] == true,
      isPublished: json['is_published'] == true,
      isPurchasableOnline: json['is_purchasable_online'] == true,
      categoryName: category is Map ? category['name']?.toString() : null,
      durationMonths: json['duration_months'] as int?,
      accessDurationDays: json['access_duration_days'] as int?,
    );
  }
}

class CoursePage {
  const CoursePage({required this.results, required this.count});
  final List<Course> results;
  final int count;
  factory CoursePage.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final raw = data['results'] as List<dynamic>? ?? [];
    return CoursePage(count: data['count'] as int? ?? raw.length,
      results: raw.map((entry) => Course.fromJson(Map<String, dynamic>.from(entry as Map))).toList());
  }
}
