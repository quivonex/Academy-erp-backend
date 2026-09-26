import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/student_portal_repository.dart';

class LiveClassDetailScreen
    extends ConsumerStatefulWidget {
  const LiveClassDetailScreen({
    super.key,
    required this.liveClassUuid,
  });

  final String liveClassUuid;

  @override
  ConsumerState<LiveClassDetailScreen>
  createState() =>
      _LiveClassDetailScreenState();
}

class _LiveClassDetailScreenState
    extends ConsumerState<LiveClassDetailScreen> {
  late Future<Map<String, dynamic>> _classData;

  @override
  void initState() {
    super.initState();

    _classData = ref
        .read(studentPortalRepositoryProvider)
        .liveClass(widget.liveClassUuid);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _classData,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load class: '
                  '${snapshot.error}',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final item = snapshot.data!;
        final meetingUrl =
        item['meeting_url']?.toString();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              item['title']?.toString() ??
                  'Live class',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              item['description']
                  ?.toString() ??
                  '',
            ),
            const SizedBox(height: 16),
            ListTile(
              leading:
              const Icon(Icons.schedule),
              title: const Text('Scheduled at'),
              subtitle: Text(
                item['scheduled_start_at']
                    ?.toString() ??
                    'Not scheduled',
              ),
            ),
            ListTile(
              leading:
              const Icon(Icons.person_outline),
              title: const Text('Teacher'),
              subtitle: Text(
                item['teacher_name']
                    ?.toString() ??
                    'Not assigned',
              ),
            ),
            ListTile(
              leading:
              const Icon(Icons.info_outline),
              title: const Text('Status'),
              subtitle: Text(
                item['status']?.toString() ??
                    '',
              ),
            ),
            if (meetingUrl != null &&
                meetingUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              SelectableText(meetingUrl),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: meetingUrl,
                    ),
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Meeting link copied',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text(
                  'Copy meeting link',
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}