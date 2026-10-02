class HomeBanner {
  const HomeBanner({
    required this.uuid,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.actionLabel,
    required this.actionUrl,
    required this.displayOrder,
    required this.isActive,
    this.courseName,
    this.startsAt,
    this.endsAt,
  });

  final String uuid;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String actionLabel;
  final String actionUrl;

  final String? courseName;

  final int displayOrder;

  final DateTime? startsAt;
  final DateTime? endsAt;

  final bool isActive;

  factory HomeBanner.fromJson(
    Map<String, dynamic> json,
  ) {
    return HomeBanner(
      uuid: json['uuid']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      actionLabel: json['action_label']?.toString() ?? '',
      actionUrl: json['action_url']?.toString() ?? '',
      courseName: json['course_name']?.toString(),
      displayOrder: int.tryParse(
            json['display_order']?.toString() ?? '0',
          ) ??
          0,
      startsAt: json['starts_at'] != null
          ? DateTime.tryParse(
              json['starts_at'].toString(),
            )
          : null,
      endsAt: json['ends_at'] != null
          ? DateTime.tryParse(
              json['ends_at'].toString(),
            )
          : null,
      isActive: json['is_active'] == true,
    );
  }
}

class HomeBannerPage {
  const HomeBannerPage({
    required this.count,
    required this.results,
  });

  final int count;
  final List<HomeBanner> results;

  factory HomeBannerPage.fromJson(
    Map<String, dynamic> json,
  ) {
    Map<String, dynamic> data = json;

    if (json['data'] is Map<String, dynamic>) {
      data = json['data'] as Map<String, dynamic>;
    }

    final raw = data['results'] as List<dynamic>? ?? [];

    return HomeBannerPage(
      count: data['count'] as int? ?? raw.length,
      results: raw
          .map(
            (item) => HomeBanner.fromJson(
              Map<String, dynamic>.from(
                item as Map,
              ),
            ),
          )
          .toList(),
    );
  }
}

typedef BannerItem = HomeBanner;
typedef BannerPage = HomeBannerPage;
