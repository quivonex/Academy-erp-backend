import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/session/user_role.dart';
import '../data/student_portal_repository.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final search = TextEditingController();

  String? categoryUuid;
  late Future<List<PublicCourse>> courses;
  late Future<List<CourseCategory>> categories;

  @override
  void initState() {
    super.initState();

    courses = ref.read(studentPortalRepositoryProvider).publicCourses();
    categories = ref.read(studentPortalRepositoryProvider).categories();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void reload() {
    setState(() {
      courses = ref.read(studentPortalRepositoryProvider).publicCourses(
        search: search.text,
        categoryUuid: categoryUuid,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isStudent =
        ref.watch(sessionControllerProvider).role == UserRole.student;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore courses'),
        actions: [
          TextButton(
            onPressed: () =>
                context.go(isStudent ? '/student/courses' : '/login'),
            child: Text(isStudent ? 'My Courses' : 'Sign in'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          reload();
          await courses;
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Learn something new',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Browse available courses and find the right one for you.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: search,
              onSubmitted: (_) => reload(),
              decoration: InputDecoration(
                labelText: 'Search courses',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: reload,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<CourseCategory>>(
              future: categories,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();

                return Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: categoryUuid == null,
                      onSelected: (_) {
                        categoryUuid = null;
                        reload();
                      },
                    ),
                    for (final category in snapshot.data!)
                      ChoiceChip(
                        label: Text(category.name),
                        selected: categoryUuid == category.uuid,
                        onSelected: (_) {
                          categoryUuid = category.uuid;
                          reload();
                        },
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<PublicCourse>>(
              future: courses,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Column(
                    children: [
                      Text('Could not load courses: ${snapshot.error}'),
                      TextButton(
                        onPressed: reload,
                        child: const Text('Retry'),
                      ),
                    ],
                  );
                }

                final items = snapshot.data ?? [];

                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No courses found.'),
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final course in items)
                        SizedBox(
                          width: constraints.maxWidth > 650
                              ? (constraints.maxWidth - 12) / 2
                              : constraints.maxWidth,
                          child: Card(
                            child: InkWell(
                              onTap: () =>
                                  context.go('/explore/${course.uuid}'),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (course.isFeatured)
                                      const Chip(label: Text('Featured')),
                                    Text(
                                      course.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(course.categoryName ?? course.code),
                                    const SizedBox(height: 12),
                                    Text(
                                      course.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '₹${course.price}  •  '
                                          '${course.deliveryMode}',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class PublicCourseDetailScreen extends ConsumerWidget {
  const PublicCourseDetailScreen({
    super.key,
    required this.uuid,
  });

  final String uuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Course details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/explore'),
        ),
      ),
      body: FutureBuilder<PublicCourse>(
        future: ref.read(studentPortalRepositoryProvider).publicCourse(uuid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: snapshot.hasError
                  ? Text('Could not load course: ${snapshot.error}')
                  : const CircularProgressIndicator(),
            );
          }

          final course = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                course.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                '${course.categoryName ?? course.code}  •  '
                    '${course.deliveryMode}',
              ),
              const SizedBox(height: 20),
              Text(
                course.description.isEmpty
                    ? 'Course description is not available.'
                    : course.description,
              ),
              const SizedBox(height: 20),
              Text('Price: ₹${course.price}'),
              if (course.durationMonths != null)
                Text('Duration: ${course.durationMonths} months'),
              const SizedBox(height: 22),
              const Text(
                'To access the lessons, sign in and contact your academy '
                    'about enrollment.',
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go('/login'),
                child: const Text('Sign in'),
              ),
            ],
          );
        },
      ),
    );
  }
}