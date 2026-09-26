import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/student_portal_repository.dart';

class MyCoursesScreen
    extends ConsumerStatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  ConsumerState<MyCoursesScreen> createState() =>
      _MyCoursesScreenState();
}

class _MyCoursesScreenState
    extends ConsumerState<MyCoursesScreen> {
  final List<MyCourse> _courses = [];

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  int _page = 1;
  int _requestId = 0;

  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCourses(reset: true);
  }

  Future<void> _loadCourses({
    required bool reset,
  }) async {
    if (!reset &&
        (_loadingMore || !_hasMore)) {
      return;
    }

    final requestId = ++_requestId;
    final requestedPage =
    reset ? 1 : _page + 1;

    setState(() {
      _error = null;

      if (reset) {
        _loading = true;
        _loadingMore = false;
        _hasMore = true;
        _courses.clear();
      } else {
        _loadingMore = true;
      }
    });

    try {
      final result = await ref
          .read(studentPortalRepositoryProvider)
          .myCourses(page: requestedPage);

      if (!mounted ||
          requestId != _requestId) {
        return;
      }

      setState(() {
        _courses.addAll(result);
        _page = requestedPage;
        _hasMore = result.length == 20;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted ||
          requestId != _requestId) {
        return;
      }

      setState(() {
        _error = error.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () =>
          _loadCourses(reset: true),
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'My Courses',
            style: Theme.of(context)
                .textTheme
                .headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Courses you currently have access to.',
          ),
          const SizedBox(height: 20),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child:
                CircularProgressIndicator(),
              ),
            )
          else if (_courses.isEmpty &&
              _error != null) ...[
            Text(
              'Could not load courses: $_error',
            ),
            TextButton(
              onPressed: () =>
                  _loadCourses(reset: true),
              child: const Text('Retry'),
            ),
          ] else if (_courses.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No active courses yet. '
                      'Contact your academy to get access.',
                ),
              ),
            )
          else ...[
              for (final course in _courses)
                Card(
                  margin: const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child: ListTile(
                    contentPadding:
                    const EdgeInsets.all(16),
                    leading: const Icon(
                      Icons.menu_book_outlined,
                      size: 30,
                    ),
                    title: Text(
                      course.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium,
                    ),
                    subtitle: Padding(
                      padding:
                      const EdgeInsets.only(
                        top: 8,
                      ),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            course.categoryName ??
                                course.code,
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          Text(
                            course.accessEndAt ==
                                null
                                ? 'Access active'
                                : 'Access until '
                                '${course.accessEndAt}',
                          ),
                        ],
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                    ),
                    onTap: () => context.push(
                      '/student/courses/'
                          '${course.courseUuid}',
                    ),
                  ),
                ),

              if (_error != null)
                Padding(
                  padding:
                  const EdgeInsets.all(8),
                  child: Text(
                    'Could not load more: $_error',
                  ),
                ),

              if (_hasMore)
                OutlinedButton(
                  onPressed: _loadingMore
                      ? null
                      : () => _loadCourses(
                    reset: false,
                  ),
                  child: _loadingMore
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    'Load more courses',
                  ),
                ),
            ],
        ],
      ),
    );
  }
}