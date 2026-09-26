import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_exception.dart';
import '../data/course.dart';
import '../data/course_repository.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  const CourseDetailScreen({super.key, required this.courseUuid});
  final String courseUuid;
  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> {
  late Future<Course> result;
  bool changing = false;
  @override
  void initState() { super.initState(); reload(); }
  void reload() { result = ref.read(courseRepositoryProvider).detail(widget.courseUuid); }

  Future<void> toggle(Course course) async {
    setState(() => changing = true);
    try {
      await ref.read(courseRepositoryProvider).setPublished(course.uuid, !course.isPublished);
      if (mounted) setState(reload);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally { if (mounted) setState(() => changing = false); }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Course>(future: result, builder: (context, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
    if (snapshot.hasError) return Center(child: Text('Could not load course: ${snapshot.error}'));
    final c = snapshot.data!;
    return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextButton.icon(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back), label: const Text('Courses')),
      Text(c.name, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Code: ${c.code}'), Text('Category: ${c.categoryName ?? '—'}'),
        Text('Price: ₹${c.price}'), Text('Mode: ${c.deliveryMode}'),
        Text('Duration: ${c.durationMonths?.toString() ?? '—'} months'),
        Text('Access: ${c.accessDurationDays?.toString() ?? '—'} days'),
        Text('Active: ${c.isActive ? 'Yes' : 'No'}'),
        Text('Published: ${c.isPublished ? 'Yes' : 'No'}'),
        Text('Purchasable online: ${c.isPurchasableOnline ? 'Yes' : 'No'}'),
        const SizedBox(height: 8), Text(c.description),
      ]))),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: changing ? null : () => toggle(c),
        child: Text(changing ? 'Updating...' : (c.isPublished ? 'Unpublish course' : 'Publish course'))),
    ]));
  });
}
