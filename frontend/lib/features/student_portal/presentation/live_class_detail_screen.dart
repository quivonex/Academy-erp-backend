import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/open_external_link.dart';
import '../data/student_portal_repository.dart';
import 'widgets/student_ui.dart';

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _prettyDateTime(String raw) {
  final date = DateTime.tryParse(raw)?.toLocal();
  if (date == null) return raw;
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '${_dayNames[date.weekday - 1]}, ${date.day} '
      '${_monthShort[date.month - 1]} ${date.year} · '
      '$hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
}

class LiveClassDetailScreen extends ConsumerStatefulWidget {
  const LiveClassDetailScreen({
    super.key,
    required this.liveClassUuid,
  });

  final String liveClassUuid;

  @override
  ConsumerState<LiveClassDetailScreen> createState() =>
      _LiveClassDetailScreenState();
}

class _LiveClassDetailScreenState
    extends ConsumerState<LiveClassDetailScreen> {
  late Future<Map<String, dynamic>> _classData;
  Future<List<Map<String, dynamic>>>? _classMaterials;
  String? _materialsCourseUuid;

  Timer? _statusTimer;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _load();

    _statusTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) {
        if (mounted) {
          _pollClass();
        }
      },
    );
  }

  void _load() {
    _classMaterials = null;
    _materialsCourseUuid = null;

    _classData = ref
        .read(studentPortalRepositoryProvider)
        .liveClass(widget.liveClassUuid)
        .then((data) {
      final status = _text(data, 'status').toUpperCase();

      if (status == 'COMPLETED' || status == 'CANCELLED') {
        _statusTimer?.cancel();
      }

      return data;
    });
  }

  Future<void> _pollClass() async {
    if (_polling) return;

    _polling = true;

    try {
      final latest = await ref
          .read(studentPortalRepositoryProvider)
          .liveClass(widget.liveClassUuid);

      if (!mounted) return;

      final status = _text(latest, 'status').toUpperCase();

      if (status == 'COMPLETED' || status == 'CANCELLED') {
        _statusTimer?.cancel();
      }

      setState(() {
        _classData = Future.value(latest);
      });
    } on ApiException catch (error) {
      if (error.statusCode == 404 && mounted) {
        _statusTimer?.cancel();

        setState(() {
          _classData =
              Future<Map<String, dynamic>>.error(error);
        });
      }
    } catch (_) {
      // Keep the currently displayed class during a temporary network error.
    } finally {
      _polling = false;
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadClassMaterials(
    String courseUuid,
  ) {
    if (_classMaterials == null ||
        _materialsCourseUuid != courseUuid) {
      _materialsCourseUuid = courseUuid;

      _classMaterials = ref
          .read(studentPortalRepositoryProvider)
          .materials(courseUuid)
          .then(
            (items) => items
                .where(
                  (material) =>
                      material['live_class_uuid']?.toString() ==
                      widget.liveClassUuid,
                )
                .toList(),
          );
    }

    return _classMaterials!;
  }

  Future<void> _refresh() async {
    setState(_load);

    try {
      await _classData;
    } catch (_) {
      // FutureBuilder displays the API error.
    }
  }

  String _text(Map<String, dynamic> item, String key) {
    return item[key]?.toString().trim() ?? '';
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _classData,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return StudentPageFrame(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(kStudentPagePadding),
                children: [
                  StudentStateMessage(
                    icon: Icons.wifi_off_rounded,
                    title: 'Class could not load',
                    message: '${snapshot.error}',
                    actionLabel: 'Try again',
                    onAction: _refresh,
                    isError: true,
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 100),
                Center(child: CircularProgressIndicator()),
              ],
            );
          }

          final item = snapshot.data!;
          final status = _text(item, 'status').toUpperCase();
          final meetingUrl = _text(item, 'meeting_url');
          final meetingId = _text(item, 'meeting_id');
          final meetingPassword = _text(item, 'meeting_password');
          final title = _text(item, 'title');
          final teacher = _text(item, 'teacher_name');
          final course = _text(item, 'course_name');
          final start = _text(item, 'scheduled_start_at');
          final isLive = status == 'LIVE';

          final statusPill = switch (status) {
            'LIVE' => const TonalPill(
                label: 'Happening now',
                dot: true,
                background: Color(0xFFBA1A1A),
                foreground: Colors.white,
              ),
            'SCHEDULED' => TonalPill(
                label: 'Scheduled',
                icon: Icons.event_available_rounded,
                background: colors.warningBg,
                foreground: colors.warning,
              ),
            'COMPLETED' => TonalPill(
                label: 'Completed',
                icon: Icons.check_circle_outline_rounded,
                background: colors.successBg,
                foreground: colors.success,
              ),
            'CANCELLED' => TonalPill(
                label: 'Cancelled',
                background: colors.dangerBg,
                foreground: colors.danger,
              ),
            _ => TonalPill(label: status.isEmpty ? 'Unknown' : status),
          };

          final heroText = isLive ? Colors.white : colors.textPrimary;
          final heroMuted =
              isLive ? const Color(0xFFDAD7FF) : colors.textMuted;

          return StudentPageFrame(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                kStudentPagePadding,
                4,
                kStudentPagePadding,
                28,
              ),
              children: [
                // Hero
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: isLive ? colors.heroGradient : null,
                    color: isLive ? null : colors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: isLive
                        ? null
                        : Border.all(color: colors.borderSubtle),
                    boxShadow: isLive ? colors.heroShadow : colors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          statusPill,
                          if (course.isNotEmpty)
                            TonalPill(
                              label: course,
                              background: isLive
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : colors.primaryTonal,
                              foreground:
                                  isLive ? Colors.white : colors.primary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        title.isEmpty ? 'Live class' : title,
                        style: textTheme.headlineSmall?.copyWith(
                          color: heroText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: isLive
                                ? Colors.white.withValues(alpha: 0.2)
                                : colors.primaryDeep,
                            child: Text(
                              initialsOf(
                                teacher.isEmpty ? 'Teacher' : teacher,
                              ),
                              style: textTheme.labelLarge?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  teacher.isEmpty ? 'Not assigned' : teacher,
                                  style: textTheme.titleSmall?.copyWith(
                                    color: heroText,
                                  ),
                                ),
                                Text(
                                  'Teacher',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: heroMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (isLive && meetingUrl.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: colors.primaryDeep,
                                  minimumSize: const Size(0, 52),
                                ),
                                onPressed: () => openExternalLink(
                                  context,
                                  meetingUrl,
                                ),
                                icon: const Icon(Icons.videocam_rounded),
                                label: const Text('Join live class'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Tooltip(
                              message: 'Copy meeting link',
                              child: Material(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _copy(
                                    meetingUrl,
                                    'Meeting link',
                                  ),
                                  child: const SizedBox(
                                    width: 52,
                                    height: 52,
                                    child: Icon(
                                      Icons.link_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                PremiumCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.calendar_month_outlined,
                        label: 'Scheduled start',
                        value: start.isEmpty
                            ? 'Not scheduled'
                            : _prettyDateTime(start),
                      ),
                      _InfoRow(
                        icon: Icons.info_outline_rounded,
                        label: 'Status',
                        value: status.isEmpty
                            ? 'Unknown'
                            : status[0] + status.substring(1).toLowerCase(),
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
                if (_text(item, 'description').isNotEmpty) ...[
                  const SectionHeader(
                    title: 'About this class',
                    icon: Icons.notes_rounded,
                  ),
                  PremiumCard(
                    child: Text(
                      _text(item, 'description'),
                      style: textTheme.bodyLarge?.copyWith(height: 1.5),
                    ),
                  ),
                ],
                if (status == 'LIVE') ...[
                  if (meetingUrl.isEmpty)
                    _Note(
                      icon: Icons.hourglass_top_rounded,
                      text: 'This class is live, but the meeting link '
                          'is not available yet. Pull down to refresh.',
                      background: colors.warningBg,
                      foreground: colors.warning,
                    ),
                  if (meetingId.isNotEmpty || meetingPassword.isNotEmpty) ...[
                    const SectionHeader(
                      title: 'Meeting details',
                      icon: Icons.key_rounded,
                    ),
                    PremiumCard(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          if (meetingId.isNotEmpty)
                            _InfoRow(
                              icon: Icons.tag_rounded,
                              label: 'Meeting ID',
                              value: meetingId,
                              selectable: true,
                              showDivider: meetingPassword.isNotEmpty,
                              trailing: IconButton(
                                tooltip: 'Copy meeting ID',
                                onPressed: () => _copy(
                                  meetingId,
                                  'Meeting ID',
                                ),
                                icon: Icon(
                                  Icons.copy_rounded,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                          if (meetingPassword.isNotEmpty)
                            _InfoRow(
                              icon: Icons.lock_outline_rounded,
                              label: 'Meeting password',
                              value: meetingPassword,
                              selectable: true,
                              showDivider: false,
                              trailing: IconButton(
                                tooltip: 'Copy meeting password',
                                onPressed: () => _copy(
                                  meetingPassword,
                                  'Meeting password',
                                ),
                                icon: Icon(
                                  Icons.copy_rounded,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ] else if (status == 'SCHEDULED') ...[
                  _Note(
                    icon: Icons.notifications_active_outlined,
                    text: 'The meeting link will appear when the class '
                        'starts. Pull down to check for updates.',
                    background: colors.primaryTonal,
                    foreground: colors.primary,
                  ),
                ] else if (status == 'COMPLETED') ...[
                  _Note(
                    icon: Icons.check_circle_outline_rounded,
                    text: 'This live class has ended.',
                    background: colors.successBg,
                    foreground: colors.success,
                  ),
                  const SectionHeader(
                    title: 'Recordings & materials',
                    icon: Icons.video_library_outlined,
                  ),
                  if (_text(item, 'course_uuid').isEmpty)
                    const StudentStateMessage(
                      icon: Icons.folder_off_outlined,
                      title: 'Materials unavailable',
                      message: 'Class materials are unavailable.',
                    )
                  else
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _loadClassMaterials(
                        _text(item, 'course_uuid'),
                      ),
                      builder: (context, materialsSnapshot) {
                        if (materialsSnapshot.hasError) {
                          return StudentStateMessage(
                            icon: Icons.wifi_off_rounded,
                            title: 'Materials could not load',
                            message: '${materialsSnapshot.error}',
                            actionLabel: 'Try again',
                            onAction: () {
                              setState(() {
                                _classMaterials = null;
                              });
                            },
                            isError: true,
                          );
                        }

                        if (!materialsSnapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: LinearProgressIndicator(),
                          );
                        }

                        final materials = materialsSnapshot.data!;

                        if (materials.isEmpty) {
                          return const StudentStateMessage(
                            icon: Icons.video_library_outlined,
                            title: 'Nothing here yet',
                            message: 'No recording or material is available '
                                'for this class yet.',
                          );
                        }

                        return Column(
                          children: [
                            for (final material in materials)
                              PremiumCard(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                onTap: () {
                                  final uuid =
                                      material['uuid']?.toString() ?? '';

                                  if (uuid.isNotEmpty) {
                                    context.push('/student/materials/$uuid');
                                  }
                                },
                                child: Row(
                                  children: [
                                    IconTile(
                                      icon: material['material_type'] ==
                                              'VIDEO'
                                          ? Icons.play_circle_outline_rounded
                                          : Icons.description_outlined,
                                      size: 48,
                                      radius: 14,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            material['title']?.toString() ??
                                                'Class material',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            material['material_type']
                                                    ?.toString() ??
                                                'MATERIAL',
                                            style: textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: colors.textSubtle,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                ] else if (status == 'CANCELLED') ...[
                  _Note(
                    icon: Icons.event_busy_rounded,
                    text: 'This live class was cancelled.',
                    background: colors.dangerBg,
                    foreground: colors.danger,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.selectable = false,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final bool selectable;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final valueStyle = textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w500,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              IconTile(icon: icon, size: 40, radius: 12),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: textTheme.labelMedium),
                    const SizedBox(height: 2),
                    selectable
                        ? SelectableText(value, style: valueStyle)
                        : Text(value, style: valueStyle),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 70, right: 16),
            child: Divider(height: 1, color: colors.borderSubtle),
          ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
