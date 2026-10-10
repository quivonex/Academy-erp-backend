class Course {
  const Course({
    required this.uuid,
    required this.name,
    required this.code,
    required this.price,
    required this.deliveryMode,
    required this.isActive,
    required this.isPublished,
    required this.isPurchasableOnline,
    required this.isFeatured,
    this.isCertificateEnabled = false,
    this.certificateRequiredWatchPercentage = 100,
    required this.featuredOrder,
    this.description = '',
    this.categoryName,
    this.durationMonths,
    this.accessDurationDays,
  });

  final String uuid;
  final String name;
  final String code;
  final String description;
  final String price;
  final String deliveryMode;

  final bool isActive;
  final bool isPublished;
  final bool isPurchasableOnline;
  final bool isFeatured;
  final bool isCertificateEnabled;
  final double certificateRequiredWatchPercentage;

  final int featuredOrder;

  final String? categoryName;
  final int? durationMonths;
  final int? accessDurationDays;

  factory Course.fromJson(
    Map<String, dynamic> json,
  ) {
    final category = json['category'];

    return Course(
      uuid: json['uuid']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: json['price']?.toString() ?? '0.00',
      deliveryMode: json['delivery_mode']?.toString() ?? 'ONLINE',
      isActive: json['is_active'] == true,
      isPublished: json['is_published'] == true,
      isPurchasableOnline: json['is_purchasable_online'] == true,
      isFeatured: json['is_featured'] == true,
      isCertificateEnabled: json['is_certificate_enabled'] == true,
      certificateRequiredWatchPercentage: double.tryParse(
            json['certificate_required_watch_percentage']?.toString() ?? '100',
          ) ??
          100,
      featuredOrder: int.tryParse(
            json['featured_order']?.toString() ?? '0',
          ) ??
          0,
      categoryName: category is Map ? category['name']?.toString() : null,
      durationMonths: json['duration_months'] is int
          ? json['duration_months'] as int
          : int.tryParse(
              json['duration_months']?.toString() ?? '',
            ),
      accessDurationDays: json['access_duration_days'] is int
          ? json['access_duration_days'] as int
          : int.tryParse(
              json['access_duration_days']?.toString() ?? '',
            ),
    );
  }
}

class CoursePage {
  const CoursePage({required this.results, required this.count});
  final List<Course> results;
  final int count;

  factory CoursePage.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> data = json;
    if (json['data'] is Map<String, dynamic>) {
      data = json['data'] as Map<String, dynamic>;
    }

    List<dynamic> raw = [];
    if (data['results'] is List) {
      raw = data['results'] as List<dynamic>;
    } else if (json['results'] is List) {
      raw = json['results'] as List<dynamic>;
    } else if (json['data'] is List) {
      raw = json['data'] as List<dynamic>;
    }

    final count = data['count'] as int? ?? json['count'] as int? ?? raw.length;

    return CoursePage(
      count: count,
      results: raw
          .map((entry) => Course.fromJson(Map<String, dynamic>.from(entry as Map)))
          .toList(),
    );
  }
}
