import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/student_portal_repository.dart';

class MyCoursesScreen extends ConsumerStatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  ConsumerState<MyCoursesScreen> createState() =>
      _MyCoursesScreenState();
}

class _MyCoursesScreenState extends ConsumerState<MyCoursesScreen> {
  late Future<List<MyCourse>> courses;

  @override
  void initState() {
    super.initState();
    courses = ref.read(studentPortalRepositoryProvider).myCourses();
  }

  void reload() {
    courses = ref.read(studentPortalRepositoryProvider).myCourses();

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        reload();
        await courses;
      },
      child: FutureBuilder<List<MyCourse>>(
        future: courses,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Could not load courses: ${snapshot.error}',
                  ),
                ),
                TextButton(
                  onPressed: reload,
                  child: const Text('Retry'),
                ),
              ],
            );
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No active enrolled courses yet. '
                        'Your academy can grant access.',
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(item.name),
                  subtitle: Text(
                    '${item.categoryName ?? item.code}\n'
                        '${item.accessEndAt == null ? 'Access active' : 'Access until ${item.accessEndAt}'}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(
                    '/student/courses/${item.courseUuid}',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class MyCourseDetailScreen extends ConsumerWidget {
  const MyCourseDetailScreen({
    super.key,
    required this.uuid,
  });

  final String uuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(studentPortalRepositoryProvider);

    return FutureBuilder<MyCourse>(
      future: repository.myCourse(uuid),
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
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              course.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(course.description),
            const SizedBox(height: 22),
            Text(
              'Study materials',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: repository.materials(uuid),
              builder: (context, data) => _resourceList(
                data,
                'No materials uploaded yet.',
                'title',
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Live classes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: repository.classes(uuid),
              builder: (context, data) => _resourceList(
                data,
                'No live classes scheduled.',
                'title',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _resourceList(
      AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
      String empty,
      String labelKey,
      ) {
    if (!snapshot.hasData) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          snapshot.hasError
              ? 'Could not load: ${snapshot.error}'
              : 'Loading...',
        ),
      );
    }

    if (snapshot.data!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(empty),
      );
    }

    return Column(
      children: [
        for (final item in snapshot.data!)
          ListTile(
            title: Text(item[labelKey]?.toString() ?? 'Untitled'),
            subtitle: Text(item['status']?.toString() ?? ''),
          ),
      ],
    );
  }
}