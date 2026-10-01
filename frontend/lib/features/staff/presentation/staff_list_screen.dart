import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../teachers/data/teacher.dart';
import '../../teachers/data/teacher_repository.dart';

class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({super.key});

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  final searchController = TextEditingController();
  late Future<TeacherPage> result;
  String search = '';
  int page = 1;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    result = ref.read(teacherRepositoryProvider).list(
          search: search,
          page: page,
        );
  }

  void refresh() {
    setState(reload);
  }

  void applySearch() {
    setState(() {
      search = searchController.text.trim();
      page = 1;
      reload();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Staff & Teachers',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: refresh,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Search staff or teachers',
                  hintText: 'Name, employee ID, phone...',
                ),
                onSubmitted: (_) => applySearch(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: applySearch,
              child: const Text('Search'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<TeacherPage>(
            future: result,
            builder: (context, snapshot) {
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
                      Text('Could not load staff:\n${snapshot.error}'),
                      TextButton(
                        onPressed: refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final data = snapshot.data!;

              if (data.results.isEmpty) {
                return const Center(
                  child: Text('No staff or teachers found.'),
                );
              }

              return ListView.builder(
                itemCount: data.results.length,
                itemBuilder: (context, index) {
                  final teacher = data.results[index];

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          teacher.fullName.isNotEmpty
                              ? teacher.fullName[0].toUpperCase()
                              : 'S',
                        ),
                      ),
                      title: Text(teacher.fullName),
                      subtitle: Text(
                        '${teacher.employeeId}'
                        ' • '
                        '${teacher.specialization.isEmpty ? 'Staff/Teacher' : teacher.specialization}'
                        '${teacher.email.isEmpty ? '' : ' • ${teacher.email}'}',
                      ),
                      trailing: Chip(
                        label: Text(
                          teacher.isActive ? 'Active' : 'Inactive',
                        ),
                      ),
                      onTap: () async {
                        await context.push('/teachers/${teacher.uuid}');
                        if (mounted) refresh();
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
