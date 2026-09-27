import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/student_portal_repository.dart';

class CourseLearningScreen
    extends ConsumerStatefulWidget {
  const CourseLearningScreen({
    super.key,
    required this.courseUuid,
  });

  final String courseUuid;

  @override
  ConsumerState<CourseLearningScreen> createState() =>
      _CourseLearningScreenState();
}

class _CourseLearningScreenState
    extends ConsumerState<CourseLearningScreen> {
  late Future<MyCourse> _course;
  late Future<Map<String, dynamic>> _progress;
  late Future<List<Map<String, dynamic>>> _materials;
  late Future<List<Map<String, dynamic>>> _classes;
  late Future<List<Map<String, dynamic>>> _assignments;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final api = ref.read(
      studentPortalRepositoryProvider,
    );

    _course = api.myCourse(widget.courseUuid);
    _progress = api.courseProgress(widget.courseUuid);
    _materials = api.materials(widget.courseUuid);
    _classes = api.classes(widget.courseUuid);
    _assignments = api.assignments(
      widget.courseUuid,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MyCourse>(
      future: _course,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load course: ${snapshot.error}',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final course = snapshot.data!;

        return RefreshIndicator(
          onRefresh: () async {
            setState(_load);

            try {
              await _course;
              await _progress;
            } catch (_) {
              // खालील FutureBuilders error दाखवतील.
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                course.name,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(course.description),
              const SizedBox(height: 20),
              _progressCard(),
              const SizedBox(height: 20),
              Text(
                'Study materials',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge,
              ),
              _resourceList(
                future: _materials,
                emptyMessage:
                'No study materials available.',
                titleKey: 'title',
                onTap: (item) async {
                  final uuid = item['uuid']?.toString();

                  if (uuid == null || uuid.isEmpty) return;

                  await context.push<void>(
                    '/student/materials/$uuid',
                  );

                  if (!mounted) return;

                  setState(() {
                    _progress = ref
                        .read(studentPortalRepositoryProvider)
                        .courseProgress(widget.courseUuid);
                  });
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Live classes',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge,
              ),
              _resourceList(
                future: _classes,
                emptyMessage:
                'No live classes scheduled.',
                titleKey: 'title',
                onTap: (item) {
                  final uuid = item['uuid']?.toString();

                  if (uuid != null) {
                    context.push(
                      '/student/live-classes/$uuid',
                    );
                  }
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Assignments',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge,
              ),
              _resourceList(
                future: _assignments,
                emptyMessage:
                'No assignments available.',
                titleKey: 'title',
                subtitleBuilder: _assignmentSubtitle,
                onTap: (item) {
                  final uuid = item['uuid']?.toString();

                  if (uuid != null) {
                    context.push(
                      '/student/assignments/$uuid',
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _progressCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _progress,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Could not load progress: '
                '${snapshot.error}',
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          );
        }

        final data = snapshot.data!;

        final total =
            (data['total_materials'] as num?)?.toInt() ??
                0;

        final completed =
            (data['completed_materials'] as num?)
                    ?.toInt() ??
                0;

        final rawPercentage = double.tryParse(
              data['completion_percentage']
                      ?.toString() ??
                  '0',
            ) ??
            0;

        final percentage =
            rawPercentage.clamp(0.0, 100.0).toDouble();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Course Progress',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: percentage / 100,
                  minHeight: 8,
                  borderRadius:
                      BorderRadius.circular(8),
                ),
                const SizedBox(height: 10),
                Text(
                  '${percentage.toStringAsFixed(0)}% completed',
                ),
                Text(
                  '$completed of $total materials completed',
                ),
                if (total == 0) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'No materials are currently counted '
                    'toward progress.',
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _assignmentSubtitle(Map<String, dynamic> assignment) {
    final dueAt = DateTime.tryParse(
      assignment['due_at']?.toString() ?? '',
    );
    final marks = assignment['max_marks']?.toString();
    final marksLabel =
        marks == null || marks.isEmpty ? '' : ' · $marks marks';

    if (dueAt == null) {
      return 'No due date$marksLabel';
    }

    final localDueAt = dueAt.toLocal();
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(localDueAt);

    if (DateTime.now().isAfter(dueAt)) {
      if (assignment['allow_late_submission'] == true) {
        return 'Late submissions allowed · Due $date$marksLabel';
      }
      return 'Deadline passed · Due $date$marksLabel';
    }

    return 'Due $date$marksLabel';
  }

  Widget _resourceList({
    required Future<List<Map<String, dynamic>>>
    future,
    required String emptyMessage,
    required String titleKey,
    String Function(Map<String, dynamic>)? subtitleBuilder,
    required void Function(Map<String, dynamic>)
    onTap,
  }) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Could not load: ${snapshot.error}',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(),
          );
        }

        if (snapshot.data!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(emptyMessage),
          );
        }

        return Column(
          children: [
            for (final item in snapshot.data!)
              Card(
                child: ListTile(
                  title: Text(
                    item[titleKey]?.toString() ??
                        'Untitled',
                  ),
                  subtitle: Text(
                    subtitleBuilder?.call(item) ??
                        item['material_type']?.toString() ??
                        item['status']?.toString() ??
                        '',
                  ),
                  trailing:
                  const Icon(Icons.chevron_right),
                  onTap: () => onTap(item),
                ),
              ),
          ],
        );
      },
    );
  }
}