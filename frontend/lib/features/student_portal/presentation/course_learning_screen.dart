import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/student_portal_repository.dart';
import 'widgets/student_ui.dart';

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
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return FutureBuilder<MyCourse>(
      future: _course,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return StudentPageFrame(
            child: ListView(
              padding: const EdgeInsets.all(kStudentPagePadding),
              children: [
                StudentStateMessage(
                  icon: Icons.wifi_off_rounded,
                  title: 'Course could not load',
                  message: '${snapshot.error}',
                  actionLabel: 'Try again',
                  onAction: () => setState(_load),
                  isError: true,
                ),
              ],
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
              // The FutureBuilders below show the error.
            }
          },
          child: StudentPageFrame(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                kStudentPagePadding,
                4,
                kStudentPagePadding,
                28,
              ),
              children: [
                // Course hero
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: colors.heroGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: colors.heroShadow,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        right: -8,
                        top: -6,
                        child: Icon(
                          Icons.menu_book_rounded,
                          size: 84,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              TonalPill(
                                label: course.categoryName ?? course.code,
                                icon: Icons.school_rounded,
                                background:
                                    Colors.white.withValues(alpha: 0.18),
                                foreground: Colors.white,
                              ),
                              TonalPill(
                                label: course.accessEndAt == null
                                    ? 'Access active'
                                    : 'Access until ${course.accessEndAt}',
                                icon: Icons.verified_outlined,
                                background:
                                    Colors.white.withValues(alpha: 0.18),
                                foreground: Colors.white,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            course.name,
                            style: textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          if (course.description.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              course.description,
                              style: textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFFDAD7FF),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _progressCard(),
                _resourceList(
                  title: 'Study materials & videos',
                  icon: Icons.video_library_outlined,
                  countNoun: 'lesson',
                  future: _materials,
                  emptyMessage: 'No study materials available.',
                  emptyIcon: Icons.video_library_outlined,
                  titleKey: 'title',
                  iconFor: _materialIcon,
                  accent: colors.primary,
                  accentBg: colors.primaryTonal,
                  trailingIcon: Icons.play_arrow_rounded,
                  subtitleBuilder: (item) => _resourceSubtitle(
                    item,
                    typeKey: 'material_type',
                  ),
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
                _resourceList(
                  title: 'Live sessions',
                  icon: Icons.live_tv_rounded,
                  countNoun: 'session',
                  future: _classes,
                  emptyMessage: 'No live classes scheduled.',
                  emptyIcon: Icons.event_busy_rounded,
                  titleKey: 'title',
                  iconFor: (item) =>
                      item['status']?.toString().toUpperCase() == 'LIVE'
                          ? Icons.podcasts_rounded
                          : Icons.videocam_outlined,
                  accent: colors.danger,
                  accentBg: colors.dangerBg,
                  subtitleBuilder: (item) => _resourceSubtitle(
                    item,
                    typeKey: 'status',
                  ),
                  onTap: (item) {
                    final uuid = item['uuid']?.toString();

                    if (uuid != null) {
                      context.push(
                        '/student/live-classes/$uuid',
                      );
                    }
                  },
                ),
                _resourceList(
                  title: 'Assignments & tests',
                  icon: Icons.assignment_outlined,
                  countNoun: 'assignment',
                  future: _assignments,
                  emptyMessage: 'No assignments available.',
                  emptyIcon: Icons.assignment_turned_in_outlined,
                  titleKey: 'title',
                  iconFor: (_) => Icons.edit_note_rounded,
                  accent: colors.warning,
                  accentBg: colors.warningBg,
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
          ),
        );
      },
    );
  }

  IconData _materialIcon(Map<String, dynamic> item) {
    final type = item['material_type']?.toString().toUpperCase() ?? '';
    if (type.contains('VIDEO')) return Icons.play_circle_outline_rounded;
    if (type.contains('PDF') || type.contains('DOC')) {
      return Icons.picture_as_pdf_outlined;
    }
    if (type.contains('LINK') || type.contains('URL')) {
      return Icons.link_rounded;
    }
    if (type.contains('AUDIO')) return Icons.headphones_rounded;
    return Icons.description_outlined;
  }

  String _resourceSubtitle(
    Map<String, dynamic> item, {
    required String typeKey,
  }) {
    final parts = <String>[];

    for (final key in [
      typeKey,
      'subject_name',
      'chapter_title',
      'lesson_title',
    ]) {
      final value = item[key]?.toString().trim();

      if (value != null && value.isNotEmpty) {
        parts.add(value);
      }
    }

    return parts.isEmpty ? 'Course content' : parts.join(' · ');
  }

  Widget _progressCard() {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return FutureBuilder<Map<String, dynamic>>(
      future: _progress,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return PremiumCard(
            child: Row(
              children: [
                IconTile(
                  icon: Icons.error_outline_rounded,
                  background: colors.dangerBg,
                  foreground: colors.danger,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Could not load progress: ${snapshot.error}',
                    style: textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const PremiumCard(
            child: LinearProgressIndicator(minHeight: 8),
          );
        }

        final data = snapshot.data!;

        final total = (data['total_materials'] as num?)?.toInt() ?? 0;

        final completed =
            (data['completed_materials'] as num?)?.toInt() ?? 0;

        final rawPercentage = double.tryParse(
              data['completion_percentage']?.toString() ?? '0',
            ) ??
            0;

        final percentage = rawPercentage.clamp(0.0, 100.0).toDouble();
        final done = percentage >= 100;

        return PremiumCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconTile(
                    icon: done
                        ? Icons.emoji_events_outlined
                        : Icons.donut_large_rounded,
                    background: done ? colors.successBg : null,
                    foreground: done ? colors.success : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your progress', style: textTheme.titleMedium),
                        Text(
                          '$completed of $total materials completed',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${percentage.toStringAsFixed(0)}% done',
                    style: textTheme.titleMedium?.copyWith(
                      color: done ? colors.success : colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  minHeight: 8,
                  backgroundColor: colors.primaryTonal,
                  color: done ? colors.success : colors.primary,
                ),
              ),
              if (total == 0) ...[
                const SizedBox(height: 10),
                Text(
                  'No materials are currently counted toward progress.',
                  style: textTheme.bodySmall,
                ),
              ],
            ],
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
    required String title,
    required IconData icon,
    required String countNoun,
    required Future<List<Map<String, dynamic>>> future,
    required String emptyMessage,
    required IconData emptyIcon,
    required String titleKey,
    required IconData Function(Map<String, dynamic>) iconFor,
    required Color accent,
    required Color accentBg,
    IconData? trailingIcon,
    String Function(Map<String, dynamic>)? subtitleBuilder,
    required void Function(Map<String, dynamic>) onTap,
  }) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        final count = snapshot.data?.length;

        final header = SectionHeader(
          title: title,
          icon: icon,
          iconColor: accent,
          trailing: count == null || count == 0
              ? null
              : Text(
                  '$count ${count == 1 ? countNoun : '${countNoun}s'}',
                  style: textTheme.labelLarge?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
        );

        Widget body;

        if (snapshot.hasError) {
          body = PremiumCard(
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: colors.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Could not load: ${snapshot.error}',
                    style: textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          );
        } else if (!snapshot.hasData) {
          body = const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          );
        } else if (snapshot.data!.isEmpty) {
          body = PremiumCard(
            child: Row(
              children: [
                IconTile(
                  icon: emptyIcon,
                  background: const Color(0xFFF1F2F8),
                  foreground: colors.textSubtle,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    emptyMessage,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          body = Column(
            children: [
              for (final item in snapshot.data!)
                PremiumCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  onTap: () => onTap(item),
                  child: Row(
                    children: [
                      IconTile(
                        icon: iconFor(item),
                        size: 48,
                        radius: 14,
                        background: accentBg,
                        foreground: accent,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item[titleKey]?.toString() ?? 'Untitled',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitleBuilder?.call(item) ??
                                  item['material_type']?.toString() ??
                                  item['status']?.toString() ??
                                  '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (trailingIcon != null)
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colors.primaryDeep,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            trailingIcon,
                            color: Colors.white,
                            size: 22,
                          ),
                        )
                      else
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colors.textSubtle,
                        ),
                    ],
                  ),
                ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            header,
            body,
          ],
        );
      },
    );
  }
}
