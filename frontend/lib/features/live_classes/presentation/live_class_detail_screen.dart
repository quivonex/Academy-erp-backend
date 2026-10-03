import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../data/live_class.dart';
import '../data/live_class_repository.dart';

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

class _LiveClassDetailScreenState extends ConsumerState<LiveClassDetailScreen> {
  late Future<LiveClass> result;

  bool processing = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    result = ref
        .read(liveClassRepositoryProvider)
        .detail(widget.liveClassUuid);
  }

  Future<void> startClass(
    LiveClass liveClass,
  ) async {
    setState(() {
      processing = true;
    });

    try {
      await ref.read(liveClassRepositoryProvider).start(liveClass.uuid);

      if (mounted) {
        setState(reload);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Live class started successfully.',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      showError(e.message);
    } finally {
      if (mounted) {
        setState(() {
          processing = false;
        });
      }
    }
  }

  Future<void> completeClass(
    LiveClass liveClass,
  ) async {
    setState(() {
      processing = true;
    });

    try {
      await ref.read(liveClassRepositoryProvider).complete(liveClass.uuid);

      if (mounted) {
        setState(reload);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Live class completed successfully.',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      showError(e.message);
    } finally {
      if (mounted) {
        setState(() {
          processing = false;
        });
      }
    }
  }

  Future<void> cancelClass(
    LiveClass liveClass,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text(
              'Cancel Live Class',
            ),
            content: const Text(
              'Are you sure you want to cancel this live class?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(
                  context,
                  false,
                ),
                child: const Text(
                  'No',
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  true,
                ),
                child: const Text(
                  'Yes, Cancel',
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    setState(() {
      processing = true;
    });

    try {
      await ref.read(liveClassRepositoryProvider).cancel(liveClass.uuid);

      if (mounted) {
        setState(reload);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Live class cancelled successfully.',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      showError(e.message);
    } finally {
      if (mounted) {
        setState(() {
          processing = false;
        });
      }
    }
  }

  void showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LiveClass>(
      future: result,
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Could not load live class:\n${snapshot.error}',
                ),
                TextButton(
                  onPressed: () {
                    setState(reload);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final liveClass = snapshot.data!;

        final canStart = liveClass.status == 'SCHEDULED';

        final canComplete = liveClass.status == 'LIVE';

        final canCancel =
            liveClass.status == 'SCHEDULED' || liveClass.status == 'LIVE';

        final canEdit =
            liveClass.status == 'SCHEDULED' || liveClass.status == 'LIVE';

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(
                  Icons.arrow_back,
                ),
                label: const Text('Live Classes'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    child: Icon(
                      Icons.video_camera_front,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          liveClass.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          liveClass.courseName,
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(
                      liveClass.status,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(
                    20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Class Information',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(
                        height: 18,
                      ),
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
                        value: liveClass.subjectName?.isNotEmpty == true
                            ? liveClass.subjectName!
                            : '—',
                      ),
                      _InfoRow(
                        label: 'Teacher',
                        value: liveClass.teacherName,
                      ),
                      _InfoRow(
                        label: 'Scheduled Start',
                        value: _formatDateTime(
                          liveClass.scheduledStartAt,
                        ),
                      ),
                      _InfoRow(
                        label: 'Scheduled End',
                        value: _formatDateTime(
                          liveClass.scheduledEndAt,
                        ),
                      ),
                      _InfoRow(
                        label: 'Actual Start',
                        value: _formatDateTime(
                          liveClass.actualStartAt,
                        ),
                      ),
                      _InfoRow(
                        label: 'Actual End',
                        value: _formatDateTime(
                          liveClass.actualEndAt,
                        ),
                      ),
                      _InfoRow(
                        label: 'Meeting URL',
                        value: liveClass.meetingUrl?.isNotEmpty == true
                            ? liveClass.meetingUrl!
                            : '—',
                      ),
                      _InfoRow(
                        label: 'Meeting ID',
                        value: liveClass.meetingId?.isNotEmpty == true
                            ? liveClass.meetingId!
                            : '—',
                      ),
                      _InfoRow(
                        label: 'Meeting Password',
                        value: liveClass.meetingPassword?.isNotEmpty == true
                            ? liveClass.meetingPassword!
                            : '—',
                      ),
                      _InfoRow(
                        label: 'Status',
                        value: liveClass.status,
                      ),
                      _InfoRow(
                        label: 'Description',
                        value: liveClass.description.isEmpty
                            ? '—'
                            : liveClass.description,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  if (canStart)
                    FilledButton.icon(
                      onPressed: processing
                          ? null
                          : () => startClass(
                                liveClass,
                              ),
                      icon: const Icon(
                        Icons.play_arrow,
                      ),
                      label: Text(
                        processing ? 'Processing...' : 'Start Class',
                      ),
                    ),
                  if (canComplete)
                    FilledButton.icon(
                      onPressed: processing
                          ? null
                          : () => completeClass(
                                liveClass,
                              ),
                      icon: const Icon(
                        Icons.check,
                      ),
                      label: Text(
                        processing ? 'Processing...' : 'Complete Class',
                      ),
                    ),
                  if (canEdit)
                    OutlinedButton.icon(
                      onPressed: processing
                          ? null
                          : () async {
                              final updated = await showDialog<bool>(
                                context: context,
                                builder: (_) => _EditLiveClassDialog(
                                  liveClass: liveClass,
                                ),
                              );

                              if (updated == true && mounted) {
                                setState(
                                  reload,
                                );
                              }
                            },
                      icon: const Icon(
                        Icons.edit,
                      ),
                      label: const Text(
                        'Edit Class',
                      ),
                    ),
                  if (canCancel)
                    OutlinedButton.icon(
                      onPressed: processing
                          ? null
                          : () => cancelClass(
                                liveClass,
                              ),
                      icon: const Icon(
                        Icons.cancel_outlined,
                      ),
                      label: const Text(
                        'Cancel Class',
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EditLiveClassDialog extends ConsumerStatefulWidget {
  const _EditLiveClassDialog({
    required this.liveClass,
  });

  final LiveClass liveClass;

  @override
  ConsumerState<_EditLiveClassDialog> createState() =>
      _EditLiveClassDialogState();
}

class _EditLiveClassDialogState extends ConsumerState<_EditLiveClassDialog> {
  late final TextEditingController title;

  late final TextEditingController description;

  late final TextEditingController meetingUrl;

  late final TextEditingController meetingId;

  late final TextEditingController meetingPassword;

  DateTime? startAt;
  DateTime? endAt;

  bool saving = false;

  String? error;

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

    startAt = widget.liveClass.scheduledStartAt;

    endAt = widget.liveClass.scheduledEndAt;
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

  Future<DateTime?> pickDateTime(
    DateTime? current,
  ) async {
    final initial = current ?? DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (date == null || !mounted) {
      return null;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        initial,
      ),
    );

    if (time == null) {
      return null;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty) {
      setState(() {
        error = 'Title is required.';
      });

      return;
    }

    if (startAt != null && endAt != null && !endAt!.isAfter(startAt!)) {
      setState(() {
        error = 'End time must be after start time.';
      });

      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await ref.read(liveClassRepositoryProvider).update(
            uuid: widget.liveClass.uuid,
            title: title.text,
            description: description.text,
            scheduledStartAt: startAt,
            scheduledEndAt: endAt,
            meetingUrl: meetingUrl.text,
            meetingId: meetingId.text,
            meetingPassword: meetingPassword.text,
            includeSchedule: widget.liveClass.status == 'SCHEDULED',
          );

      if (mounted) {
        Navigator.pop(
          context,
          true,
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isScheduled = widget.liveClass.status == 'SCHEDULED';

    return AlertDialog(
      title: const Text('Edit Live Class'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: description,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description',
                ),
              ),
              if (isScheduled) ...[
                const SizedBox(
                  height: 12,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Scheduled Start',
                  ),
                  subtitle: Text(
                    _formatDateTime(
                      startAt,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.calendar_month,
                  ),
                  onTap: () async {
                    final value = await pickDateTime(
                      startAt,
                    );

                    if (value != null && mounted) {
                      setState(() {
                        startAt = value;
                      });
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Scheduled End',
                  ),
                  subtitle: Text(
                    _formatDateTime(
                      endAt,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.calendar_month,
                  ),
                  onTap: () async {
                    final value = await pickDateTime(
                      endAt,
                    );

                    if (value != null && mounted) {
                      setState(() {
                        endAt = value;
                      });
                    }
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: meetingUrl,
                decoration: const InputDecoration(
                  labelText: 'Meeting URL',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: meetingId,
                decoration: const InputDecoration(
                  labelText: 'Meeting ID',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: meetingPassword,
                decoration: const InputDecoration(
                  labelText: 'Meeting Password',
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(
                    top: 12,
                  ),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(
            saving ? 'Saving...' : 'Save Changes',
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(
  DateTime? value,
) {
  if (value == null) {
    return '—';
  }

  final local = value.toLocal();

  String twoDigits(int number) => number.toString().padLeft(
        2,
        '0',
      );

  return '${twoDigits(local.day)}/'
      '${twoDigits(local.month)}/'
      '${local.year} '
      '${twoDigits(local.hour)}:'
      '${twoDigits(local.minute)}';
}
