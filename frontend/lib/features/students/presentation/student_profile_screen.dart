import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_exception.dart';
import '../data/student.dart';
import '../data/student_repository.dart';

class StudentProfileScreen extends ConsumerStatefulWidget {
  const StudentProfileScreen({super.key, required this.studentUuid});
  final String studentUuid;
  @override
  ConsumerState<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen> {
  late Future<Student> result;
  bool changing = false;
  @override
  void initState() { super.initState(); reload(); }
  void reload() { result = ref.read(studentRepositoryProvider).detail(widget.studentUuid); }

  Future<void> toggle(Student student) async {
    setState(() => changing = true);
    try {
      await ref.read(studentRepositoryProvider).setActive(student.uuid, !student.isActive);
      if (mounted) setState(reload);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally { if (mounted) setState(() => changing = false); }
  }

  Future<void> showEnableLoginDialog(Student student) async {
    final credentials = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _EnableLoginDialog(initialEmail: student.email),
    );
    if (credentials == null || !mounted) return;
    try {
      await ref.read(studentRepositoryProvider).enableLogin(student.uuid,
        email: credentials['email']!, password: credentials['password']!,
        confirmPassword: credentials['confirm_password']!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student login enabled.')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Student>(future: result, builder: (context, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
    if (snapshot.hasError) return Center(child: Text('Could not load student: ${snapshot.error}'));
    final s = snapshot.data!;
    return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextButton.icon(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back), label: const Text('Students')),
      Text(s.fullName, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Admission number: ${s.admissionNumber}'),
        Text('Email: ${s.email.isEmpty ? '—' : s.email}'),
        Text('Phone: ${s.phone.isEmpty ? '—' : s.phone}'),
        Text('Gender: ${s.gender.isEmpty ? '—' : s.gender}'),
        Text('Academy: ${s.firmName ?? '—'}'),
        Text('Joined: ${s.joinedDate ?? '—'}'),
        Text('Address: ${s.address.isEmpty ? '—' : s.address}'),
        Text('Status: ${s.isActive ? 'Active' : 'Inactive'}'),
      ]))),
      const SizedBox(height: 12),
      FilledButton.tonal(onPressed: () => showEnableLoginDialog(s), child: const Text('Enable student login')),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: changing ? null : () => toggle(s),
        child: Text(changing ? 'Updating...' : (s.isActive ? 'Deactivate student' : 'Activate student'))),
    ]));
  });
}

class _EnableLoginDialog extends StatefulWidget {
  const _EnableLoginDialog({required this.initialEmail});
  final String initialEmail;
  @override
  State<_EnableLoginDialog> createState() => _EnableLoginDialogState();
}

class _EnableLoginDialogState extends State<_EnableLoginDialog> {
  final form = GlobalKey<FormState>();
  late final email = TextEditingController(text: widget.initialEmail);
  final password = TextEditingController();
  final confirm = TextEditingController();
  @override
  void dispose() { email.dispose(); password.dispose(); confirm.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Enable student login'),
    content: SizedBox(width: 380, child: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: email, decoration: const InputDecoration(labelText: 'Email'),
        validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null),
      const SizedBox(height: 10),
      TextFormField(controller: password, obscureText: true,
        decoration: const InputDecoration(labelText: 'Password'),
        validator: (v) => v == null || v.length < 8 ? 'Use at least 8 characters' : null),
      const SizedBox(height: 10),
      TextFormField(controller: confirm, obscureText: true,
        decoration: const InputDecoration(labelText: 'Confirm password'),
        validator: (v) => v != password.text ? 'Passwords do not match' : null),
    ])))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () {
        if (!form.currentState!.validate()) return;
        Navigator.pop(context, <String, String>{
          'email': email.text.trim(), 'password': password.text,
          'confirm_password': confirm.text,
        });
      }, child: const Text('Enable'))],
  );
}
