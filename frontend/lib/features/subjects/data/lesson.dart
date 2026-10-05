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
    Map<String, dynamic> data = json;
    if (json['data'] is Map<String, dynamic>) {
      data = json['data'] as Map<String, dynamic>;
    } else if (json['data'] is Map) {
      data = Map<String, dynamic>.from(json['data'] as Map);
    }

    List<dynamic> list = [];
    if (data['results'] is List) {
      list = data['results'] as List<dynamic>;
    } else if (json['results'] is List) {
      list = json['results'] as List<dynamic>;
    } else if (json['data'] is List) {
      list = json['data'] as List<dynamic>;
    }

    final count = (data['count'] as num?)?.toInt() ??
        (json['count'] as num?)?.toInt() ??
        list.length;

    return LessonPage(
      count: count,
      results: list
          .map(
            (item) => Lesson.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}
