import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/student_portal_repository.dart';

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
        _classes.addAll(result);
        _page = nextPage;
        _hasMore = result.length == 20;
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

  String _displayTime(dynamic rawValue) {
    final value = rawValue?.toString();

    if (value == null || value.isEmpty) {
      return 'Time not available';
    }

    final date = DateTime.tryParse(value);

    if (date == null) return value;

    final local = date.toLocal();

    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${twoDigits(local.day)}/'
        '${twoDigits(local.month)}/${local.year}  '
        '${twoDigits(local.hour)}:'
        '${twoDigits(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Live Classes',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Classes for your enrolled courses.',
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _statusChip('All', null),
                _statusChip('Scheduled', 'SCHEDULED'),
                _statusChip('Live', 'LIVE'),
                _statusChip('Completed', 'COMPLETED'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null && _classes.isEmpty) ...[
            Text('Could not load classes: $_error'),
            TextButton(
              onPressed: () => _load(reset: true),
              child: const Text('Retry'),
            ),
          ] else if (_classes.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No classes found for this filter.',
                ),
              ),
            )
          else ...[
            for (final item in _classes)
              Card(
                margin: const EdgeInsets.only(
                  bottom: 12,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: Icon(
                    item['status'] == 'LIVE'
                        ? Icons.wifi
                        : Icons.video_camera_front_outlined,
                  ),
                  title: Text(
                    item['title']?.toString() ?? 'Live class',
                  ),
                  subtitle: Text(
                    '${item['course_name'] ?? ''}\n'
                    '${_displayTime(
                      item['scheduled_start_at'],
                    )}  •  ${item['status'] ?? ''}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    final uuid = item['uuid']?.toString();

                    if (uuid != null && uuid.isNotEmpty) {
                      context.push(
                        '/student/live-classes/$uuid',
                      );
                    }
                  },
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Could not load more: $_error',
                ),
              ),
            if (_hasMore)
              OutlinedButton(
                onPressed:
                    _loadingMore ? null : () => _load(reset: false),
                child: _loadingMore
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Load more classes',
                      ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(
    String label,
    String? status,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _selectedStatus == status,
        onSelected: (_) {
          _selectedStatus = status;
          _load(reset: true);
        },
      ),
    );
  }
}
