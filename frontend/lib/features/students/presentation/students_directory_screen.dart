import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_exception.dart';
import '../data/student.dart';
import '../data/student_repository.dart';

class StudentsDirectoryScreen extends ConsumerStatefulWidget {
  const StudentsDirectoryScreen({super.key});
  @override
  ConsumerState<StudentsDirectoryScreen> createState() => _StudentsDirectoryScreenState();
}

class _StudentsDirectoryScreenState extends ConsumerState<StudentsDirectoryScreen> {
  final searchController = TextEditingController();
  late Future<StudentPage> result;
  String search = '';
  int page = 1;

  @override
  void initState() { super.initState(); reload(); }
  void reload() { result = ref.read(studentRepositoryProvider).list(search: search, page: page); }
  void goToPage(int next) { setState(() { page = next; reload(); }); }
  @override
  void dispose() { searchController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Text('Students', style: Theme.of(context).textTheme.headlineSmall),
      FilledButton.icon(onPressed: () async {
        final created = await showDialog<bool>(context: context, builder: (_) => _CreateStudentDialog(ref.read(studentRepositoryProvider)));
        if (created == true && mounted) { setState(() { page = 1; reload(); }); }
      }, icon: const Icon(Icons.person_add_outlined), label: const Text('Add student')),
      IconButton(onPressed: () => setState(reload), icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
    ]),
    const SizedBox(height: 14),
    Row(children: [
      Expanded(child: TextField(controller: searchController,
        decoration: const InputDecoration(labelText: 'Name, admission number, email or phone'),
        onSubmitted: (_) => applySearch())),
      const SizedBox(width: 8),
      FilledButton(onPressed: applySearch, child: const Text('Search')),
    ]),
    const SizedBox(height: 12),
    Expanded(child: FutureBuilder<StudentPage>(future: result, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Could not load students: ${snapshot.error}'),
        TextButton(onPressed: () => setState(reload), child: const Text('Retry')),
      ]));
      final data = snapshot.data!;
      return Column(children: [
        Expanded(child: data.results.isEmpty ? const Center(child: Text('No students found.'))
          : ListView.builder(itemCount: data.results.length, itemBuilder: (context, index) {
            final student = data.results[index];
            return Card(child: ListTile(
              title: Text(student.fullName),
              subtitle: Text('${student.admissionNumber}  •  ${student.email}'),
              trailing: Chip(label: Text(student.isActive ? 'Active' : 'Inactive')),
              onTap: () async { await context.push('/students/${student.uuid}'); if (mounted) setState(reload); },
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

class _CreateStudentDialog extends StatefulWidget {
  const _CreateStudentDialog(this.repository);
  final StudentRepository repository;
  @override
  State<_CreateStudentDialog> createState() => _CreateStudentDialogState();
}

class _CreateStudentDialogState extends State<_CreateStudentDialog> {
  final key = GlobalKey<FormState>();
  final admission = TextEditingController();
  final first = TextEditingController();
  final last = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  bool saving = false;
  String? error;
  @override
  void dispose() { admission.dispose(); first.dispose(); last.dispose(); email.dispose(); phone.dispose(); super.dispose(); }

  Future<void> save() async {
    if (!key.currentState!.validate()) return;
    setState(() { saving = true; error = null; });
    try {
      await widget.repository.create(admissionNumber: admission.text, firstName: first.text,
        lastName: last.text, email: email.text, phone: phone.text);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) { if (mounted) setState(() => error = e.message); }
    finally { if (mounted) setState(() => saving = false); }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add student'),
    content: SizedBox(width: 420, child: SingleChildScrollView(child: Form(key: key, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: admission, decoration: const InputDecoration(labelText: 'Admission number'), validator: requiredField),
      const SizedBox(height: 10),
      TextFormField(controller: first, decoration: const InputDecoration(labelText: 'First name'), validator: requiredField),
      const SizedBox(height: 10),
      TextFormField(controller: last, decoration: const InputDecoration(labelText: 'Last name')),
      const SizedBox(height: 10),
      TextFormField(controller: email, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress,
        validator: (v) => v != null && v.isNotEmpty && !v.contains('@') ? 'Invalid email' : null),
      const SizedBox(height: 10),
      TextFormField(controller: phone, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
    ])))),
    actions: [TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Saving...' : 'Save'))],
  );
}

String? requiredField(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;
