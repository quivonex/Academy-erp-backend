import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/user_role.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../courses/data/course.dart';
import '../../students/data/student.dart';
import '../../subjects/data/chapter.dart';
import '../data/chapter_video_access_repository.dart';

class BulkChapterVideoAccessScreen extends ConsumerWidget {
  const BulkChapterVideoAccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);

    if (session.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if ((session.role != UserRole.academyAdmin &&
            session.role != UserRole.firmStaff) ||
        (session.firmUuid ?? '').isEmpty) {
      return const AdminStateMessage(
        icon: Icons.lock_outline,
        title: 'Video access unavailable',
        message:
            'Sign in as an academy admin or staff member linked to a firm.',
      );
    }

    return _AccessForm(
      key: ValueKey('${session.userUuid}_${session.firmUuid}'),
    );
  }
}

class _AccessForm extends ConsumerStatefulWidget {
  const _AccessForm({super.key});

  @override
  ConsumerState<_AccessForm> createState() => _AccessFormState();
}

class _AccessFormState extends ConsumerState<_AccessForm> {
  final studentSearch = TextEditingController();
  final chapterSearch = TextEditingController();

  List<Course> courses = [];
  List<Student> students = [];
  List<Chapter> chapters = [];

  final selectedStudents = <String>{};
  final selectedChapters = <String>{};

  String? courseUuid;
  String? courseError;
  String? studentError;
  String? chapterError;
  String? error;

  DateTime? startsAt;
  DateTime? endsAt;
  ChapterVideoAccessResult? result;

  int studentPage = 1;
  int chapterPage = 1;
  int chapterRevision = 0;

  bool loadingCourses = false;
  bool loadingStudents = false;
  bool loadingChapters = false;
  bool working = false;
  bool picking = false;

  bool get locked => working || picking;
  bool get editable => !locked && result == null;

  ChapterVideoAccessRepository get repo =>
      ref.read(chapterVideoAccessRepositoryProvider);

  Course? get course {
    for (final item in courses) {
      if (item.uuid == courseUuid) return item;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    loadCourses();
    loadStudents();
  }

  @override
  void dispose() {
    studentSearch.dispose();
    chapterSearch.dispose();
    super.dispose();
  }

  Future<void> loadCourses() async {
    if (!editable || loadingCourses) return;

    setState(() {
      loadingCourses = true;
      courseError = null;
    });

    try {
      final items = await repo.courses();
      if (!mounted) return;

      setState(() {
        courses = items;

        if (courseUuid != null &&
            !items.any((c) => c.uuid == courseUuid)) {
          chapterRevision++;
          courseUuid = null;
          chapters = [];
          loadingChapters = false;
          chapterError = null;
          selectedStudents.clear();
          selectedChapters.clear();
          chapterPage = 1;
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => courseError = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => courseError = 'Could not load courses. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => loadingCourses = false);
    }
  }

  Future<void> loadStudents() async {
    if (!editable || loadingStudents) return;

    setState(() {
      loadingStudents = true;
      studentError = null;
    });

    try {
      final items = await repo.students();
      if (!mounted) return;

      setState(() {
        students = items;
        studentPage = 1;
        selectedStudents.removeWhere(
          (uuid) => !items.any((s) => s.uuid == uuid),
        );
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => studentError = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => studentError = 'Could not load students. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => loadingStudents = false);
    }
  }

  void changeCourse(String? value) {
    if (!editable || value == courseUuid) return;

    setState(() {
      chapterRevision++;
      courseUuid = value;
      chapters = [];
      selectedStudents.clear();
      selectedChapters.clear();
      chapterPage = studentPage = 1;
      chapterSearch.clear();
      studentSearch.clear();
      chapterError = error = null;
      loadingChapters = false;
    });

    if (value != null) loadChapters();
  }

  Future<void> loadChapters() async {
    if (!editable || courseUuid == null || loadingChapters) return;

    final uuid = courseUuid!;
    final ticket = ++chapterRevision;

    bool current() =>
        mounted && ticket == chapterRevision && courseUuid == uuid;

    setState(() {
      loadingChapters = true;
      chapterError = null;
    });

    try {
      final items = await repo.chapters(
        uuid,
        stillCurrent: current,
      );

      if (!current()) return;

      setState(() {
        chapters = items;
        chapterPage = 1;
        selectedChapters.removeWhere(
          (id) => !items.any((c) => c.uuid == id),
        );
      });
    } on ApiException catch (e) {
      if (current()) setState(() => chapterError = e.message);
    } catch (_) {
      if (current()) {
        setState(
          () => chapterError =
              'Could not load this course’s chapters. Please retry.',
        );
      }
    } finally {
      if (current()) setState(() => loadingChapters = false);
    }
  }

  Future<void> pickDate(bool start) async {
    if (!editable) return;
    setState(() => picking = true);

    try {
      final initial =
          (start ? startsAt : endsAt) ?? DateTime.now();
      final day = DateTime(initial.year, initial.month, initial.day);

      final picked = await showDatePicker(
        context: context,
        initialDate: day,
        firstDate: day.isBefore(DateTime(2000))
            ? day
            : DateTime(2000),
        lastDate: day.isAfter(DateTime(2100, 12, 31))
            ? day
            : DateTime(2100, 12, 31),
      );

      if (!mounted || picked == null) return;

      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );

      if (!mounted || time == null) return;

      final value = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time.hour,
        time.minute,
      );

      setState(() {
        if (start) {
          startsAt = value;
        } else {
          endsAt = value;
        }
        error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not open the date picker. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  String? validateSelection() {
    if (course == null || !course!.isActive) {
      return 'Select an active course.';
    }

    if (loadingCourses ||
        loadingStudents ||
        loadingChapters ||
        courseError != null ||
        studentError != null ||
        chapterError != null) {
      return 'Load the selection lists before granting access.';
    }

    if (selectedStudents.isEmpty || selectedStudents.length > 500) {
      return 'Select between 1 and 500 students.';
    }

    if (selectedChapters.isEmpty || selectedChapters.length > 100) {
      return 'Select between 1 and 100 chapters.';
    }

    final start = startsAt ?? DateTime.now();
    if (endsAt != null && !endsAt!.isAfter(start)) {
      return 'Access end must be after access start.';
    }

    return null;
  }

  Future<void> grant() async {
    if (!editable) return;

    final message = validateSelection();
    if (message != null) {
      setState(() => error = message);
      return;
    }

    final selectedCourse = course!;
    final studentIds = Set<String>.from(selectedStudents);
    final chapterIds = Set<String>.from(selectedChapters);
    final start = startsAt;
    final end = endsAt;

    setState(() {
      working = true;
      error = null;
    });

    try {
      var dialogResolved = false;

      void resolve(BuildContext dialogContext, bool value) {
        if (dialogResolved) return;
        dialogResolved = true;
        Navigator.pop(dialogContext, value);
      }

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Review video access'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${selectedCourse.name} (${selectedCourse.code})',
                ),
                const SizedBox(height: 12),
                Text(
                  '${studentIds.length} students × '
                  '${chapterIds.length} chapters',
                ),
                Text(
                  '${studentIds.length * chapterIds.length} '
                  'permissions will be created or renewed.',
                ),
                Text('Start: ${start == null ? 'Now' : _date(start)}'),
                Text(
                  'End: ${end == null ? defaultEnd(selectedCourse) : _date(end)}',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Existing permissions receive the new access dates.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => resolve(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => resolve(dialogContext, true),
              child: const Text('Grant access'),
            ),
          ],
        ),
      );

      if (!mounted || confirmed != true) return;

      if (end != null && !end.isAfter(start ?? DateTime.now())) {
        setState(
          () => error =
              'The end time has passed. Choose a later end time.',
        );
        return;
      }

      final receipt = await repo.grant(
        courseUuid: selectedCourse.uuid,
        studentUuids: studentIds,
        chapterUuids: chapterIds,
        startsAt: start,
        endsAt: end,
      );

      if (!mounted) return;

      setState(() => result = receipt);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chapter video access granted successfully.'),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not confirm the grant result. '
              'Please check before submitting again.',
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  String defaultEnd(Course value) {
    final days = value.accessDurationDays;
    return days != null && days > 0
        ? '$days days after start (course default)'
        : 'No expiry (course default)';
  }

  void toggle(
    Set<String> selected,
    String id,
    bool value,
    int limit,
  ) {
    if (!editable) return;

    if (value && !selected.contains(id) && selected.length >= limit) {
      setState(() => error = 'You can select at most $limit items.');
      return;
    }

    setState(() {
      if (value) {
        selected.add(id);
      } else {
        selected.remove(id);
      }
      error = null;
    });
  }

  Widget selector({
    required String title,
    required List<_Choice> items,
    required Set<String> selected,
    required TextEditingController search,
    required int page,
    required int limit,
    required bool loading,
    required String? loadError,
    required VoidCallback retry,
    required ValueChanged<int> onPage,
    required VoidCallback onSearch,
  }) {
    final text = search.text.trim().toLowerCase();

    final filtered = items
        .where(
          (i) => '${i.title} ${i.subtitle}'.toLowerCase().contains(text),
        )
        .toList();

    final visible = filtered.skip((page - 1) * 20).take(20).toList();
    final enabled =
        editable && courseUuid != null && !loading && loadError == null;

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$title — ${selected.length}/$limit selected',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: search,
            enabled: enabled,
            decoration: adminFieldDecoration(
              context,
              hint: 'Search $title',
              icon: Icons.search,
            ),
            onChanged: (_) => onSearch(),
          ),
          const SizedBox(height: 8),
          if (loading)
            const LinearProgressIndicator()
          else if (loadError != null) ...[
            AdminErrorBanner(message: loadError),
            TextButton(
              onPressed: editable ? retry : null,
              child: const Text('Retry'),
            ),
          ] else ...[
            Wrap(
              spacing: 12,
              children: [
                TextButton(
                  onPressed: enabled && visible.isNotEmpty
                      ? () {
                          final combined = {
                            ...selected,
                            ...visible.map((i) => i.uuid),
                          };

                          if (combined.length > limit) {
                            setState(
                              () => error =
                                  'Selection exceeds the limit of $limit.',
                            );
                            return;
                          }

                          setState(() {
                            selected.addAll(
                              visible.map((i) => i.uuid),
                            );
                            error = null;
                          });
                        }
                      : null,
                  child: const Text('Select this page'),
                ),
                TextButton(
                  onPressed: enabled && selected.isNotEmpty
                      ? () => setState(selected.clear)
                      : null,
                  child: const Text('Clear selection'),
                ),
              ],
            ),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  courseUuid == null
                      ? 'Select a course first.'
                      : 'No matching active items.',
                ),
              ),
            for (final item in visible)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: selected.contains(item.uuid),
                title: Text(item.title),
                subtitle: Text(item.subtitle),
                onChanged: enabled
                    ? (v) => toggle(
                          selected,
                          item.uuid,
                          v == true,
                          limit,
                        )
                    : null,
              ),
            IgnorePointer(
              ignoring: !enabled,
              child: AdminPager(
                page: page,
                pageSize: 20,
                total: filtered.length,
                noun: title,
                onPage: (value) {
                  if (enabled) onPage(value);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget dateField(
    String label,
    DateTime? value,
    bool start,
  ) =>
      FieldLabel(
        label: label,
        child: InputDecorator(
          decoration: adminFieldDecoration(context),
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                value == null
                    ? (start ? 'Start now' : 'Use course default')
                    : _date(value),
              ),
              IconButton(
                tooltip: 'Choose $label',
                onPressed: editable ? () => pickDate(start) : null,
                icon: const Icon(Icons.event),
              ),
              if (value != null)
                IconButton(
                  tooltip: 'Clear $label',
                  onPressed: editable
                      ? () => setState(() {
                            if (start) {
                              startsAt = null;
                            } else {
                              endsAt = null;
                            }
                            error = null;
                          })
                      : null,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ),
      );

  Widget receipt(ChapterVideoAccessResult value) => AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Access granted — ${value.courseName}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                Text('Students: ${value.studentsCount}'),
                Text('Chapters: ${value.chaptersCount}'),
                Text('Created: ${value.createdCount}'),
                Text('Renewed: ${value.renewedCount}'),
              ],
            ),
            const SizedBox(height: 12),
            Text('Start: ${_date(value.startsAt)}'),
            Text(
              'End: ${value.endsAt == null ? 'No expiry' : _date(value.endsAt)}',
            ),
            ExpansionTile(
              title: const Text('Students'),
              children: [
                for (final student in value.students)
                  ListTile(title: Text(student)),
              ],
            ),
            ExpansionTile(
              title: const Text('Chapters'),
              children: [
                for (final chapter in value.chapters)
                  ListTile(title: Text(chapter)),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: GradientButton(
                label: 'New grant',
                onPressed: locked
                    ? null
                    : () => setState(() {
                          result = null;
                          error = null;
                          selectedStudents.clear();
                          selectedChapters.clear();
                          startsAt = endsAt = null;
                          studentPage = chapterPage = 1;
                          studentSearch.clear();
                          chapterSearch.clear();
                        }),
              ),
            ),
          ],
        ),
      );

  void back() {
    if (locked) return;

    if (context.canPop()) {
      context.pop(result != null);
    } else {
      context.go('/enrollments');
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !locked,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: locked ? null : back,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Enrollments'),
              ),
            ),
            const AdminPageHeader(
              title: 'Chapter Video Access',
              subtitle:
                  'Grant selected chapter videos to multiple students.',
            ),
            const SizedBox(height: 20),
            if (result != null)
              receipt(result!)
            else ...[
              AdminCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FieldLabel(
                      label: 'Course',
                      required: true,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('${courseUuid}_${courses.length}'),
                        value: courseUuid,
                        isExpanded: true,
                        decoration: adminFieldDecoration(
                          context,
                          hint: 'Select an active course',
                        ),
                        items: [
                          for (final item in courses)
                            DropdownMenuItem(
                              value: item.uuid,
                              child: Text(
                                '${item.name} (${item.code})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: editable &&
                                !loadingCourses &&
                                courseError == null
                            ? changeCourse
                            : null,
                      ),
                    ),
                    if (loadingCourses) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    if (courseError != null) ...[
                      const SizedBox(height: 12),
                      AdminErrorBanner(message: courseError!),
                      TextButton(
                        onPressed: editable ? loadCourses : null,
                        child: const Text('Retry courses'),
                      ),
                    ],
                    if (!loadingCourses &&
                        courseError == null &&
                        courses.isEmpty)
                      const Text('No active courses available.'),
                    const SizedBox(height: 12),
                    const Text(
                      'Changing the course clears both student '
                      'and chapter selections.',
                    ),
                    const SizedBox(height: 16),
                    FormRow(
                      left: dateField('Access start', startsAt, true),
                      right: dateField('Access end', endsAt, false),
                    ),
                    const SizedBox(height: 12),
                    if (course != null)
                      Text('Default end: ${defaultEnd(course!)}'),
                    const Text(
                      'Dates use local time. Clearing the end date '
                      'restores the course default duration.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FormRow(
                left: selector(
                  title: 'Students',
                  items: [
                    for (final s in students)
                      _Choice(s.uuid, s.fullName, s.admissionNumber),
                  ],
                  selected: selectedStudents,
                  search: studentSearch,
                  page: studentPage,
                  limit: 500,
                  loading: loadingStudents,
                  loadError: studentError,
                  retry: loadStudents,
                  onPage: (v) {
                    if (editable) setState(() => studentPage = v);
                  },
                  onSearch: () => setState(() => studentPage = 1),
                ),
                right: selector(
                  title: 'Chapters',
                  items: [
                    for (final c in chapters)
                      _Choice(c.uuid, c.title, c.subjectName),
                  ],
                  selected: selectedChapters,
                  search: chapterSearch,
                  page: chapterPage,
                  limit: 100,
                  loading: loadingChapters,
                  loadError: chapterError,
                  retry: loadChapters,
                  onPage: (v) {
                    if (editable) setState(() => chapterPage = v);
                  },
                  onSearch: () => setState(() => chapterPage = 1),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '${selectedStudents.length} students × '
                '${selectedChapters.length} chapters = '
                '${selectedStudents.length * selectedChapters.length} '
                'permissions',
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: GradientButton(
                  label: 'Review & grant access',
                  icon: Icons.video_library_outlined,
                  loading: working,
                  onPressed: editable &&
                          !loadingCourses &&
                          !loadingStudents &&
                          !loadingChapters &&
                          courseError == null &&
                          studentError == null &&
                          chapterError == null &&
                          course != null &&
                          selectedStudents.isNotEmpty &&
                          selectedChapters.isNotEmpty
                      ? grant
                      : null,
                ),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 12),
              AdminErrorBanner(message: error!),
            ],
          ],
        ),
      );
}

class _Choice {
  const _Choice(this.uuid, this.title, this.subtitle);

  final String uuid;
  final String title;
  final String subtitle;
}

String _date(DateTime? value) {
  if (value == null) return 'Not set';

  final d = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');

  return '${two(d.day)}/${two(d.month)}/${d.year} '
      '${two(d.hour)}:${two(d.minute)}';
}
