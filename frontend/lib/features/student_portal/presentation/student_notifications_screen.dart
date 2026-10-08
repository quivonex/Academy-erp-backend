import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/user_role.dart';
import '../../notifications/data/notification_repository.dart';

class StudentNotificationsScreen extends ConsumerWidget {
  const StudentNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);

    if (session.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!session.isAuthenticated ||
        session.role != UserRole.student ||
        (session.firmUuid ?? '').isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Sign in with your student account to view notifications.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return _StudentInbox(
      key: ValueKey('${session.userUuid}_${session.firmUuid}'),
    );
  }
}

class _StudentInbox extends ConsumerStatefulWidget {
  const _StudentInbox({super.key});

  @override
  ConsumerState<_StudentInbox> createState() => _StudentInboxState();
}

class _StudentInboxState extends ConsumerState<_StudentInbox> {
  static const _types = <String, String>{
    'GENERAL': 'General',
    'COURSE_ACCESS': 'Course access',
    'ASSIGNMENT': 'Assignment',
    'LIVE_CLASS': 'Live class',
    'MATERIAL': 'Material',
    'PAYMENT': 'Payment',
    'RESULT': 'Result',
  };

  NotificationPage? _result;
  int? _unreadCount;

  int _page = 1;
  int _revision = 0;

  String _type = 'ALL';
  bool _unreadOnly = true;

  bool _loading = false;
  bool _working = false;

  String? _listError;
  String? _countError;
  String? _actionError;

  bool get _busy => _loading || _working;

  NotificationRepository get _repository =>
      ref.read(notificationRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _errorMessage(Object error) {
    if (error is ApiException) return error.message;
    return 'Could not complete this request. Please retry.';
  }

  Future<void> _load() async {
    final ticket = ++_revision;
    final requestedPage = _page;
    final requestedType = _type;
    final requestedUnread = _unreadOnly;

    bool current() => mounted && ticket == _revision;

    setState(() {
      _loading = true;
      _result = null;
      _unreadCount = null;
      _listError = null;
      _countError = null;
    });

    Future<void> loadList() async {
      try {
        final result = await _repository.list(
          page: requestedPage,
          unread: requestedUnread,
          type: requestedType == 'ALL' ? null : requestedType,
        );
        if (!current()) return;
        setState(() {
          _result = result;
          _page = result.page;
        });
      } catch (error) {
        if (current()) {
          setState(() => _listError = _errorMessage(error));
        }
      }
    }

    Future<void> loadCount() async {
      try {
        final count = await _repository.unreadCount();
        if (current()) {
          setState(() => _unreadCount = count);
        }
      } catch (error) {
        if (current()) {
          setState(() => _countError = _errorMessage(error));
        }
      }
    }

    await Future.wait([loadList(), loadCount()]);

    if (current()) {
      setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _actionError = null);
    await _load();
  }

  void _changeFilter({String? type, bool? unreadOnly}) {
    if (_busy) return;
    setState(() {
      _type = type ?? _type;
      _unreadOnly = unreadOnly ?? _unreadOnly;
      _page = 1;
      _actionError = null;
    });
    _load();
  }

  void _changePage(int page) {
    if (_busy || page < 1) return;
    setState(() {
      _page = page;
      _actionError = null;
    });
    _load();
  }

  Future<void> _markRead(InboxNotification item) async {
    if (_busy || item.isRead) return;
    setState(() {
      _working = true;
      _actionError = null;
    });

    try {
      await _repository.markRead(item.uuid);
      if (!mounted) return;
      if (_unreadOnly) setState(() => _page = 1);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification marked as read.')),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _actionError = _errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_busy || _unreadCount == null || _unreadCount == 0) return;

    setState(() {
      _working = true;
      _actionError = null;
    });

    try {
      var resolved = false;
      void closeDialog(BuildContext dialogContext, bool result) {
        if (resolved) return;
        resolved = true;
        Navigator.of(dialogContext).pop(result);
      }

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Mark all notifications as read?'),
          content: const Text(
            'This marks your entire inbox as read, '
                'including other pages and notification types.',
          ),
          actions: [
            TextButton(
              onPressed: () => closeDialog(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => closeDialog(dialogContext, true),
              child: const Text('Mark all read'),
            ),
          ],
        ),
      );

      if (!mounted || confirmed != true) return;

      final count = await _repository.markAllRead();
      if (!mounted) return;

      setState(() => _page = 1);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count notifications marked as read.')),
      );

      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _actionError = _errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'COURSE_ACCESS':
        return Icons.school_outlined;
      case 'ASSIGNMENT':
        return Icons.assignment_outlined;
      case 'LIVE_CLASS':
        return Icons.video_camera_front_outlined;
      case 'MATERIAL':
        return Icons.menu_book_outlined;
      case 'PAYMENT':
        return Icons.receipt_long_outlined;
      case 'RESULT':
        return Icons.assessment_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _date(DateTime? value) {
    if (value == null) return 'Date unavailable';
    final date = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  Widget _errorCard(String message) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: colors.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _viewNotification(InboxNotification item) async {
    if (_busy) return;
    setState(() {
      _working = true;
      _actionError = null;
    });

    try {
      var closed = false;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(item.title),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _types[item.type] ?? item.type,
                    style: Theme.of(dialogContext).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _date(item.createdAt),
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  SelectableText(item.body),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                if (closed) return;
                closed = true;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Close'),
            ),
          ],
        ),
      );

      if (!mounted || item.isRead) return;
      await _repository.markRead(item.uuid);
      if (!mounted) return;
      setState(() => _page = 1);
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _actionError = _errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Widget _notificationCard(InboxNotification item) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _busy ? null : () => _viewNotification(item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: item.isRead
                        ? colors.surfaceContainerHighest
                        : colors.primaryContainer,
                    child: Icon(
                      _typeIcon(item.type),
                      color: item.isRead
                          ? colors.onSurfaceVariant
                          : colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: item.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _types[item.type] ?? item.type,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.isRead ? 'Read' : 'Unread',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: item.isRead
                          ? colors.onSurfaceVariant
                          : colors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _date(item.createdAt),
                style: theme.textTheme.bodySmall,
              ),
              if (item.isRead && item.readAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Read at ${_date(item.readAt)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _viewNotification(item),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('View'),
                  ),
                  if (!item.isRead)
                    TextButton.icon(
                      onPressed: _busy ? null : () => _markRead(item),
                      icon: const Icon(Icons.done_rounded),
                      label: const Text('Mark read'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HERO CARD — extracted so it can be placed OUTSIDE the scrollable list
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildHeroCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3525CD), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x263525CD),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Unread in your inbox: ${_unreadCount ?? '…'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
          if (_countError != null) ...[
            const SizedBox(height: 12),
            _errorCard(_countError!),
          ],
          const SizedBox(height: 18),
          const Text(
            'NOTIFICATION TYPE',
            style: TextStyle(
              color: Color(0xFFB7B3FF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _type,
                isExpanded: true,
                isDense: true,
                borderRadius: BorderRadius.circular(12),
                dropdownColor: Colors.white,
                icon: const Icon(
                  Icons.expand_more_rounded,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'ALL',
                    child: Text('All types'),
                  ),
                  for (final entry in _types.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) {
                  if (value != null) _changeFilter(type: value);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Unread only',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.9,
                child: Switch(
                  value: _unreadOnly,
                  onChanged: _busy
                      ? null
                      : (value) => _changeFilter(unreadOnly: value),
                  activeThumbColor: Colors.white,
                  activeTrackColor: Colors.white.withValues(alpha: 0.45),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.28),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: _busy ? null : _refresh,
                    child: const Text(
                      'Filter list',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF3525CD),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    onPressed: _busy ||
                        _unreadCount == null ||
                        _unreadCount == 0
                        ? null
                        : _markAllRead,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Color(0xFF3525CD),
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Mark all\nread',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3525CD),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;
    final totalPages = result == null || result.count == 0
        ? 1
        : (result.count / 20).ceil();

    return PopScope(
      canPop: !_working,
      child: Column(
        // ── Outer column: static hero + scrollable list ──
        children: [
          // ── HERO CARD (STATIC, does NOT scroll) ──
          _buildHeroCard(),

          // ── SCROLLABLE AREA (title + notifications + pagination) ──
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Text(
                    'Your notifications',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Course updates, assignments, results '
                        'and academy announcements.',
                  ),
                  const SizedBox(height: 16),

                  if (_working) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                  ],
                  if (_actionError != null) ...[
                    _errorCard(_actionError!),
                    const SizedBox(height: 12),
                  ],
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_listError != null) ...[
                    _errorCard(_listError!),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _busy ? null : _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ),
                    if (_page > 1)
                      TextButton(
                        onPressed: _busy ? null : () => _changePage(1),
                        child: const Text('Return to first page'),
                      ),
                  ],
                  if (result != null) ...[
                    if (result.items.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.notifications_none_rounded,
                                size: 48,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No notifications match these filters.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    for (final item in result.items)
                      _notificationCard(item),
                    const SizedBox(height: 8),
                    Text(
                      '${result.count} notifications',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Previous page',
                          onPressed: _busy || _page <= 1
                              ? null
                              : () => _changePage(_page - 1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            'Page $_page of $totalPages',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next page',
                          onPressed: _busy || _page >= totalPages
                              ? null
                              : () => _changePage(_page + 1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}