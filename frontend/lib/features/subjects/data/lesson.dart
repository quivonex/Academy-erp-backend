class Lesson {
  const Lesson({
    required this.uuid,
    required this.chapterTitle,
    required this.title,
    required this.description,
    required this.sequence,
    required this.isActive,
  });

  final String uuid;
  final String chapterTitle;
  final String title;
  final String description;
  final int sequence;
  final bool isActive;

  factory Lesson.fromJson(
    Map<String, dynamic> json,
  ) {
    return Lesson(
      uuid: json['uuid']?.toString() ?? '',
      chapterTitle: json['chapter_title']?.toString() ?? '',
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

class LessonPage {
  const LessonPage({
    required this.count,
    required this.results,
  });

  final int count;
  final List<Lesson> results;

  factory LessonPage.fromJson(
    Map<String, dynamic> json,
  ) {
    final list = json['results'] as List<dynamic>? ?? [];

    return LessonPage(
      count: json['count'] as int? ?? list.length,
      results: list
          .map(
            (item) => Lesson.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
    );
  }
}
