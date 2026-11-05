import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../data/student_enrollment_repository.dart';
import '../data/student_portal_repository.dart';

class StudentEnrollmentAction extends ConsumerStatefulWidget {
  const StudentEnrollmentAction({super.key, required this.courseUuid});
  final String courseUuid;

  @override
  ConsumerState<StudentEnrollmentAction> createState() => _StudentEnrollmentActionState();
}

class _StudentEnrollmentActionState extends ConsumerState<StudentEnrollmentAction> {
  late Future<StudentEnrollment> _status;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _status = _load();
  }

  Future<StudentEnrollment> _load() async {
    // Keep existing chapter-only grants working as well as full enrollment.
    try {
      final course = await ref.read(studentPortalRepositoryProvider).myCourse(widget.courseUuid);
      return StudentEnrollment(courseUuid: widget.courseUuid,
        courseName: course.name, status: 'ACTIVE', hasAccess: true);
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;
    }
    return ref.read(studentEnrollmentRepositoryProvider).status(widget.courseUuid);
  }

  void _refresh() => setState(() {
    _error = null;
    _status = _load();
  });

  Future<void> _request() async {
    if (_submitting) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final enrollment = await ref.read(studentEnrollmentRepositoryProvider)
          .request(widget.courseUuid);
      if (!mounted) return;
      setState(() => _status = Future.value(enrollment));
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not submit enrollment: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<StudentEnrollment>(
    future: _status,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Column(children: [
          Text('Could not check enrollment: ${snapshot.error}'),
          TextButton(onPressed: _refresh, child: const Text('Try again')),
        ]);
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final enrollment = snapshot.data!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(enrollment.hasAccess
              ? 'You have access to this course.'
              : enrollment.isPending
                  ? 'Enrollment requested. Your academy will confirm fees and approve access.'
                  : enrollment.canRequest
                      ? 'Request enrollment. Your academy will confirm fees and approve access before learning begins.'
                      : 'Your enrollment is ${enrollment.status.toLowerCase()}. Contact your academy to update access.'),
          const SizedBox(height: 14),
          if (enrollment.hasAccess)
            FilledButton.icon(
              onPressed: () => context.go('/student/courses/${widget.courseUuid}'),
              icon: const Icon(Icons.play_circle_fill_rounded),
              label: const Text('Continue learning'),
            )
          else if (enrollment.canRequest)
            FilledButton.icon(
              onPressed: _submitting ? null : _request,
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.how_to_reg_outlined),
              label: Text(_submitting ? 'Submitting…' : 'Enroll'),
            )
          else
            OutlinedButton(onPressed: _refresh,
              child: const Text('Refresh enrollment status')),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => context.go('/student/courses'),
            child: const Text('View My Courses'),
          ),
        ],
      );
    },
  );
}

class PendingEnrollments extends ConsumerStatefulWidget {
  const PendingEnrollments({super.key, this.refreshRevision = 0});
  final int refreshRevision;

  @override
  ConsumerState<PendingEnrollments> createState() => _PendingEnrollmentsState();
}

class _PendingEnrollmentsState extends ConsumerState<PendingEnrollments> {
  final _items = <StudentEnrollment>[];
  bool _loading = false;
  bool _hasNext = false;
  int _page = 0;
  int _revision = 0;
  String? _error;
  bool _retryReset = false;

  @override
  void initState() { super.initState(); _load(reset: true); }

  @override
  void didUpdateWidget(covariant PendingEnrollments oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshRevision != widget.refreshRevision) _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && _loading) return;
    final revision = ++_revision;
    final page = reset ? 1 : _page + 1;
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ref.read(studentEnrollmentRepositoryProvider).pending(page: page);
      if (!mounted || revision != _revision) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(result.items);
        _page = page;
        _hasNext = result.hasNext;
      });
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(() {
          _retryReset = reset;
          _error = 'Could not load enrollment requests.';
        });
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _error == null && _items.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Enrollment requests', style: Theme.of(context).textTheme.titleMedium),
            for (final item in _items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.courseName),
                subtitle: const Text('Pending academy approval'),
                trailing: const Icon(Icons.schedule_rounded),
                onTap: () => context.push('/explore/${item.courseUuid}'),
              ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) Text(_error!),
            if (_error != null)
              TextButton(onPressed: () => _load(reset: _retryReset),
                child: const Text('Retry enrollment requests'))
            else if (_hasNext && !_loading)
              TextButton(onPressed: _load, child: const Text('Load more requests')),
          ],
        ),
      ),
    );
  }
}
