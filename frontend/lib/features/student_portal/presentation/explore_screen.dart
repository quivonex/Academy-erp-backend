import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/user_role.dart';
import '../data/student_portal_repository.dart';
import 'home_banners.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() =>
      _ExploreScreenState();
}

class _ExploreScreenState
    extends ConsumerState<ExploreScreen> {
  final TextEditingController _searchController =
  TextEditingController();

  Timer? _searchTimer;

  List<CourseCategory> _categories = [];
  List<PublicCourse> _courses = [];

  String? _selectedCategoryUuid;
  String? _error;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  int _page = 1;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();

    _loadCategories();
    _loadCourses(reset: true);
  }

  Future<void> _loadCategories() async {
    try {
      final result = await ref
          .read(studentPortalRepositoryProvider)
          .categories();

      if (!mounted) return;

      setState(() => _categories = result);
    } catch (_) {
      // Categories fail झाल्या तरी course list दिसेल.
    }
  }

  Future<void> _loadCourses({
    required bool reset,
  }) async {
    if (!reset && (_loadingMore || !_hasMore)) {
      return;
    }

    final requestId = ++_requestId;
    final requestedPage = reset ? 1 : _page + 1;

    setState(() {
      _error = null;

      if (reset) {
        _loading = true;
        _loadingMore = false;
        _courses = [];
        _hasMore = true;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final result = await ref
          .read(studentPortalRepositoryProvider)
          .publicCourses(
        search: _searchController.text,
        categoryUuid:
        _selectedCategoryUuid,
        page: requestedPage,
      );

      if (!mounted || requestId != _requestId) {
        return;
      }

      setState(() {
        if (reset) {
          _courses = result;
        } else {
          _courses.addAll(result);
        }

        _page = requestedPage;
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

  void _onSearchChanged(String _) {
    _searchTimer?.cancel();

    _searchTimer = Timer(
      const Duration(milliseconds: 400),
          () => _loadCourses(reset: true),
    );
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = ref
        .watch(sessionControllerProvider)
        .role ==
        UserRole.student;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore courses'),
        actions: [
          TextButton(
            onPressed: () => context.go(
              isStudent
                  ? '/student/courses'
                  : '/login',
            ),
            child: Text(
              isStudent
                  ? 'My Courses'
                  : 'Sign in',
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _loadCategories(),
            _loadCourses(reset: true),
          ]);
        },
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const HomeBanners(),
            const SizedBox(height: 22),
            Text(
              'Find your next course',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Explore courses available at the academy.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                labelText: 'Search courses',
                prefixIcon:
                const Icon(Icons.search),
                suffixIcon:
                _searchController.text.isEmpty
                    ? null
                    : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController
                        .clear();
                    _searchTimer
                        ?.cancel();
                    _loadCourses(
                      reset: true,
                    );
                  },
                  icon: const Icon(
                    Icons.close,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding:
                    const EdgeInsets.only(
                      right: 8,
                    ),
                    child: ChoiceChip(
                      label: const Text('All'),
                      selected:
                      _selectedCategoryUuid ==
                          null,
                      onSelected: (_) {
                        _selectedCategoryUuid =
                        null;
                        _loadCourses(
                          reset: true,
                        );
                      },
                    ),
                  ),
                  for (final category
                  in _categories)
                    Padding(
                      padding:
                      const EdgeInsets.only(
                        right: 8,
                      ),
                      child: ChoiceChip(
                        label:
                        Text(category.name),
                        selected:
                        _selectedCategoryUuid ==
                            category.uuid,
                        onSelected: (_) {
                          _selectedCategoryUuid =
                              category.uuid;
                          _loadCourses(
                            reset: true,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(
                  child:
                  CircularProgressIndicator(),
                ),
              )
            else if (_error != null &&
                _courses.isEmpty) ...[
              Text(
                'Could not load courses: $_error',
              ),
              TextButton(
                onPressed: () =>
                    _loadCourses(reset: true),
                child: const Text('Retry'),
              ),
            ] else if (_courses.isEmpty)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(
                  child: Text(
                    'No courses found.',
                  ),
                ),
              )
            else ...[
                for (final course in _courses)
                  _CourseCard(course: course),
                if (_error != null)
                  Padding(
                    padding:
                    const EdgeInsets.all(8),
                    child: Text(
                      'Could not load more: $_error',
                    ),
                  ),
                if (_hasMore)
                  Padding(
                    padding:
                    const EdgeInsets.only(
                      top: 12,
                    ),
                    child: OutlinedButton(
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
                  ),
              ],
          ],
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
  });

  final PublicCourse course;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      child: InkWell(
        borderRadius:
        BorderRadius.circular(12),
        onTap: () => context.push(
          '/explore/${course.uuid}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              if (course.isFeatured)
                const Chip(
                  label: Text('Featured'),
                ),
              Text(
                course.name,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                course.categoryName ??
                    course.code,
              ),
              const SizedBox(height: 10),
              Text(
                course.description,
                maxLines: 2,
                overflow:
                TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '₹${course.price}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium,
                  ),
                  const Spacer(),
                  Text(course.deliveryMode),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PublicCourseDetailScreen extends ConsumerStatefulWidget {
  const PublicCourseDetailScreen({
    super.key,
    required this.uuid,
  });

  final String uuid;

  @override
  ConsumerState<PublicCourseDetailScreen> createState() =>
      _PublicCourseDetailScreenState();
}

class _PublicCourseDetailScreenState
    extends ConsumerState<PublicCourseDetailScreen> {
  late Future<PublicCourse> _course;
  Future<bool>? _hasAccess;

  @override
  void initState() {
    super.initState();
    _loadCourse();
  }

  @override
  void didUpdateWidget(covariant PublicCourseDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.uuid != widget.uuid) {
      _loadCourse();
      _hasAccess = null;
    }
  }

  void _loadCourse() {
    _course = ref
        .read(studentPortalRepositoryProvider)
        .publicCourse(widget.uuid);
  }

  Future<bool> _checkAccess() async {
    try {
      await ref
          .read(studentPortalRepositoryProvider)
          .myCourse(widget.uuid);
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 404) return false;
      rethrow;
    }
  }

  Widget _courseAction({
    required bool isAuthenticated,
    required bool isStudent,
  }) {
    if (!isAuthenticated) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sign in with a student account to check your course access.',
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Sign in'),
          ),
        ],
      );
    }

    if (!isStudent) {
      return const Text(
        'Course learning is available to student accounts.',
      );
    }

    return FutureBuilder<bool>(
      future: _hasAccess ??= _checkAccess(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Could not check course access: ${snapshot.error}'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  setState(() => _hasAccess = _checkAccess());
                },
                child: const Text('Try again'),
              ),
            ],
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.data == true) {
          return FilledButton(
            onPressed: () => context.go(
              '/student/courses/${widget.uuid}',
            ),
            child: const Text('Continue learning'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'You do not have access to this course yet. '
              'Contact the academy for enrollment.',
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go('/student/courses'),
              child: const Text('View my courses'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final isStudent = session.isAuthenticated &&
        session.role == UserRole.student;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Course details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Explore',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/explore');
            }
          },
        ),
      ),
      body: FutureBuilder<PublicCourse>(
        future: _course,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Could not load course: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(_loadCourse),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final course = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (course.isFeatured)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(label: Text('Featured')),
                ),
              Text(
                course.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(course.categoryName ?? course.code),
              const SizedBox(height: 16),
              Text(
                course.description.isEmpty
                    ? 'Description is not available.'
                    : course.description,
              ),
              const SizedBox(height: 20),
              Text('Price: ₹${course.price}'),
              Text('Mode: ${course.deliveryMode}'),
              if (course.durationMonths != null)
                Text(
                  'Duration: ${course.durationMonths} months',
                ),
              const SizedBox(height: 24),
              _courseAction(
                isAuthenticated: session.isAuthenticated,
                isStudent: isStudent,
              ),
            ],
          );
        },
      ),
    );
  }
}