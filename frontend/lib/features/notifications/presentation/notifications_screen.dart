import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/user_role.dart';
import '../../../core/widgets/admin_ui.dart';
import '../data/notification_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);

    if (session.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!session.isAuthenticated ||
        (session.firmUuid ?? '').isEmpty) {
      return const AdminStateMessage(
        icon: Icons.lock_outline,
        title: 'Inbox unavailable',
        message:
            'Sign in with an academy account to view your inbox.',
      );
    }

    return _Inbox(
      key: ValueKey('${session.userUuid}_${session.firmUuid}'),
    );
  }
}

class _Inbox extends ConsumerStatefulWidget {
  const _Inbox({super.key});

  @override
  ConsumerState<_Inbox> createState() => _InboxState();
}

class _InboxState extends ConsumerState<_Inbox> {
  static const types = <String, String>{
    'GENERAL': 'General',
    'COURSE_ACCESS': 'Course access',
    'ASSIGNMENT': 'Assignment',
    'LIVE_CLASS': 'Live class',
    'MATERIAL': 'Material',
    'PAYMENT': 'Payment',
    'RESULT': 'Result',
  };

  NotificationPage? result;
  int? unreadCount;

  int page = 1;
  int revision = 0;
  bool unreadOnly = false;
  String type = 'ALL';

  bool loading = false;
  bool working = false;

  String? listError;
  String? countError;
  String? actionError;

  bool get busy => loading || working;

  NotificationRepository get repo =>
      ref.read(notificationRepositoryProvider);

  @override
  void initState() {
    super.initState();
    load();
  }

  String message(Object error) => error is ApiException
      ? error.message
      : 'Could not complete this request. Please retry.';

  Future<void> load() async {
    final ticket = ++revision;
    final requestedPage = page;
    final requestedType = type;
    final requestedUnread = unreadOnly;

    bool current() => mounted && revision == ticket;

    setState(() {
      loading = true;
      listError = countError = null;
      result = null;
      unreadCount = null;
    });

    Future<void> rows() async {
      try {
        final value = await repo.list(
          page: requestedPage,
          unread: requestedUnread,
          type: requestedType == 'ALL' ? null : requestedType,
        );

        if (current()) {
          setState(() {
            result = value;
            page = value.page;
          });
        }
      } catch (e) {
        if (current()) setState(() => listError = message(e));
      }
    }

    Future<void> counter() async {
      try {
        final value = await repo.unreadCount();
        if (current()) setState(() => unreadCount = value);
      } catch (e) {
        if (current()) setState(() => countError = message(e));
      }
    }

    await Future.wait([rows(), counter()]);

    if (current()) setState(() => loading = false);
  }

  Future<void> markRead(InboxNotification item) async {
    if (busy || item.isRead) return;

    setState(() {
      working = true;
      actionError = null;
    });

    try {
      await repo.markRead(item.uuid);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification marked as read.'),
        ),
      );

      await load();
    } catch (e) {
      if (mounted) setState(() => actionError = message(e));
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> markAll() async {
    if (busy || unreadCount == null || unreadCount == 0) return;

    setState(() {
      working = true;
      actionError = null;
    });

    try {
      var resolved = false;

      void close(BuildContext dialogContext, bool value) {
        if (resolved) return;
        resolved = true;
        Navigator.pop(dialogContext, value);
      }

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Mark entire inbox as read?'),
          content: const Text(
            'This marks all unread notifications in your inbox '
            'as read, including other pages and types.',
          ),
          actions: [
            TextButton(
              onPressed: () => close(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => close(dialogContext, true),
              child: const Text('Mark all read'),
            ),
          ],
        ),
      );

      if (!mounted || confirmed != true) return;

      final count = await repo.markAllRead();
      if (!mounted) return;

      setState(() => page = 1);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count notifications marked as read.'),
        ),
      );

      await load();
    } catch (e) {
      if (mounted) setState(() => actionError = message(e));
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  void filter({String? nextType, bool? nextUnread}) {
    if (working) return;

    setState(() {
      type = nextType ?? type;
      unreadOnly = nextUnread ?? unreadOnly;
      page = 1;
      actionError = null;
    });

    load();
  }

  Widget card(InboxNotification item) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    item.isRead
                        ? Icons.notifications_none
                        : Icons.notifications_active_outlined,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(item.isRead ? 'Read' : 'Unread'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${types[item.type] ?? item.type} • '
                '${_notificationDate(item.createdAt)}',
              ),
              const SizedBox(height: 12),
              SelectableText(item.body),
              if (item.isRead && item.readAt != null) ...[
                const SizedBox(height: 8),
                Text('Read at ${_notificationDate(item.readAt)}'),
              ],
              if (!item.isRead)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: busy ? null : () => markRead(item),
                    icon: const Icon(Icons.done),
                    label: const Text('Mark read'),
                  ),
                ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !working,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            AdminPageHeader(
              title: 'Notifications',
              subtitle: 'Your academy account inbox.',
              actions: [
                AdminOutlineButton(
                  label: 'Device registration',
                  icon: Icons.devices_outlined,
                  onPressed: busy
                      ? null
                      : () => context.push('/notifications/devices'),
                ),
                if (ref.watch(sessionControllerProvider).role ==
                        UserRole.academyAdmin ||
                    ref.watch(sessionControllerProvider).role ==
                        UserRole.firmStaff)
                  AdminOutlineButton(
                    label: 'Send notification',
                    icon: Icons.send_outlined,
                    onPressed: busy
                        ? null
                        : () async {
                            final sent = await context.push<bool>(
                              '/notifications/send',
                            );

                            if (sent == true && mounted) {
                              load();
                            }
                          },
                  ),
                AdminOutlineButton(
                  label: 'Refresh',
                  icon: Icons.refresh,
                  onPressed: busy
                      ? null
                      : () {
                          setState(() => actionError = null);
                          load();
                        },
                ),
                GradientButton(
                  label: 'Mark all read',
                  icon: Icons.done_all,
                  loading: working,
                  onPressed:
                      busy || unreadCount == null || unreadCount == 0
                          ? null
                          : markAll,
                ),
              ],
            ),
            const SizedBox(height: 20),
            AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Unread in entire inbox: ${unreadCount ?? '…'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (countError != null) ...[
                    const SizedBox(height: 8),
                    AdminErrorBanner(message: countError!),
                    TextButton(
                      onPressed: busy ? null : load,
                      child: const Text('Retry unread count'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: type,
                    isExpanded: true,
                    decoration: adminFieldDecoration(
                      context,
                      hint: 'Notification type',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'ALL',
                        child: Text('All types'),
                      ),
                      for (final entry in types.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: working
                        ? null
                        : (value) {
                            if (value != null) {
                              filter(nextType: value);
                            }
                          },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Unread only'),
                    value: unreadOnly,
                    onChanged: working
                        ? null
                        : (value) => filter(nextUnread: value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (actionError != null) ...[
              AdminErrorBanner(message: actionError!),
              const SizedBox(height: 12),
            ],
            if (loading) const LinearProgressIndicator(),
            if (listError != null)
              AdminStateMessage(
                icon: Icons.error_outline,
                title: 'Could not load notifications',
                message: listError!,
                actionLabel: 'Retry',
                onAction: busy ? null : load,
                isError: true,
              ),
            if (result != null) ...[
              if (result!.items.isEmpty)
                const AdminStateMessage(
                  icon: Icons.notifications_none,
                  title: 'No notifications',
                  message:
                      'There are no notifications matching these filters.',
                ),
              for (final item in result!.items) card(item),
              IgnorePointer(
                ignoring: busy,
                child: AdminPager(
                  page: page,
                  pageSize: 20,
                  total: result!.count,
                  noun: 'notifications',
                  onPage: (value) {
                    if (busy) return;
                    setState(() => page = value);
                    load();
                  },
                ),
              ),
            ],
          ],
        ),
      );
}

String _notificationDate(DateTime? value) {
  if (value == null) return 'Date unavailable';

  final d = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');

  return '${two(d.day)}/${two(d.month)}/${d.year} '
      '${two(d.hour)}:${two(d.minute)}';
}
