import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/widgets/admin_ui.dart';
import '../data/device_notification_repository.dart';

class DeviceNotificationScreen extends ConsumerWidget {
  const DeviceNotificationScreen({super.key});

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
        title: 'Device registration unavailable',
        message:
            'Sign in with an academy account to manage device registration.',
      );
    }

    return _DeviceForm(
      key: ValueKey('${session.userUuid}_${session.firmUuid}'),
    );
  }
}

class _DeviceForm extends ConsumerStatefulWidget {
  const _DeviceForm({super.key});

  @override
  ConsumerState<_DeviceForm> createState() =>
      _DeviceFormState();
}

class _DeviceFormState extends ConsumerState<_DeviceForm> {
  final token = TextEditingController();
  final deviceId = TextEditingController();

  String platform = 'WEB';
  bool working = false;
  bool revealToken = false;
  String? error;
  String? outcome;
  DeviceRegistration? registration;

  @override
  void dispose() {
    token.dispose();
    deviceId.dispose();
    super.dispose();
  }

  void edited() => setState(() {
        error = outcome = null;
        registration = null;
      });

  Future<void> submit(bool register) async {
    if (working) return;

    late String selectedToken;
    final selectedPlatform = platform;
    final selectedId = deviceId.text.trim();

    try {
      selectedToken =
          DeviceNotificationRepository.validatedToken(
        token.text,
      );

      if (register && selectedId.runes.length > 255) {
        throw const ApiException(
          'Device ID must be at most 255 characters.',
        );
      }
    } on ApiException catch (e) {
      setState(() => error = e.message);
      return;
    }

    setState(() {
      working = true;
      error = outcome = null;
      registration = null;
    });

    try {
      if (!register) {
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
            title: const Text('Unregister device token?'),
            content: const Text(
              'This deactivates the entered token for your '
              'current account. Your inbox messages remain available.',
            ),
            actions: [
              TextButton(
                onPressed: () => close(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => close(dialogContext, true),
                child: const Text('Unregister'),
              ),
            ],
          ),
        );

        if (!mounted || confirmed != true) return;
      }

      final repo = ref.read(
        deviceNotificationRepositoryProvider,
      );

      if (register) {
        final value = await repo.register(
          token: selectedToken,
          platform: selectedPlatform,
          deviceId: selectedId,
        );

        if (!mounted) return;

        setState(() {
          registration = value;
          outcome = 'Device token registered for your account.';
        });
      } else {
        final count = await repo.unregister(selectedToken);

        if (!mounted) return;

        setState(() {
          outcome = count == 0
              ? 'No active registration for this token '
                  'was found in your account.'
              : '$count device registration deactivated.';
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          error =
              'Could not confirm the result. You can retry '
              'the same action with the same token.';
        });
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  void back() {
    if (working) return;

    if (context.canPop()) {
      context.pop();
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
              title: 'Device Registration',
              subtitle:
                  'Register or deactivate a notification token '
                  'for your account.',
            ),
            const SizedBox(height: 20),
            AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Paste a real Firebase Messaging device token. '
                    'Registration alone does not enable push delivery.',
                  ),
                  const SizedBox(height: 16),
                  FieldLabel(
                    label: 'Device token',
                    required: true,
                    child: TextField(
                      controller: token,
                      enabled: !working,
                      obscureText: !revealToken,
                      autocorrect: false,
                      enableSuggestions: false,
                      onChanged: (_) => edited(),
                      decoration: adminFieldDecoration(
                        context,
                        hint: 'Paste device token',
                        suffix: IconButton(
                          tooltip:
                              revealToken ? 'Hide token' : 'Show token',
                          onPressed: working
                              ? null
                              : () => setState(
                                    () => revealToken = !revealToken,
                                  ),
                          icon: Icon(
                            revealToken
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FieldLabel(
                    label: 'Platform',
                    required: true,
                    child: DropdownButtonFormField<String>(
                      value: platform,
                      isExpanded: true,
                      decoration: adminFieldDecoration(context),
                      items: [
                        for (final value
                            in DeviceNotificationRepository.platforms)
                          DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                      ],
                      onChanged: working
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() {
                                  platform = value;
                                  error = outcome = null;
                                  registration = null;
                                });
                              }
                            },
                    ),
                  ),
                  const SizedBox(height: 16),
                  FieldLabel(
                    label: 'Device ID (optional)',
                    child: TextField(
                      controller: deviceId,
                      enabled: !working,
                      maxLength: 255,
                      onChanged: (_) => edited(),
                      decoration: adminFieldDecoration(
                        context,
                        hint: 'Device identifier',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      GradientButton(
                        label: 'Register token',
                        icon: Icons.devices_outlined,
                        loading: working,
                        onPressed:
                            working ? null : () => submit(true),
                      ),
                      AdminOutlineButton(
                        label: 'Unregister token',
                        icon: Icons.link_off_outlined,
                        onPressed:
                            working ? null : () => submit(false),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              AdminErrorBanner(message: error!),
            ],
            if (outcome != null) ...[
              const SizedBox(height: 16),
              AdminCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      outcome!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (registration != null) ...[
                      const SizedBox(height: 8),
                      Text('Platform: ${registration!.platform}'),
                      Text(
                        'Updated: '
                        '${registration!.lastSeenAt?.toLocal().toString() ?? 'Unavailable'}',
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Text(
                      'This shows the result of your last action '
                      'on this screen.',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
}
