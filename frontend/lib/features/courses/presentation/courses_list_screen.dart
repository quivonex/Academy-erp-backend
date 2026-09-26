import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_exception.dart';
import '../data/course.dart';
import '../data/course_repository.dart';

class CoursesListScreen extends ConsumerStatefulWidget {
  const CoursesListScreen({super.key});
  @override
  ConsumerState<CoursesListScreen> createState() => _CoursesListScreenState();
}

class _CoursesListScreenState extends ConsumerState<CoursesListScreen> {
  final searchController = TextEditingController();
  late Future<CoursePage> result;
  String search = '';
  int page = 1;
  @override
  void initState() { super.initState(); reload(); }
  void reload() { result = ref.read(courseRepositoryProvider).list(search: search, page: page); }
  void goToPage(int next) { setState(() { page = next; reload(); }); }
  @override
  void dispose() { searchController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Text('Courses', style: Theme.of(context).textTheme.headlineSmall),
      FilledButton.icon(onPressed: () async {
        final created = await showDialog<bool>(context: context, builder: (_) => _CreateCourseDialog(ref.read(courseRepositoryProvider)));
        if (created == true && mounted) setState(() { page = 1; reload(); });
      }, icon: const Icon(Icons.add), label: const Text('Add course')),
      IconButton(onPressed: () => setState(reload), icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
    ]),
    const SizedBox(height: 14),
    Row(children: [
      Expanded(child: TextField(controller: searchController,
        decoration: const InputDecoration(labelText: 'Search course name or code'),
        onSubmitted: (_) => applySearch())),
      const SizedBox(width: 8),
      FilledButton(onPressed: applySearch, child: const Text('Search')),
    ]),
    const SizedBox(height: 12),
    Expanded(child: FutureBuilder<CoursePage>(future: result, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Could not load courses: ${snapshot.error}'),
        TextButton(onPressed: () => setState(reload), child: const Text('Retry')),
      ]));
      final data = snapshot.data!;
      return Column(children: [
        Expanded(child: data.results.isEmpty ? const Center(child: Text('No courses found.'))
          : ListView.builder(itemCount: data.results.length, itemBuilder: (context, index) {
            final course = data.results[index];
            return Card(child: ListTile(
              title: Text(course.name),
              subtitle: Text('${course.code}  •  ₹${course.price}  •  ${course.deliveryMode}'),
              trailing: Chip(label: Text(course.isPublished ? 'Published' : 'Draft')),
              onTap: () async { await context.push('/courses/${course.uuid}'); if (mounted) setState(reload); },
            ));
          })),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('${data.count} total  •  Page $page'),
          IconButton(onPressed: page > 1 ? () => goToPage(page - 1) : null, icon: const Icon(Icons.chevron_left)),
          IconButton(onPressed: page * 20 < data.count ? () => goToPage(page + 1) : null, icon: const Icon(Icons.chevron_right)),
        ]),
      ]);
    })),
  ]);

  void applySearch() { setState(() { search = searchController.text.trim(); page = 1; reload(); }); }
}

class _CreateCourseDialog extends StatefulWidget {
  const _CreateCourseDialog(this.repository);
  final CourseRepository repository;
  @override
  State<_CreateCourseDialog> createState() => _CreateCourseDialogState();
}

class _CreateCourseDialogState extends State<_CreateCourseDialog> {
  final key = GlobalKey<FormState>();
  final name = TextEditingController();
  final code = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController(text: '0.00');
  String mode = 'ONLINE';
  String? error;
  bool saving = false;
  @override
  void dispose() { name.dispose(); code.dispose(); description.dispose(); price.dispose(); super.dispose(); }

  Future<void> save() async {
    if (!key.currentState!.validate()) return;
    setState(() { saving = true; error = null; });
    try {
      await widget.repository.create(name: name.text, code: code.text,
        description: description.text, price: price.text.trim(), deliveryMode: mode);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) { if (mounted) setState(() => error = e.message); }
    finally { if (mounted) setState(() => saving = false); }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add course'),
    content: SizedBox(width: 420, child: SingleChildScrollView(child: Form(key: key, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Course name'), validator: requiredField),
      const SizedBox(height: 10),
      TextFormField(controller: code, decoration: const InputDecoration(labelText: 'Course code'), validator: requiredField),
      const SizedBox(height: 10),
      TextFormField(controller: description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
      const SizedBox(height: 10),
      TextFormField(controller: price, decoration: const InputDecoration(labelText: 'Price (₹)'), keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (v) => double.tryParse(v ?? '') == null || double.parse(v!) < 0 ? 'Enter a valid price' : null),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(value: mode, decoration: const InputDecoration(labelText: 'Delivery mode'),
        items: const [DropdownMenuItem(value: 'ONLINE', child: Text('Online')),
          DropdownMenuItem(value: 'OFFLINE', child: Text('Offline')),
          DropdownMenuItem(value: 'HYBRID', child: Text('Hybrid'))],
        onChanged: (value) => setState(() => mode = value ?? mode)),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
    ])))),
    actions: [TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Saving...' : 'Save'))],
  );
}

String? requiredField(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;
