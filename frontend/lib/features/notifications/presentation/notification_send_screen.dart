import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/user_role.dart';
import '../../../core/widgets/admin_ui.dart';
import '../data/notification_send_repository.dart';

class NotificationSendScreen extends ConsumerWidget {
  const NotificationSendScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);

    if (session.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!session.isAuthenticated ||
        (session.firmUuid ?? '').isEmpty ||
        (session.role != UserRole.academyAdmin &&
            session.role != UserRole.firmStaff)) {
      return const AdminStateMessage(
        icon: Icons.lock_outline,
        title: 'Sending unavailable',
        message:
            'Sign in as an academy admin or staff member linked to a firm.',
      );
    }

    return _SendForm(
      key: ValueKey('${session.userUuid}_${session.firmUuid}'),
    );
  }
}

class _SendForm extends ConsumerStatefulWidget {
  const _SendForm({super.key});

  @override
  ConsumerState<_SendForm> createState() => _SendFormState();
}

class _SendFormState extends ConsumerState<_SendForm> {
  final recipients = TextEditingController();
  final title = TextEditingController();
  final body = TextEditingController();

  String type = 'GENERAL';
  String? error;
  bool working = false;
  bool uncertain = false;
  int? sentCount;

  bool get editable =>
      !working && !uncertain && sentCount == null;

  @override
  void dispose() {
    recipients.dispose();
    title.dispose();
    body.dispose();
    super.dispose();
  }

  void reset() {
    if (working) return;

    setState(() {
      recipients.clear();
      title.clear();
      body.clear();
      type = 'GENERAL';
      error = null;
      sentCount = null;
      uncertain = false;
    });
  }

  Future<void> send() async {
    if (!editable) return;

    late List<String> ids;
    final heading = title.text.trim();
    final content = body.text.trim();
    final selectedType = type;

    try {
      ids = NotificationSendRepository.recipients(
        recipients.text,
      );

      if (heading.isEmpty ||
          heading.runes.length > 255 ||
          content.isEmpty) {
        throw const ApiException(
          'Enter a title of up to 255 characters and a message.',
        );
      }
    } on ApiException catch (e) {
      setState(() => error = e.message);
      return;
    }

    setState(() {
      working = true;
      error = null;
    });

    var submitted = false;

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
          title: const Text('Review notification'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${ids.length} recipients • '
                    '${NotificationSendRepository.types[selectedType]}',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    heading,
                    style:
                        Theme.of(dialogContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(content),
                  const SizedBox(height: 12),
                  const Text('Recipient user UUIDs'),
                  for (final id in ids) Text(id),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => close(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => close(dialogContext, true),
              child: const Text('Send'),
            ),
          ],
        ),
      );

      if (!mounted || confirmed != true) return;

      submitted = true;

      final count =
          await ref.read(notificationSendRepositoryProvider).send(
                userUuids: ids,
                type: selectedType,
                title: heading,
                body: content,
              );

      if (!mounted) return;
      setState(() => sentCount = count);
    } on NotificationDeliveryUnknown {
      if (mounted) {
        setState(() {
          uncertain = true;
          error =
              'Delivery could not be confirmed. Some recipients may '
              'already have received this message. Check delivery '
              'before starting a new message.';
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          uncertain = submitted;
          error = submitted
              ? 'Delivery could not be confirmed. Check delivery '
                  'before starting a new message.'
              : 'Could not open the review. Please retry.';
        });
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  void back() {
    if (working) return;

    if (context.canPop()) {
      context.pop(sentCount != null);
    } else {
      context.go('/notifications');
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !working,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: working ? null : back,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Notifications'),
              ),
            ),
            const AdminPageHeader(
              title: 'Send Notification',
              subtitle: 'Create an inbox message for academy users.',
            ),
            const SizedBox(height: 20),
            if (sentCount != null)
              AdminCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notification created for $sentCount users.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(title.text.trim()),
                    const SizedBox(height: 12),
                    const Text(
                      'Recipients can view it in their inbox. '
                      'Device push delivery is separate.',
                    ),
                    const SizedBox(height: 16),
                    GradientButton(
                      label: 'New message',
                      onPressed: working ? null : reset,
                    ),
                  ],
                ),
              )
            else
              AdminCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FieldLabel(
                      label: 'Recipient user UUIDs',
                      required: true,
                      child: TextField(
                        controller: recipients,
                        enabled: editable,
                        minLines: 3,
                        maxLines: 6,
                        decoration: adminFieldDecoration(
                          context,
                          hint: 'Paste user UUIDs, one per line',
                          helper:
                              '1–500 unique users. Use user UUIDs, '
                              'not student UUIDs.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FieldLabel(
                      label: 'Type',
                      required: true,
                      child: DropdownButtonFormField<String>(
                        value: type,
                        isExpanded: true,
                        decoration: adminFieldDecoration(context),
                        items: [
                          for (final entry
                              in NotificationSendRepository.types.entries)
                            DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                        ],
                        onChanged: editable
                            ? (value) {
                                if (value != null) {
                                  setState(() => type = value);
                                }
                              }
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FieldLabel(
                      label: 'Title',
                      required: true,
                      child: TextField(
                        controller: title,
                        enabled: editable,
                        maxLength: 255,
                        decoration: adminFieldDecoration(
                          context,
                          hint: 'Notification title',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FieldLabel(
                      label: 'Message',
                      required: true,
                      child: TextField(
                        controller: body,
                        enabled: editable,
                        minLines: 4,
                        maxLines: 10,
                        decoration: adminFieldDecoration(
                          context,
                          hint: 'Write your message',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GradientButton(
                        label: 'Review & send',
                        icon: Icons.send_outlined,
                        loading: working,
                        onPressed: editable ? send : null,
                      ),
                    ),
                  ],
                ),
              ),
            if (error != null) ...[
              const SizedBox(height: 16),
              AdminErrorBanner(message: error!),
            ],
            if (uncertain) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: AdminOutlineButton(
                  label: 'Start a new message',
                  onPressed: working ? null : reset,
                ),
              ),
            ],
          ],
        ),
      );
}
