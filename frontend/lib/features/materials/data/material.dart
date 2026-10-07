class LearningMaterial {
  const LearningMaterial({
    required this.uuid,
    required this.courseName,
    required this.title,
    required this.description,
    required this.materialType,
    required this.source,
    required this.fileKey,
    required this.externalUrl,
    required this.sequence,
    required this.isRequired,
    required this.countsTowardProgress,
    required this.isActive,
    this.subjectName,
    this.chapterTitle,
    this.lessonTitle,
    this.durationSeconds,
    this.availableFrom,
    this.availableUntil,
  });

  final String uuid;

  final String courseName;
  final String? subjectName;
  final String? chapterTitle;
  final String? lessonTitle;

  final String title;
  final String description;

  final String materialType;
  final String source;

  final String fileKey;
  final String externalUrl;

  final int? durationSeconds;
  final int sequence;

  final DateTime? availableFrom;
  final DateTime? availableUntil;

  final bool isRequired;
  final bool countsTowardProgress;
  final bool isActive;

  factory LearningMaterial.fromJson(
    Map<String, dynamic> json,
  ) {
    final course = json['course'];
    final courseName = json['course_name']?.toString() ??
        (course is Map ? course['name']?.toString() : null) ??
        '';

    final subject = json['subject'];
    final subjectName = json['subject_name']?.toString() ??
        (subject is Map ? subject['name']?.toString() : null);

    final chapter = json['chapter'];
    final chapterTitle = json['chapter_title']?.toString() ??
        (chapter is Map ? chapter['title']?.toString() : null);

    final lesson = json['lesson'];
    final lessonTitle = json['lesson_title']?.toString() ??
        (lesson is Map ? lesson['title']?.toString() : null);

    return LearningMaterial(
      uuid: json['uuid']?.toString() ?? '',
      courseName: courseName,
      subjectName: subjectName,
      chapterTitle: chapterTitle,
      lessonTitle: lessonTitle,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      materialType: json['material_type']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      fileKey: json['file_key']?.toString() ?? '',
      externalUrl: json['external_url']?.toString() ?? '',
      durationSeconds: int.tryParse(
        json['duration_seconds']?.toString() ?? '',
      ),
      sequence: int.tryParse(
            json['sequence']?.toString() ?? '1',
          ) ??
          1,
      availableFrom: _parseDate(
        json['available_from'],
      ),
      availableUntil: _parseDate(
        json['available_until'],
      ),
      isRequired: json['is_required'] as bool? ?? true,
      countsTowardProgress: json['counts_toward_progress'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class LearningMaterialPage {
  const LearningMaterialPage({
    required this.count,
    required this.results,
  });

  final int count;

  final List<LearningMaterial> results;

  factory LearningMaterialPage.fromJson(
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

    return LearningMaterialPage(
      count: count,
      results: list
          .map(
            (item) => LearningMaterial.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) {
    return null;
  }

  return DateTime.tryParse(
    value.toString(),
  );
}
