import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/status_pill.dart';
import '../data/live_class.dart';
import '../data/live_class_repository.dart';

enum _ClassAction { start, complete, cancel }

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
  late Future<LiveClass> result;
  bool busy = false;
  int revision = 0;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(covariant LiveClassDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.liveClassUuid != widget.liveClassUuid) {
      revision++;
      reload();
    }
  }

  void reload() {
    result = ref
        .read(liveClassRepositoryProvider)
        .detail(widget.liveClassUuid);
  }

  void refresh() {
    if (!busy) setState(reload);
  }

  void message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> edit(LiveClass liveClass) async {
    if (busy ||
        !['SCHEDULED', 'LIVE'].contains(liveClass.status)) {
      return;
    }

    final currentRevision = revision;
    setState(() => busy = true);

    try {
      final updated = await showDialog<LiveClass>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _EditLiveClassDialog(
          liveClass: liveClass,
        ),
      );

      if (!mounted ||
          currentRevision != revision ||
          updated == null) {
        return;
      }

      setState(() => result = Future.value(updated));
      message('Live class updated successfully.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> perform(
      LiveClass liveClass,
      _ClassAction action,
      ) async {
    if (busy) return;

    final allowed = switch (action) {
      _ClassAction.start =>
      liveClass.status == 'SCHEDULED',
      _ClassAction.complete =>
      liveClass.status == 'LIVE',
      _ClassAction.cancel =>
          ['SCHEDULED', 'LIVE'].contains(liveClass.status),
    };

    if (!allowed) return;

    final currentRevision = revision;
    setState(() => busy = true);

    try {
      if (action == _ClassAction.cancel) {
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Cancel live class'),
            content: const Text(
              'Are you sure you want to cancel this class?',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(false),
                child: const Text('Keep class'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(true),
                child: const Text('Cancel class'),
              ),
            ],
          ),
        );

        if (!mounted ||
            currentRevision != revision ||
            confirmed != true) {
          return;
        }
      }

      final repository =
      ref.read(liveClassRepositoryProvider);

      final updated = await (switch (action) {
        _ClassAction.start =>
            repository.start(liveClass.uuid),
        _ClassAction.complete =>
            repository.complete(liveClass.uuid),
        _ClassAction.cancel =>
            repository.cancel(liveClass.uuid),
      });

      if (!mounted || currentRevision != revision) return;

      setState(() => result = Future.value(updated));

      message(switch (action) {
        _ClassAction.start =>
        'Live class started successfully.',
        _ClassAction.complete =>
        'Live class completed successfully.',
        _ClassAction.cancel =>
        'Live class cancelled successfully.',
      });
    } on ApiException catch (e) {
      if (mounted && currentRevision == revision) {
        message(e.message);
        setState(reload);
      }
    } catch (_) {
      if (mounted && currentRevision == revision) {
        message(
          'Could not update class. Refresh to check its current status.',
        );
        setState(reload);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(bottom: 24),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: busy
              ? null
              : () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/live-classes');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Live classes'),
        ),
      ),
      FutureBuilder<LiveClass>(
        future: result,
        builder: (context, snapshot) {
          final state = adminFutureState(
            snapshot,
            noun: 'live class',
            onRetry: refresh,
          );

          if (state != null) return state;

          final liveClass = snapshot.data!;
          final scheduled =
              liveClass.status == 'SCHEDULED';
          final live = liveClass.status == 'LIVE';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminPageHeader(
                eyebrow: const AdminEyebrow(
                  section: 'Virtual campus',
                  detail: 'Live class details',
                ),
                title: liveClass.title,
                subtitle: liveClass.courseName,
                titleTrailing: [
                  StatusPill(
                    label: liveClass.status,
                    compact: true,
                    tone: switch (liveClass.status) {
                      'LIVE' => PillTone.danger,
                      'SCHEDULED' => PillTone.info,
                      'COMPLETED' => PillTone.success,
                      _ => PillTone.neutral,
                    },
                  ),
                ],
                actions: [
                  AdminOutlineButton(
                    label: 'Refresh',
                    icon: Icons.refresh_rounded,
                    onPressed: busy ? null : refresh,
                  ),
                  if (scheduled || live)
                    GradientButton(
                      label: 'Edit class',
                      icon: Icons.edit_outlined,
                      onPressed:
                      busy ? null : () => edit(liveClass),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              AdminCard(
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'Title',
                      value: liveClass.title,
                    ),
                    _InfoRow(
                      label: 'Course',
                      value: liveClass.courseName,
                    ),
                    _InfoRow(
                      label: 'Subject',
                      value: _text(liveClass.subjectName),
                    ),
                    _InfoRow(
                      label: 'Teacher',
                      value: liveClass.teacherName,
                    ),
                    _InfoRow(
                      label: 'Scheduled start',
                      value: _date(liveClass.scheduledStartAt),
                    ),
                    _InfoRow(
                      label: 'Scheduled end',
                      value: _date(liveClass.scheduledEndAt),
                    ),
                    _InfoRow(
                      label: 'Actual start',
                      value: _date(liveClass.actualStartAt),
                    ),
                    _InfoRow(
                      label: 'Actual end',
                      value: _date(liveClass.actualEndAt),
                    ),
                    _InfoRow(
                      label: 'Meeting URL',
                      value: _text(liveClass.meetingUrl),
                    ),
                    _InfoRow(
                      label: 'Meeting ID',
                      value: _text(liveClass.meetingId),
                    ),
                    _InfoRow(
                      label: 'Meeting password',
                      value: _text(liveClass.meetingPassword),
                    ),
                    _InfoRow(
                      label: 'Description',
                      value: _text(liveClass.description),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (busy) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (scheduled)
                    GradientButton(
                      label: 'Start class',
                      icon: Icons.play_arrow_rounded,
                      onPressed: busy
                          ? null
                          : () => perform(
                        liveClass,
                        _ClassAction.start,
                      ),
                    ),
                  if (live)
                    GradientButton(
                      label: 'Complete class',
                      icon: Icons.check_rounded,
                      onPressed: busy
                          ? null
                          : () => perform(
                        liveClass,
                        _ClassAction.complete,
                      ),
                    ),
                  if (scheduled || live)
                    AdminOutlineButton(
                      label: 'Cancel class',
                      icon: Icons.cancel_outlined,
                      danger: true,
                      onPressed: busy
                          ? null
                          : () => perform(
                        liveClass,
                        _ClassAction.cancel,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    ],
  );
}

class _EditLiveClassDialog extends ConsumerStatefulWidget {
  const _EditLiveClassDialog({required this.liveClass});

  final LiveClass liveClass;

  @override
  ConsumerState<_EditLiveClassDialog> createState() =>
      _EditLiveClassDialogState();
}

class _EditLiveClassDialogState
    extends ConsumerState<_EditLiveClassDialog> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController title;
  late final TextEditingController description;
  late final TextEditingController meetingUrl;
  late final TextEditingController meetingId;
  late final TextEditingController meetingPassword;

  DateTime? startAt;
  DateTime? endAt;
  bool saving = false;
  bool picking = false;
  String? error;

  bool get scheduled =>
      widget.liveClass.status == 'SCHEDULED';

  @override
  void initState() {
    super.initState();

    title = TextEditingController(
      text: widget.liveClass.title,
    );
    description = TextEditingController(
      text: widget.liveClass.description,
    );
    meetingUrl = TextEditingController(
      text: widget.liveClass.meetingUrl ?? '',
    );
    meetingId = TextEditingController(
      text: widget.liveClass.meetingId ?? '',
    );
    meetingPassword = TextEditingController(
      text: widget.liveClass.meetingPassword ?? '',
    );

    startAt = widget.liveClass.scheduledStartAt?.toLocal();
    endAt = widget.liveClass.scheduledEndAt?.toLocal();
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    meetingUrl.dispose();
    meetingId.dispose();
    meetingPassword.dispose();
    super.dispose();
  }

  Future<void> pick(bool start) async {
    if (saving || picking || !scheduled) return;

    setState(() => picking = true);

    try {
      final initial =
          (start ? startAt : endAt) ?? DateTime.now();

      final day = DateTime(
        initial.year,
        initial.month,
        initial.day,
      );

      final first =
      day.isBefore(DateTime(2000)) ? day : DateTime(2000);

      final last = day.isAfter(DateTime(2100, 12, 31))
          ? day
          : DateTime(2100, 12, 31);

      final date = await showDatePicker(
        context: context,
        initialDate: day,
        firstDate: first,
        lastDate: last,
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
          startAt = value;
        } else {
          endAt = value;
        }

        error = null;
      });
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> save() async {
    if (saving ||
        picking ||
        !formKey.currentState!.validate()) {
      return;
    }

    if (scheduled &&
        (startAt == null ||
            endAt == null ||
            !endAt!.isAfter(startAt!))) {
      setState(() {
        error =
        'Select start/end times. End must be after start.';
      });
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      final updated =
      await ref.read(liveClassRepositoryProvider).update(
        uuid: widget.liveClass.uuid,
        title: title.text,
        description: description.text,
        meetingUrl: meetingUrl.text,
        meetingId: meetingId.text,
        meetingPassword: meetingPassword.text,
        scheduledStartAt: scheduled ? startAt : null,
        scheduledEndAt: scheduled ? endAt : null,
        includeSchedule: scheduled,
      );

      if (mounted) Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Could not save class. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget field(
      TextEditingController controller,
      String label, {
        int? maxLength,
        int lines = 1,
        bool obscure = false,
        String? Function(String?)? validator,
      }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          enabled: !saving,
          maxLength: maxLength,
          maxLines: lines,
          obscureText: obscure,
          validator: validator,
          decoration: adminFieldDecoration(
            context,
            hint: label,
          ).copyWith(labelText: label),
        ),
      );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving && !picking,
    child: AdminFormDialog(
      icon: Icons.edit_outlined,
      title: 'Edit live class',
      subtitle: scheduled
          ? 'Update class details and scheduled times.'
          : 'Update title, description and meeting details.',
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
            if (scheduled)
              for (final start in [true, false])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    start
                        ? 'Scheduled start (local time)'
                        : 'Scheduled end (local time)',
                  ),
                  subtitle:
                  Text(_date(start ? startAt : endAt)),
                  trailing: const Icon(
                    Icons.calendar_month_outlined,
                  ),
                  onTap: saving || picking
                      ? null
                      : () => pick(start),
                ),
            field(
              meetingUrl,
              'Meeting URL',
              maxLength: 1000,
              validator: (value) {
                final text = (value ?? '').trim();

                if (text.isEmpty) return null;

                final uri = Uri.tryParse(text);

                if (uri == null ||
                    !['http', 'https'].contains(uri.scheme) ||
                    uri.host.isEmpty) {
                  return 'Enter a valid http/https meeting URL.';
                }

                return null;
              },
            ),
            field(
              meetingId,
              'Meeting ID',
              maxLength: 255,
            ),
            field(
              meetingPassword,
              'Meeting password',
              maxLength: 255,
              obscure: true,
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
          label: 'Save changes',
          loading: saving,
          onPressed: saving || picking ? null : save,
        ),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final heading = Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        );

        if (constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: 4),
              SelectableText(value),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 170, child: heading),
            Expanded(child: SelectableText(value)),
          ],
        );
      },
    ),
  );
}

String _text(String? value) =>
    (value ?? '').trim().isEmpty ? '—' : value!;

String _date(DateTime? value) {
  if (value == null) return '—';

  final local = value.toLocal();

  String two(int number) =>
      number.toString().padLeft(2, '0');

  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}