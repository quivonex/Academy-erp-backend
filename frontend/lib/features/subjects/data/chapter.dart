class Chapter {
  const Chapter({
    required this.uuid,
    required this.subjectName,
    required this.title,
    required this.description,
    required this.sequence,
    required this.isActive,
  });

  final String uuid;
  final String subjectName;
  final String title;
  final String description;
  final int sequence;
  final bool isActive;

  factory Chapter.fromJson(
    Map<String, dynamic> json,
  ) {
    return Chapter(
      uuid: json['uuid']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      sequence: int.tryParse(
            json['sequence']?.toString() ?? '1',
          ) ??
          1,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class ChapterPage {
  const ChapterPage({
    required this.count,
    required this.results,
  });

  final int count;
  final List<Chapter> results;

  factory ChapterPage.fromJson(
    Map<String, dynamic> json,
  ) {
    final list = json['results'] as List<dynamic>? ?? [];

    return ChapterPage(
      count: json['count'] as int? ?? list.length,
      results: list
          .map(
            (item) => Chapter.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
    );
  }
}
