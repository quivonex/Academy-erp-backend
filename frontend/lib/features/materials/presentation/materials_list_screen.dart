import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../courses/data/course_repository.dart';
import '../../subjects/data/subject_repository.dart';
import '../../subjects/data/chapter_repository.dart';
import '../../subjects/data/lesson_repository.dart';
import '../../live_classes/data/live_class_repository.dart';
import '../data/material.dart';
import '../data/material_repository.dart';

class MaterialsListScreen extends ConsumerStatefulWidget {
  const MaterialsListScreen({super.key});

  @override
  ConsumerState<MaterialsListScreen> createState() =>
      _MaterialsListScreenState();
}

class _MaterialsListScreenState
    extends ConsumerState<MaterialsListScreen> {
  final searchController = TextEditingController();

  late Future<LearningMaterialPage> result;

  String search = '';
  String? typeFilter;
  int page = 1;
  bool creating = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void reload() {
    result = ref.read(materialRepositoryProvider).list(
      page: page,
      search: search,
      materialType: typeFilter,
    );
  }

  void refresh() => setState(reload);

  void applySearch() => setState(() {
    search = searchController.text.trim();
    page = 1;
    reload();
  });

  void setType(String? value) => setState(() {
    typeFilter = value;
    page = 1;
    reload();
  });

  Future<void> openCreate() async {
    if (creating) return;

    setState(() => creating = true);

    try {
      final created = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _CreateMaterialDialog(),
      );

      if (!mounted || created != true) return;

      setState(() {
        searchController.clear();
        search = '';
        typeFilter = null;
        page = 1;
        reload();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Material created successfully.'),
        ),
      );
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
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
            onPressed: creating ? null : openCreate,
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

            final data =
            state == null ? snapshot.data : null;

            final rows =
                data?.results ?? const <LearningMaterial>[];

            int countOf(String type) => rows
                .where(
                  (m) => m.materialType.toUpperCase() == type,
            )
                .length;

            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                AdminKpiGrid(
                  children: [
                    AdminKpiCard(
                      label: 'Matching materials',
                      value: data == null ? '…' : '${data.count}',
                      icon: Icons.folder_copy_outlined,
                    ),
                    AdminKpiCard(
                      label: 'Videos',
                      value: data == null
                          ? '…'
                          : '${countOf('VIDEO')}',
                      icon: Icons.smart_display_outlined,
                      caption: 'On this page',
                    ),
                    AdminKpiCard(
                      label: 'PDFs & documents',
                      value: data == null
                          ? '…'
                          : '${countOf('PDF') + countOf('DOCUMENT')}',
                      icon: Icons.picture_as_pdf_outlined,
                      caption: 'On this page',
                    ),
                    AdminKpiCard(
                      label: 'Links',
                      value: data == null
                          ? '…'
                          : '${countOf('LINK')}',
                      icon: Icons.link_rounded,
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
                    for (final type in [
                      null,
                      'VIDEO',
                      'PDF',
                      'DOCUMENT',
                      'LINK',
                    ])
                      CountFilterPill(
                        label: type ?? 'ALL',
                        selected: typeFilter == type,
                        onTap: () => setType(type),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                if (state != null)
                  state
                else ...[
                  if (rows.isEmpty)
                    AdminStateMessage(
                      icon: Icons.upload_file_rounded,
                      title: 'No materials found',
                      message:
                      'Add a material or change the filters/page.',
                      actionLabel: 'Add material',
                      onAction: creating ? null : openCreate,
                    ),
                  for (final material in rows)
                    AdminListRow(
                      title: material.title,
                      icon: _icon(material.materialType),
                      titleBadge: material.isRequired
                          ? const SoftBadge(label: 'Required')
                          : null,
                      subtitle: material.description,
                      meta: [
                        SoftBadge(label: material.materialType),
                        MetaChip(
                          icon: Icons.auto_stories_outlined,
                          label: material.courseName,
                        ),
                        if ((material.subjectName ?? '').isNotEmpty)
                          MetaChip(
                            icon: Icons.menu_book_outlined,
                            label: material.subjectName!,
                          ),
                        if ((material.chapterTitle ?? '').isNotEmpty)
                          MetaChip(
                            icon: Icons.book_outlined,
                            label: material.chapterTitle!,
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
                      trailing: [
                        ActiveBadge(active: material.isActive),
                      ],
                      onTap: () async {
                        await context.push(
                          '/materials/${material.uuid}',
                        );
                        if (mounted) refresh();
                      },
                    ),
                  if (data!.count > 0 || page > 1)
                    AdminPager(
                      page: page,
                      pageSize: 20,
                      total: data.count,
                      noun: 'materials',
                      onPage: (next) => setState(() {
                        page = next;
                        reload();
                      }),
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

class _Choice {
  const _Choice(this.uuid, this.label);

  final String uuid;
  final String label;
}

class _ChoicePage {
  const _ChoicePage(this.count, this.items);

  final int count;
  final List<_Choice> items;
}

class _CreateMaterialDialog extends ConsumerStatefulWidget {
  const _CreateMaterialDialog();

  @override
  ConsumerState<_CreateMaterialDialog> createState() =>
      _CreateMaterialDialogState();
}

class _CreateMaterialDialogState
    extends ConsumerState<_CreateMaterialDialog> {
  static const hierarchy = [
    'course',
    'subject',
    'chapter',
    'lesson',
  ];

  final formKey = GlobalKey<FormState>();

  final title = TextEditingController();
  final description = TextEditingController();
  final courseSearch = TextEditingController();
  final externalUrl = TextEditingController();
  final duration = TextEditingController();
  final sequence = TextEditingController(text: '1');

  final selected = <String, String?>{};
  final options = <String, List<_Choice>>{};
  final loading = <String, bool>{};
  final errors = <String, String?>{};
  final tickets = <String, int>{};

  String materialType = 'VIDEO';
  String source = 'DIRECT_UPLOAD';

  PlatformFile? selectedFile;
  DateTime? availableFrom;
  DateTime? availableUntil;

  bool isRequired = true;
  bool countsTowardProgress = true;
  bool saving = false;
  bool picking = false;

  String? error;

  bool get waiting => loading.values.any((value) => value);

  int get maximumBytes =>
      (materialType == 'VIDEO' ? 100 : 25) * 1024 * 1024;

  List<String> get extensions => switch (materialType) {
    'VIDEO' => ['mp4', 'webm', 'mov'],
    'PDF' => ['pdf'],
    'DOCUMENT' => ['pdf', 'doc', 'docx'],
    _ => <String>[],
  };

  @override
  void initState() {
    super.initState();
    loadOptions('course');
  }

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

  String? parentOf(String kind) => switch (kind) {
    'subject' => selected['course'],
    'chapter' => selected['subject'],
    'lesson' => selected['chapter'],
    'live' => selected['course'],
    _ => null,
  };

  Future<_ChoicePage> fetchOptions(
      String kind,
      String? parent,
      int page,
      ) async {
    switch (kind) {
      case 'course':
        {
          final data =
          await ref.read(courseRepositoryProvider).list(
            page: page,
          );

          return _ChoicePage(data.count, [
            for (final c in data.results.where((c) => c.isActive))
              _Choice(c.uuid, '${c.name} (${c.code})'),
          ]);
        }

      case 'subject':
        {
          final data =
          await ref.read(subjectRepositoryProvider).list(
            courseUuid: parent!,
            page: page,
          );

          return _ChoicePage(data.count, [
            for (final s in data.results.where((s) => s.isActive))
              _Choice(s.uuid, s.name),
          ]);
        }

      case 'chapter':
        {
          final data =
          await ref.read(chapterRepositoryProvider).list(
            subjectUuid: parent!,
            page: page,
          );

          return _ChoicePage(data.count, [
            for (final c in data.results.where((c) => c.isActive))
              _Choice(c.uuid, c.title),
          ]);
        }

      case 'lesson':
        {
          final data =
          await ref.read(lessonRepositoryProvider).list(
            chapterUuid: parent!,
            page: page,
          );

          return _ChoicePage(data.count, [
            for (final l in data.results.where((l) => l.isActive))
              _Choice(l.uuid, l.title),
          ]);
        }

      case 'live':
        {
          final data =
          await ref.read(liveClassRepositoryProvider).list(
            courseUuid: parent!,
            page: page,
          );

          return _ChoicePage(data.count, [
            for (final c in data.results.where((c) => c.isActive))
              _Choice(c.uuid, '${c.title} • ${c.status}'),
          ]);
        }

      default:
        throw StateError('Unknown dropdown');
    }
  }

  Future<void> loadOptions(String kind) async {
    if (saving || picking) return;

    final parent = parentOf(kind);

    if (kind != 'course' && parent == null) return;

    final ticket = (tickets[kind] ?? 0) + 1;
    tickets[kind] = ticket;

    setState(() {
      loading[kind] = true;
      errors[kind] = null;
    });

    try {
      final all = <String, _Choice>{};
      var page = 1;

      while (true) {
        final data = await fetchOptions(kind, parent, page);

        if (!mounted || tickets[kind] != ticket) return;

        for (final item in data.items) {
          all[item.uuid] = item;
        }

        // API count includes inactive records.
        if (page * 20 >= data.count) break;

        page++;
      }

      setState(() => options[kind] = all.values.toList());
    } on ApiException catch (e) {
      if (mounted && tickets[kind] == ticket) {
        setState(() => errors[kind] = e.message);
      }
    } catch (_) {
      if (mounted && tickets[kind] == ticket) {
        setState(() {
          errors[kind] =
          'Could not load $kind options. Please retry.';
        });
      }
    } finally {
      if (mounted && tickets[kind] == ticket) {
        setState(() => loading[kind] = false);
      }
    }
  }

  void resetOption(String kind) {
    tickets[kind] = (tickets[kind] ?? 0) + 1;
    selected[kind] = null;
    options[kind] = [];
    errors[kind] = null;
    loading[kind] = false;
  }

  void select(String kind, String? value) {
    if (saving || picking) return;

    final index = hierarchy.indexOf(kind);

    setState(() {
      selected[kind] = value;
      error = null;

      if (index >= 0) {
        for (final child in hierarchy.skip(index + 1)) {
          resetOption(child);
        }
      }

      if (kind == 'course') resetOption('live');
    });

    if (value != null &&
        index >= 0 &&
        index < hierarchy.length - 1) {
      loadOptions(hierarchy[index + 1]);
    }

    if (kind == 'course' &&
        value != null &&
        source == 'LIVE_CLASS_RECORDING') {
      loadOptions('live');
    }
  }

  String? validateFile(PlatformFile file) {
    final bytes = file.bytes;

    if (bytes == null || bytes.isEmpty) {
      return 'Could not read the file. Select it again.';
    }

    final extension = file.name.split('.').last.toLowerCase();

    if (!extensions.contains(extension)) {
      return 'Allowed files: ${extensions.join(', ')}.';
    }

    if (file.size > maximumBytes ||
        bytes.lengthInBytes > maximumBytes) {
      return 'Maximum file size is '
          '${maximumBytes ~/ (1024 * 1024)} MB.';
    }

    if (extension == 'pdf' &&
        (bytes.length < 5 ||
            bytes[0] != 37 ||
            bytes[1] != 80 ||
            bytes[2] != 68 ||
            bytes[3] != 70 ||
            bytes[4] != 45)) {
      return 'Selected file is not a valid PDF.';
    }

    return null;
  }

  Future<void> chooseFile() async {
    if (saving || picking || materialType == 'LINK') return;

    setState(() => picking = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        withData: true,
        allowMultiple: false,
      );

      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      final issue = validateFile(file);

      setState(() {
        if (issue == null) selectedFile = file;
        error = issue;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Could not select the file. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> pickDate(bool start) async {
    if (saving || picking) return;

    setState(() => picking = true);

    try {
      final initial =
          (start ? availableFrom : availableUntil ?? availableFrom) ??
              DateTime.now();

      final day = DateTime(
        initial.year,
        initial.month,
        initial.day,
      );

      final date = await showDatePicker(
        context: context,
        initialDate: day,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100, 12, 31),
      );

      if (!mounted || date == null) return;

      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );

      if (!mounted || time == null) return;

      setState(() {
        final value = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        if (start) {
          availableFrom = value;
        } else {
          availableUntil = value;
        }

        error = null;
      });
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  String? integer(String? value, {bool optional = false}) {
    final text = (value ?? '').trim();

    if (optional && text.isEmpty) return null;

    final number = int.tryParse(text);

    if (!RegExp(r'^\d+$').hasMatch(text) ||
        number == null ||
        number > 2147483647) {
      return 'Enter a whole number from 0 to 2147483647.';
    }

    return null;
  }

  Future<void> save() async {
    if (saving ||
        picking ||
        waiting ||
        !formKey.currentState!.validate()) {
      return;
    }

    if (availableFrom != null &&
        availableUntil != null &&
        !availableUntil!.isAfter(availableFrom!)) {
      setState(() {
        error =
        'Availability end must be after availability start.';
      });
      return;
    }

    if (materialType != 'LINK') {
      final issue = selectedFile == null
          ? 'Please select a file.'
          : validateFile(selectedFile!);

      if (issue != null) {
        setState(() => error = issue);
        return;
      }
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await ref.read(materialRepositoryProvider).create(
        courseUuid: selected['course']!,
        subjectUuid: selected['subject'],
        chapterUuid: selected['chapter'],
        lessonUuid: selected['lesson'],
        liveClassUuid: source == 'LIVE_CLASS_RECORDING'
            ? selected['live']
            : null,
        title: title.text,
        description: description.text,
        materialType: materialType,
        source: source,
        externalUrl:
        materialType == 'LINK' ? externalUrl.text : '',
        fileBytes:
        materialType == 'LINK' ? null : selectedFile!.bytes,
        fileName:
        materialType == 'LINK' ? null : selectedFile!.name,
        durationSeconds: duration.text.trim().isEmpty
            ? null
            : int.parse(duration.text.trim()),
        sequence: int.parse(sequence.text.trim()),
        availableFrom: availableFrom,
        availableUntil: availableUntil,
        isRequired: isRequired,
        countsTowardProgress: countsTowardProgress,
      );

      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Could not save material. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget dropdown(
      String kind,
      String label, {
        bool required = false,
      }) {
    final query = courseSearch.text.trim().toLowerCase();

    final items = (options[kind] ?? const <_Choice>[])
        .where(
          (item) =>
      kind != 'course' ||
          query.isEmpty ||
          item.label.toLowerCase().contains(query) ||
          item.uuid == selected[kind],
    )
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey(
              '$kind-${parentOf(kind)}-${selected[kind]}',
            ),
            value: selected[kind],
            isExpanded: true,
            decoration: adminFieldDecoration(context).copyWith(
              labelText: label,
              suffixIcon: !required && selected[kind] != null
                  ? IconButton(
                tooltip: 'Clear $label',
                onPressed: saving || picking
                    ? null
                    : () => select(kind, null),
                icon: const Icon(Icons.clear),
              )
                  : null,
            ),
            items: [
              for (final item in items)
                DropdownMenuItem(
                  value: item.uuid,
                  child: Text(
                    item.label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: saving ||
                picking ||
                loading[kind] == true ||
                errors[kind] != null ||
                items.isEmpty
                ? null
                : (value) => select(kind, value),
            validator: (value) => required && value == null
                ? 'Please select $kind.'
                : null,
          ),
          if (loading[kind] == true)
            const LinearProgressIndicator(),
          if (errors[kind] != null) ...[
            Text(
              errors[kind]!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: saving || picking
                    ? null
                    : () => loadOptions(kind),
                child: Text('Retry $kind'),
              ),
            ),
          ] else if (loading[kind] != true && items.isEmpty)
            const Text('No matching active options available.'),
        ],
      ),
    );
  }

  Widget field(
      TextEditingController controller,
      String label, {
        int? maxLength,
        int lines = 1,
        bool numeric = false,
        String? Function(String?)? validator,
      }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          enabled: !saving && !picking,
          maxLength: maxLength,
          maxLines: lines,
          validator: validator,
          keyboardType: numeric ? TextInputType.number : null,
          decoration: adminFieldDecoration(context).copyWith(
            labelText: label,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving && !picking,
    child: AdminFormDialog(
      icon: Icons.upload_file_rounded,
      title: 'Add material',
      subtitle:
      'Select course, curriculum mapping and material content.',
      onClose: saving || picking
          ? null
          : () => Navigator.of(context).pop(),
      body: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            field(
              title,
              'Title',
              maxLength: 255,
              validator: (value) =>
              (value ?? '').trim().isEmpty
                  ? 'Title is required.'
                  : null,
            ),
            field(description, 'Description', lines: 3),
            TextFormField(
              controller: courseSearch,
              enabled: !saving && !picking,
              decoration: adminFieldDecoration(
                context,
                icon: Icons.search,
              ).copyWith(
                labelText: 'Filter loaded courses',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            dropdown('course', 'Course', required: true),
            if (selected['course'] != null)
              dropdown('subject', 'Subject (optional)'),
            if (selected['subject'] != null)
              dropdown('chapter', 'Chapter (optional)'),
            if (selected['chapter'] != null)
              dropdown('lesson', 'Lesson (optional)'),
            DropdownButtonFormField<String>(
              value: materialType,
              decoration: adminFieldDecoration(context).copyWith(
                labelText: 'Material type',
              ),
              items: [
                for (final type in [
                  'VIDEO',
                  'PDF',
                  'DOCUMENT',
                  'LINK',
                ])
                  DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  ),
              ],
              onChanged: saving || picking
                  ? null
                  : (value) {
                if (value == null) return;

                setState(() {
                  materialType = value;
                  selectedFile = null;
                  error = null;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: source,
              isExpanded: true,
              decoration: adminFieldDecoration(context).copyWith(
                labelText: 'Source',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'DIRECT_UPLOAD',
                  child: Text('Direct upload'),
                ),
                DropdownMenuItem(
                  value: 'LIVE_CLASS_RECORDING',
                  child: Text('Live class recording'),
                ),
              ],
              onChanged: saving || picking
                  ? null
                  : (value) {
                if (value == null) return;

                setState(() {
                  source = value;
                  resetOption('live');
                  error = null;
                });

                if (source == 'LIVE_CLASS_RECORDING' &&
                    selected['course'] != null) {
                  loadOptions('live');
                }
              },
            ),
            const SizedBox(height: 14),
            if (source == 'LIVE_CLASS_RECORDING' &&
                selected['course'] != null)
              dropdown('live', 'Related live class (optional)'),
            if (materialType == 'LINK')
              field(
                externalUrl,
                'External URL',
                maxLength: 1000,
                validator: (value) {
                  final uri = Uri.tryParse(
                    (value ?? '').trim(),
                  );

                  if (uri == null ||
                      !['http', 'https'].contains(uri.scheme) ||
                      uri.host.isEmpty) {
                    return 'Enter a valid http/https URL.';
                  }

                  return null;
                },
              )
            else ...[
              Text(
                selectedFile == null
                    ? 'No file selected'
                    : selectedFile!.name,
              ),
              Text(
                'Allowed: ${extensions.join(', ')} • '
                    'Max ${maximumBytes ~/ (1024 * 1024)} MB',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  AdminOutlineButton(
                    label: 'Select file',
                    icon: Icons.attach_file,
                    onPressed:
                    saving || picking ? null : chooseFile,
                  ),
                  if (selectedFile != null)
                    TextButton(
                      onPressed: saving || picking
                          ? null
                          : () => setState(() {
                        selectedFile = null;
                        error = null;
                      }),
                      child: const Text('Remove file'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            field(
              duration,
              'Duration seconds (optional)',
              numeric: true,
              validator: (value) =>
                  integer(value, optional: true),
            ),
            field(
              sequence,
              'Sequence',
              numeric: true,
              validator: integer,
            ),
            for (final start in [true, false])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  start
                      ? 'Available from (local time)'
                      : 'Available until (local time)',
                ),
                subtitle: Text(
                  _date(start ? availableFrom : availableUntil),
                ),
                onTap: saving || picking
                    ? null
                    : () => pickDate(start),
                trailing:
                (start ? availableFrom : availableUntil) == null
                    ? const Icon(
                  Icons.calendar_month_outlined,
                )
                    : IconButton(
                  tooltip: 'Clear date',
                  icon: const Icon(Icons.clear),
                  onPressed: saving || picking
                      ? null
                      : () => setState(() {
                    if (start) {
                      availableFrom = null;
                    } else {
                      availableUntil = null;
                    }
                    error = null;
                  }),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Required'),
              value: isRequired,
              onChanged: saving || picking
                  ? null
                  : (value) =>
                  setState(() => isRequired = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Counts toward progress'),
              value: countsTowardProgress,
              onChanged: saving || picking
                  ? null
                  : (value) =>
                  setState(() => countsTowardProgress = value),
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
      actions: [
        AdminOutlineButton(
          label: 'Cancel',
          onPressed: saving || picking
              ? null
              : () => Navigator.of(context).pop(),
        ),
        GradientButton(
          label: 'Save material',
          loading: saving,
          onPressed: saving || picking || waiting ? null : save,
        ),
      ],
    ),
  );
}

IconData _icon(String type) => switch (type.toUpperCase()) {
  'VIDEO' => Icons.videocam_outlined,
  'PDF' => Icons.picture_as_pdf_outlined,
  'DOCUMENT' => Icons.description_outlined,
  'LINK' => Icons.link_rounded,
  _ => Icons.insert_drive_file_outlined,
};

String _date(DateTime? value) {
  if (value == null) return 'Not set';

  final local = value.toLocal();

  String two(int number) =>
      number.toString().padLeft(2, '0');

  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}