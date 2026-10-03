import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/admin_ui.dart';

import '../../courses/data/course.dart';
import '../../courses/data/course_repository.dart';

import '../../subjects/data/subject.dart';
import '../../subjects/data/subject_repository.dart';

import '../../subjects/data/chapter.dart';
import '../../subjects/data/chapter_repository.dart';

import '../../subjects/data/lesson.dart';
import '../../subjects/data/lesson_repository.dart';

import '../data/material.dart';
import '../data/material_repository.dart';

class MaterialsListScreen extends ConsumerStatefulWidget {
  const MaterialsListScreen({
    super.key,
  });

  @override
  ConsumerState<MaterialsListScreen> createState() =>
      _MaterialsListScreenState();
}

class _MaterialsListScreenState extends ConsumerState<MaterialsListScreen> {
  final searchController = TextEditingController();

  late Future<LearningMaterialPage> result;

  String search = '';

  String? typeFilter;

  int page = 1;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    result = ref.read(materialRepositoryProvider).list(
          page: page,
          search: search,
          materialType: typeFilter,
        );
  }

  void applySearch() {
    setState(() {
      search = searchController.text.trim();

      page = 1;

      reload();
    });
  }

  void refresh() {
    setState(reload);
  }

  @override
  void dispose() {
    searchController.dispose();

    super.dispose();
  }

  Future<void> _openCreate() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _CreateMaterialDialog(),
    );
    if (created == true && mounted) {
      setState(() {
        page = 1;
        reload();
      });
    }
  }

  void _setType(String? value) {
    setState(() {
      typeFilter = value;
      page = 1;
      reload();
    });
  }

  void _goToPage(int value) {
    setState(() {
      page = value;
      reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          eyebrow: const AdminEyebrow(
            section: 'Content library',
            detail: 'Videos, PDFs, documents & links',
          ),
          title: 'Learning materials',
          titleTrailing: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          actions: [
            GradientButton(
              label: 'Add material',
              icon: Icons.upload_file_rounded,
              onPressed: _openCreate,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: FutureBuilder<LearningMaterialPage>(
            future: result,
            builder: (context, snapshot) {
              final state = adminFutureState(
                snapshot,
                noun: 'materials',
                onRetry: refresh,
              );
              final data = snapshot.data;
              final rows = data?.results ?? const <LearningMaterial>[];
              int countOf(String type) => rows
                  .where((m) => m.materialType.toUpperCase() == type)
                  .length;

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  AdminKpiGrid(
                    children: [
                      AdminKpiCard(
                        label: 'Total materials',
                        value: data == null ? '…' : '${data.count}',
                        icon: Icons.folder_copy_outlined,
                      ),
                      AdminKpiCard(
                        label: 'Videos',
                        value: data == null ? '…' : '${countOf('VIDEO')}',
                        icon: Icons.smart_display_outlined,
                        iconBackground: const Color(0xFFFFF1F2),
                        iconForeground: const Color(0xFFE11D48),
                        caption: 'On this page',
                      ),
                      AdminKpiCard(
                        label: 'PDFs & documents',
                        value: data == null
                            ? '…'
                            : '${countOf('PDF') + countOf('DOCUMENT')}',
                        icon: Icons.picture_as_pdf_outlined,
                        iconBackground: const Color(0xFFF0F9FF),
                        iconForeground: const Color(0xFF0284C7),
                        caption: 'On this page',
                      ),
                      AdminKpiCard(
                        label: 'Links',
                        value: data == null ? '…' : '${countOf('LINK')}',
                        icon: Icons.link_rounded,
                        iconBackground: const Color(0xFFF5F3FF),
                        iconForeground: const Color(0xFF7C3AED),
                        caption: 'On this page',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AdminToolbar(
                    controller: searchController,
                    hint: 'Search materials…',
                    onSearch: applySearch,
                    filters: [
                      for (final entry in const [
                        ['ALL', null],
                        ['VIDEO', 'VIDEO'],
                        ['PDF', 'PDF'],
                        ['DOCUMENT', 'DOCUMENT'],
                        ['LINK', 'LINK'],
                      ])
                        CountFilterPill(
                          label: entry[0]!,
                          selected: typeFilter == entry[1],
                          onTap: () => _setType(entry[1]),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (state != null)
                    state
                  else if (rows.isEmpty)
                    AdminStateMessage(
                      icon: Icons.upload_file_rounded,
                      title: 'No materials found',
                      message: 'Upload a material or change the filters.',
                      actionLabel: 'Add material',
                      onAction: _openCreate,
                    )
                  else ...[
                    for (final material in rows)
                      AdminListRow(
                        title: material.title,
                        icon: _iconForType(material.materialType),
                        titleBadge: material.isRequired
                            ? const SoftBadge(
                                label: 'Required',
                                background: Color(0xFFFFF1F2),
                                foreground: Color(0xFFE11D48),
                              )
                            : null,
                        subtitle: material.description,
                        meta: [
                          SoftBadge(
                            label: material.materialType.toUpperCase(),
                            background: const Color(0xFFF1F5F9),
                            foreground: const Color(0xFF334155),
                          ),
                          MetaChip(
                            icon: Icons.auto_stories_outlined,
                            label: material.courseName,
                          ),
                          if ((material.subjectName ?? '').isNotEmpty)
                            MetaChip(
                              icon: Icons.menu_book_outlined,
                              label: material.subjectName!,
                            ),
                          if ((material.lessonTitle ?? '').isNotEmpty)
                            MetaChip(
                              icon: Icons.bookmark_outline_rounded,
                              label: material.lessonTitle!,
                            ),
                          MetaChip(
                            icon: Icons.cloud_outlined,
                            label: material.source,
                          ),
                        ],
                        trailing: [ActiveBadge(active: material.isActive)],
                        onTap: () async {
                          await context.push('/materials/${material.uuid}');
                          if (mounted) refresh();
                        },
                      ),
                    if (data!.count > rows.length || page > 1)
                      AdminPager(
                        page: page,
                        pageSize: 20,
                        total: data.count,
                        noun: 'materials',
                        onPage: _goToPage,
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CreateMaterialDialog extends ConsumerStatefulWidget {
  const _CreateMaterialDialog();

  @override
  ConsumerState<_CreateMaterialDialog> createState() =>
      _CreateMaterialDialogState();
}

class _CreateMaterialDialogState extends ConsumerState<_CreateMaterialDialog> {
  final title = TextEditingController();

  final description = TextEditingController();

  final courseSearch = TextEditingController();

  final externalUrl = TextEditingController();

  final duration = TextEditingController();

  final sequence = TextEditingController(
    text: '1',
  );

  List<Course> courses = [];

  Course? selectedCourse;
  Subject? selectedSubject;
  Chapter? selectedChapter;
  Lesson? selectedLesson;

  List<Subject> subjects = [];
  List<Chapter> chapters = [];
  List<Lesson> lessons = [];

  bool loadingSubjects = false;
  bool loadingChapters = false;
  bool loadingLessons = false;

  String materialType = 'VIDEO';

  String source = 'DIRECT_UPLOAD';

  PlatformFile? selectedFile;

  bool isRequired = true;

  bool countsTowardProgress = true;

  bool saving = false;

  String? error;

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    courseSearch.dispose();
    externalUrl.dispose();
    duration.dispose();
    sequence.dispose();

    super.dispose();
  }

  Future<void> searchCourses() async {
    final query = courseSearch.text.trim();

    if (query.isEmpty) {
      return;
    }

    final result = await ref.read(courseRepositoryProvider).list(
          search: query,
        );

    if (mounted) {
      setState(() {
        courses = result.results;
      });
    }
  }

  Future<void> loadSubjects(
    String courseUuid,
  ) async {
    setState(() {
      loadingSubjects = true;

      selectedSubject = null;
      selectedChapter = null;
      selectedLesson = null;

      subjects = [];
      chapters = [];
      lessons = [];
    });

    try {
      final result = await ref.read(subjectRepositoryProvider).list(
            courseUuid: courseUuid,
          );

      if (mounted) {
        setState(() {
          subjects = result.results;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          loadingSubjects = false;
        });
      }
    }
  }

  Future<void> loadChapters(
    String subjectUuid,
  ) async {
    setState(() {
      loadingChapters = true;

      selectedChapter = null;
      selectedLesson = null;

      chapters = [];
      lessons = [];
    });

    try {
      final result = await ref.read(chapterRepositoryProvider).list(
            subjectUuid: subjectUuid,
          );

      if (mounted) {
        setState(() {
          chapters = result.results;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          loadingChapters = false;
        });
      }
    }
  }

  Future<void> loadLessons(
    String chapterUuid,
  ) async {
    setState(() {
      loadingLessons = true;

      selectedLesson = null;
      lessons = [];
    });

    try {
      final result = await ref.read(lessonRepositoryProvider).list(
            chapterUuid: chapterUuid,
          );

      if (mounted) {
        setState(() {
          lessons = result.results;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          loadingLessons = false;
        });
      }
    }
  }

  Future<void> chooseFile() async {
    FileType fileType = FileType.custom;

    List<String> extensions = [];

    if (materialType == 'VIDEO') {
      extensions = [
        'mp4',
        'webm',
        'mov',
      ];
    } else if (materialType == 'PDF') {
      extensions = [
        'pdf',
      ];
    } else if (materialType == 'DOCUMENT') {
      extensions = [
        'pdf',
        'doc',
        'docx',
      ];
    }

    final result = await FilePicker.platform.pickFiles(
      type: fileType,
      allowedExtensions: extensions,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    setState(() {
      selectedFile = result.files.first;
    });
  }

  Future<void> save() async {
    if (selectedCourse == null) {
      setState(() {
        error = 'Please select a course.';
      });

      return;
    }

    if (title.text.trim().isEmpty) {
      setState(() {
        error = 'Title is required.';
      });

      return;
    }

    if (materialType == 'LINK') {
      if (externalUrl.text.trim().isEmpty) {
        setState(() {
          error = 'External URL is required.';
        });

        return;
      }
    } else {
      if (selectedFile == null || selectedFile!.bytes == null) {
        setState(() {
          error = 'Please select a file.';
        });

        return;
      }
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await ref.read(materialRepositoryProvider).create(
            courseUuid: selectedCourse!.uuid,
            subjectUuid: selectedSubject?.uuid,
            chapterUuid: selectedChapter?.uuid,
            lessonUuid: selectedLesson?.uuid,
            title: title.text,
            description: description.text,
            materialType: materialType,
            source: source,
            externalUrl: externalUrl.text,
            fileBytes: selectedFile?.bytes,
            fileName: selectedFile?.name,
            durationSeconds: int.tryParse(
              duration.text,
            ),
            sequence: int.tryParse(
                  sequence.text,
                ) ??
                1,
            isRequired: isRequired,
            countsTowardProgress: countsTowardProgress,
          );

      if (mounted) {
        Navigator.pop(
          context,
          true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Material'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: description,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: courseSearch,
                      decoration: const InputDecoration(
                        labelText: 'Search Course',
                      ),
                      onSubmitted: (_) => searchCourses(),
                    ),
                  ),
                  IconButton(
                    onPressed: searchCourses,
                    icon: const Icon(
                      Icons.search,
                    ),
                  ),
                ],
              ),
              if (courses.isNotEmpty)
                SizedBox(
                  height: 130,
                  child: ListView.builder(
                    itemCount: courses.length,
                    itemBuilder: (context, index) {
                      final course = courses[index];

                      return RadioListTile<String>(
                        value: course.uuid,
                        groupValue: selectedCourse?.uuid,
                        title: Text(course.name),
                        subtitle: Text(course.code),
                        onChanged: (_) async {
                          setState(() {
                            selectedCourse = course;
                          });

                          await loadSubjects(
                            course.uuid,
                          );
                        },
                      );
                    },
                  ),
                ),
              if (selectedCourse != null) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedSubject?.uuid,
                  decoration: const InputDecoration(
                    labelText: 'Subject (Optional)',
                  ),
                  items: subjects
                      .map(
                        (subject) => DropdownMenuItem<String>(
                          value: subject.uuid,
                          child: Text(
                            subject.name,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    if (value == null) {
                      return;
                    }

                    final subject = subjects.firstWhere(
                      (item) => item.uuid == value,
                    );

                    setState(() {
                      selectedSubject = subject;
                    });

                    await loadChapters(
                      subject.uuid,
                    );
                  },
                ),
                if (loadingSubjects) const LinearProgressIndicator(),
              ],
              if (selectedSubject != null) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedChapter?.uuid,
                  decoration: const InputDecoration(
                    labelText: 'Chapter (Optional)',
                  ),
                  items: chapters
                      .map(
                        (chapter) => DropdownMenuItem<String>(
                          value: chapter.uuid,
                          child: Text(
                            chapter.title,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    if (value == null) {
                      return;
                    }

                    final chapter = chapters.firstWhere(
                      (item) => item.uuid == value,
                    );

                    setState(() {
                      selectedChapter = chapter;
                    });

                    await loadLessons(
                      chapter.uuid,
                    );
                  },
                ),
                if (loadingChapters) const LinearProgressIndicator(),
              ],
              if (selectedChapter != null) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedLesson?.uuid,
                  decoration: const InputDecoration(
                    labelText: 'Lesson (Optional)',
                  ),
                  items: lessons
                      .map(
                        (lesson) => DropdownMenuItem<String>(
                          value: lesson.uuid,
                          child: Text(
                            lesson.title,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      selectedLesson = lessons.firstWhere(
                        (item) => item.uuid == value,
                      );
                    });
                  },
                ),
                if (loadingLessons) const LinearProgressIndicator(),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: materialType,
                decoration: const InputDecoration(
                  labelText: 'Material Type',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'VIDEO',
                    child: Text('Video'),
                  ),
                  DropdownMenuItem(
                    value: 'PDF',
                    child: Text('PDF'),
                  ),
                  DropdownMenuItem(
                    value: 'DOCUMENT',
                    child: Text('Document'),
                  ),
                  DropdownMenuItem(
                    value: 'LINK',
                    child: Text('Link'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    materialType = value ?? 'VIDEO';

                    selectedFile = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: source,
                decoration: const InputDecoration(
                  labelText: 'Source',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'DIRECT_UPLOAD',
                    child: Text(
                      'Direct Upload',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'LIVE_CLASS_RECORDING',
                    child: Text(
                      'Live Class Recording',
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    source = value ?? 'DIRECT_UPLOAD';
                  });
                },
              ),
              const SizedBox(height: 14),
              if (materialType == 'LINK')
                TextField(
                  controller: externalUrl,
                  decoration: const InputDecoration(
                    labelText: 'External URL',
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedFile == null
                            ? 'No file selected'
                            : selectedFile!.name,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: chooseFile,
                      icon: const Icon(
                        Icons.attach_file,
                      ),
                      label: const Text(
                        'Select File',
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              TextField(
                controller: duration,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration Seconds',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sequence,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Sequence',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Required'),
                value: isRequired,
                onChanged: (value) {
                  setState(() {
                    isRequired = value;
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Counts Toward Progress',
                ),
                value: countsTowardProgress,
                onChanged: (value) {
                  setState(() {
                    countsTowardProgress = value;
                  });
                },
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(
            saving ? 'Uploading...' : 'Save Material',
          ),
        ),
      ],
    );
  }
}

IconData _iconForType(
  String type,
) {
  switch (type) {
    case 'VIDEO':
      return Icons.videocam_outlined;

    case 'PDF':
      return Icons.picture_as_pdf_outlined;

    case 'DOCUMENT':
      return Icons.description_outlined;

    case 'LINK':
      return Icons.link;

    default:
      return Icons.insert_drive_file_outlined;
  }
}
