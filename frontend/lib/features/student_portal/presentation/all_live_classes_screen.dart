import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/student_portal_repository.dart';
import 'widgets/student_ui.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _text(Map<String, dynamic> item, String key) =>
    item[key]?.toString().trim() ?? '';

DateTime? _start(Map<String, dynamic> item) {
  final raw = _text(item, 'scheduled_start_at');
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

String _clock(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
}

/// "Today", "Tomorrow", "Yesterday" or "Thu, 20 Oct".
String _relativeDay(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return '${_weekdays[date.weekday - 1]}, '
      '${date.day} ${_monthNames[date.month - 1]}';
}

class AllLiveClassesScreen extends ConsumerStatefulWidget {
  const AllLiveClassesScreen({super.key});

  @override
  ConsumerState<AllLiveClassesScreen> createState() =>
      _AllLiveClassesScreenState();
}

class _AllLiveClassesScreenState extends ConsumerState<AllLiveClassesScreen> {
  final List<Map<String, dynamic>> _classes = [];

  String? _selectedStatus;
  String? _error;

  int _page = 1;
  int _requestId = 0;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (!reset && (_loadingMore || !_hasMore)) {
      return;
    }

    final requestId = ++_requestId;
    final nextPage = reset ? 1 : _page + 1;

    setState(() {
      _error = null;

      if (reset) {
        _classes.clear();
        _loading = true;
        _loadingMore = false;
        _hasMore = true;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final result = await ref
          .read(studentPortalRepositoryProvider)
          .allLiveClasses(
            status: _selectedStatus,
            page: nextPage,
          );

      if (!mounted || requestId != _requestId) {
        return;
      }

      setState(() {
        _classes.addAll(result.items);
        _page = nextPage;
        _hasMore = result.hasNext;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) {
        return;
      }

      setState(() {
        _error = error.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    String status(Map<String, dynamic> item) =>
        _text(item, 'status').toUpperCase();

    final live = _classes.where((i) => status(i) == 'LIVE').toList();
    final scheduled =
        _classes.where((i) => status(i) == 'SCHEDULED').toList();
    final completed =
        _classes.where((i) => status(i) == 'COMPLETED').toList();
    final other = _classes
        .where((i) =>
            !const {'LIVE', 'SCHEDULED', 'COMPLETED'}.contains(status(i)))
        .toList();

    void open(Map<String, dynamic> item) {
      final uuid = item['uuid']?.toString();
      if (uuid != null && uuid.isNotEmpty) {
        context.push('/student/live-classes/$uuid');
      }
    }

    String countOf(List<Map<String, dynamic>> list) =>
        '${list.length}${_hasMore ? '+' : ''}';

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: StudentPageFrame(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            kStudentPagePadding,
            4,
            kStudentPagePadding,
            24,
          ),
          children: [
            Text(
              'Interactive sessions for your enrolled courses.',
              style: textTheme.bodyLarge?.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  _statusChip('All', null),
                  _statusChip('Live now', 'LIVE', dot: colors.danger),
                  _statusChip('Scheduled', 'SCHEDULED'),
                  _statusChip('Completed', 'COMPLETED'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_loading)
              const StudentLoading()
            else if (_error != null && _classes.isEmpty)
              StudentStateMessage(
                icon: Icons.wifi_off_rounded,
                title: 'Classes could not load',
                message: _error!,
                actionLabel: 'Try again',
                onAction: () => _load(reset: true),
                isError: true,
              )
            else if (_classes.isEmpty)
              StudentStateMessage(
                icon: Icons.event_busy_rounded,
                title: 'No classes here',
                message: _selectedStatus == null
                    ? 'Classes for your enrolled courses will show up here.'
                    : 'No classes found for this filter.',
              )
            else ...[
              for (final item in live)
                _LiveNowCard(item: item, onOpen: () => open(item)),
              if (scheduled.isNotEmpty) ...[
                SectionHeader(
                  title: 'Upcoming classes',
                  icon: Icons.event_available_rounded,
                  trailing: TonalPill(label: '${countOf(scheduled)} scheduled'),
                ),
                for (final item in scheduled)
                  _ClassCard(item: item, onOpen: () => open(item)),
              ],
              if (completed.isNotEmpty) ...[
                SectionHeader(
                  title: 'Completed classes',
                  icon: Icons.history_rounded,
                  trailing: TonalPill(
                    label: '${countOf(completed)} done',
                    background: colors.successBg,
                    foreground: colors.success,
                  ),
                ),
                for (final item in completed)
                  _ClassCard(item: item, onOpen: () => open(item)),
              ],
              if (other.isNotEmpty) ...[
                const SectionHeader(
                  title: 'Other classes',
                  icon: Icons.video_library_outlined,
                ),
                for (final item in other)
                  _ClassCard(item: item, onOpen: () => open(item)),
              ],
              if (_error != null)
                InlineError(message: 'Could not load more: $_error'),
              if (_hasMore)
                LoadMoreButton(
                  label: 'Load more classes',
                  loading: _loadingMore,
                  onPressed: () => _load(reset: false),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusChip(
    String label,
    String? status, {
    Color? dot,
  }) {
    return FilterPill(
      label: label,
      selected: _selectedStatus == status,
      leadingDot: dot,
      onTap: () {
        _selectedStatus = status;
        _load(reset: true);
      },
    );
  }
}

class _LiveNowCard extends StatelessWidget {
  const _LiveNowCard({required this.item, required this.onOpen});

  final Map<String, dynamic> item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final course = _text(item, 'course_name');
    final teacher = _text(item, 'teacher_name');
    final title = _text(item, 'title');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: colors.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: colors.heroShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TonalPill(
            label: 'Happening now',
            dot: true,
            background: Color(0xFFBA1A1A),
            foreground: Colors.white,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.podcasts_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (course.isNotEmpty)
                      Text(
                        course,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelMedium?.copyWith(
                          color: const Color(0xFFDAD7FF),
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      title.isEmpty ? 'Live class' : title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (teacher.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded,
                              size: 16, color: Color(0xFFDAD7FF)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              teacher,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFDAD7FF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: colors.primaryDeep,
              ),
              onPressed: onOpen,
              icon: const Icon(Icons.videocam_rounded),
              label: const Text('Open classroom'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.item, required this.onOpen});

  final Map<String, dynamic> item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    final start = _start(item);
    final course = _text(item, 'course_name');
    final teacher = _text(item, 'teacher_name');
    final title = _text(item, 'title');
    final description = _text(item, 'description');
    final status = _text(item, 'status').toUpperCase();
    final isCompleted = status == 'COMPLETED';
    final isCancelled = status == 'CANCELLED';

    final when = start == null
        ? (_text(item, 'scheduled_start_at').isEmpty
            ? 'Time not set'
            : _text(item, 'scheduled_start_at'))
        : '${_relativeDay(start)}, ${_clock(start)}';

    return PremiumCard(
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (course.isNotEmpty)
                Flexible(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TonalPill(
                      label: course,
                      dot: true,
                      background: isCompleted
                          ? colors.successBg
                          : colors.primaryTonal,
                      foreground:
                          isCompleted ? colors.success : colors.primary,
                    ),
                  ),
                )
              else
                const Spacer(flex: 3),
              const SizedBox(width: 8),
              TonalPill(
                label: when,
                icon: Icons.schedule_rounded,
                background: isCompleted || isCancelled
                    ? const Color(0xFFF1F2F8)
                    : colors.warningBg,
                foreground: isCompleted || isCancelled
                    ? colors.textMuted
                    : colors.warning,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title.isEmpty ? 'Live class' : title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
            ),
          ],
          const SizedBox(height: 14),
          Divider(height: 1, color: colors.borderSubtle),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    isCompleted ? colors.success : colors.primaryDeep,
                child: Text(
                  initialsOf(teacher.isEmpty ? 'Class' : teacher),
                  style: textTheme.labelLarge?.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher.isEmpty ? 'Academy faculty' : teacher,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall,
                    ),
                    Text(
                      start == null
                          ? 'Instructor'
                          : 'Starts ${_clock(start)}',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (isCompleted)
                TonalPill(
                  label: 'Completed',
                  icon: Icons.check_circle_outline_rounded,
                  background: colors.successBg,
                  foreground: colors.success,
                )
              else if (isCancelled)
                TonalPill(
                  label: 'Cancelled',
                  background: colors.dangerBg,
                  foreground: colors.danger,
                )
              else
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: onOpen,
                  child: const Text('View details'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
