import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/open_external_link.dart';
import '../data/student_portal_repository.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _classData = ref
        .read(studentPortalRepositoryProvider)
        .liveClass(widget.liveClassUuid);
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
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _classData,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Text('Could not load class: ${snapshot.error}'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _refresh,
                  child: const Text('Retry'),
                ),
              ],
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

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                _text(item, 'title').isEmpty
                    ? 'Live class'
                    : _text(item, 'title'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              if (_text(item, 'description').isNotEmpty)
                Text(_text(item, 'description')),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Status'),
                subtitle: Text(
                  status.isEmpty ? 'Unknown' : status,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Scheduled start'),
                subtitle: Text(
                  _text(item, 'scheduled_start_at').isEmpty
                      ? 'Not scheduled'
                      : _text(item, 'scheduled_start_at'),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Teacher'),
                subtitle: Text(
                  _text(item, 'teacher_name').isEmpty
                      ? 'Not assigned'
                      : _text(item, 'teacher_name'),
                ),
              ),
              if (status == 'LIVE') ...[
                const SizedBox(height: 20),
                if (meetingUrl.isNotEmpty) ...[
                  FilledButton.icon(
                    onPressed: () => openExternalLink(
                      context,
                      meetingUrl,
                    ),
                    icon: const Icon(Icons.video_call_outlined),
                    label: const Text('Join live class'),
                  ),
                  TextButton.icon(
                    onPressed: () => _copy(
                      meetingUrl,
                      'Meeting link',
                    ),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy meeting link'),
                  ),
                ] else
                  const Text(
                    'This class is live, but the meeting link '
                        'is not available yet. Pull down to refresh.',
                  ),
                if (meetingId.isNotEmpty)
                  ListTile(
                    title: const Text('Meeting ID'),
                    subtitle: SelectableText(meetingId),
                    trailing: IconButton(
                      tooltip: 'Copy meeting ID',
                      onPressed: () => _copy(
                        meetingId,
                        'Meeting ID',
                      ),
                      icon: const Icon(Icons.copy),
                    ),
                  ),
                if (meetingPassword.isNotEmpty)
                  ListTile(
                    title: const Text('Meeting password'),
                    subtitle: SelectableText(meetingPassword),
                    trailing: IconButton(
                      tooltip: 'Copy meeting password',
                      onPressed: () => _copy(
                        meetingPassword,
                        'Meeting password',
                      ),
                      icon: const Icon(Icons.copy),
                    ),
                  ),
              ] else if (status == 'SCHEDULED') ...[
                const SizedBox(height: 20),
                const Text(
                  'The meeting link will appear when the class '
                      'starts. Pull down to check for updates.',
                ),
              ] else if (status == 'COMPLETED') ...[
                const SizedBox(height: 20),
                const Text('This live class has ended.'),
              ] else if (status == 'CANCELLED') ...[
                const SizedBox(height: 20),
                const Text('This live class was cancelled.'),
              ],
            ],
          );
        },
      ),
    );
  }
}