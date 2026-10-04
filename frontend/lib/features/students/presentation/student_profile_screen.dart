import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';
import '../data/student.dart';
import '../data/student_repository.dart';
import 'student_edit_screen.dart';

class StudentProfileScreen extends ConsumerStatefulWidget {
  const StudentProfileScreen({super.key, required this.studentUuid});

  final String studentUuid;

  @override
  ConsumerState<StudentProfileScreen> createState() =>
      _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen> {
  late Future<Student> result;
  bool changing = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(covariant StudentProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentUuid != widget.studentUuid) reload();
  }

  void reload() {
    result = ref.read(studentRepositoryProvider).detail(widget.studentUuid);
  }

  void goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/students');
    }
  }

  Future<void> toggle(Student student) async {
    if (changing) return;
    final repository = ref.read(studentRepositoryProvider);
    final studentUuid = student.uuid;
    setState(() => changing = true);
    try {
      final updated = await repository.setActive(
        studentUuid,
        !student.isActive,
      );
      if (!mounted || widget.studentUuid != studentUuid) return;
      setState(() => result = Future<Student>.value(updated));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(updated.isActive
              ? 'Student activated successfully.'
              : 'Student deactivated successfully.'),
        ),
      );
    } on ApiException catch (e) {
      if (mounted && widget.studentUuid == studentUuid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted && widget.studentUuid == studentUuid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update student status. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => changing = false);
    }
  }

  Future<void> showEnableLoginDialog(Student student) async {
    if (changing) return;
    final repository = ref.read(studentRepositoryProvider);
    final studentUuid = student.uuid;
    setState(() => changing = true);
    try {
      final enabled = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _EnableLoginDialog(
          repository: repository,
          studentUuid: studentUuid,
          initialEmail: student.email,
        ),
      );
      if (!mounted || enabled != true ||
          widget.studentUuid != studentUuid) return;
      setState(reload);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student login enabled successfully.')),
      );
    } finally {
      if (mounted) setState(() => changing = false);
    }
  }

  Future<void> editStudent(Student student) async {
    if (changing) return;

    final uuid = student.uuid;
    setState(() => changing = true);

    try {
      final updated = await showDialog<Student>(
        context: context,
        barrierDismissible: false,
        builder: (_) => StudentEditScreen(student: student),
      );

      if (!mounted ||
          updated == null ||
          widget.studentUuid != uuid) {
        return;
      }

      setState(() {
        result = Future<Student>.value(updated);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student updated successfully.'),
        ),
      );
    } finally {
      if (mounted) setState(() => changing = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Student>(
    future: result,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError || !snapshot.hasData) {
        final error = snapshot.error;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: goBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Students'),
                ),
              ),
              AdminStateMessage(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load student',
                message: error is ApiException
                    ? error.message
                    : 'Please try again.',
                actionLabel: 'Retry',
                onAction: () => setState(reload),
                isError: true,
              ),
            ],
          ),
        );
      }

      final student = snapshot.data!;
      final name = student.fullName.trim().isEmpty
          ? student.admissionNumber
          : student.fullName;

      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: goBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Students'),
              ),
            ),
            const SizedBox(height: 8),
            AdminCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InitialsBadge(label: adminInitials(name)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SoftBadge(
                              label: student.admissionNumber,
                              monospace: true,
                            ),
                            ActiveBadge(active: student.isActive),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: changing ? null : () => setState(reload),
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Student information',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 14),
                  _InfoRow(
                    label: 'Admission number',
                    value: student.admissionNumber,
                  ),
                  _InfoRow(label: 'Email', value: student.email),
                  _InfoRow(label: 'Phone', value: student.phone),
                  _InfoRow(label: 'Gender', value: student.gender),
                  _InfoRow(
                    label: 'Date of birth',
                    value: student.dateOfBirth ?? '',
                  ),
                  _InfoRow(
                    label: 'Academy',
                    value: student.firmName ?? '',
                  ),
                  _InfoRow(
                    label: 'Joined',
                    value: student.joinedDate ?? '',
                  ),
                  _InfoRow(label: 'Address', value: student.address),
                  _InfoRow(
                    label: 'Status',
                    value: student.isActive ? 'Active' : 'Inactive',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                AdminOutlineButton(
                  label: 'Edit student',
                  icon: Icons.edit_outlined,
                  onPressed: changing ? null : () => editStudent(student),
                ),
                GradientButton(
                  label: 'Enable student login',
                  icon: Icons.lock_open_rounded,
                  onPressed: changing
                      ? null
                      : () => showEnableLoginDialog(student),
                ),
                AdminOutlineButton(
                  label: student.isActive
                      ? 'Deactivate student'
                      : 'Activate student',
                  icon: student.isActive
                      ? Icons.person_off_outlined
                      : Icons.person_outline_rounded,
                  danger: student.isActive,
                  onPressed: changing ? null : () => toggle(student),
                ),
              ],
            ),
            if (changing) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      );
    },
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final labelWidget = Text(label, style: textTheme.bodySmall);
    final valueWidget = SelectableText(
      value.trim().isEmpty ? '—' : value,
      style: textTheme.bodyMedium,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 480) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget,
                const SizedBox(height: 4),
                valueWidget,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 160, child: labelWidget),
              const SizedBox(width: 16),
              Expanded(child: valueWidget),
            ],
          );
        },
      ),
    );
  }
}

class _EnableLoginDialog extends StatefulWidget {
  const _EnableLoginDialog({
    required this.repository,
    required this.studentUuid,
    required this.initialEmail,
  });

  final StudentRepository repository;
  final String studentUuid;
  final String initialEmail;

  @override
  State<_EnableLoginDialog> createState() => _EnableLoginDialogState();
}

class _EnableLoginDialogState extends State<_EnableLoginDialog> {
  final form = GlobalKey<FormState>();
  late final email = TextEditingController(text: widget.initialEmail);
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool saving = false;
  bool obscure = true;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (saving) return;
    if (!(form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.repository.enableLogin(
        widget.studentUuid,
        email: email.text.trim(),
        password: password.text,
        confirmPassword: confirm.text,
      );
      if (!mounted) return;
      setState(() => saving = false);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not enable login. Please try again.');
      }
    } finally {
      if (mounted && saving) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AdminFormDialog(
      icon: Icons.lock_open_rounded,
      title: 'Enable student login',
      subtitle: 'Create login credentials for this student.',
      onClose: saving ? null : () => Navigator.of(context).pop(),
      body: Form(
        key: form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldLabel(
              label: 'Email',
              required: true,
              child: TextFormField(
                controller: email,
                enabled: !saving,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: adminFieldDecoration(
                  context,
                  hint: 'student@academy.edu',
                  icon: Icons.mail_outline_rounded,
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                      .hasMatch(text)
                      ? null
                      : 'Enter a valid email';
                },
              ),
            ),
            const SizedBox(height: 16),
            FieldLabel(
              label: 'Password',
              required: true,
              child: TextFormField(
                controller: password,
                enabled: !saving,
                obscureText: obscure,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
                decoration: adminFieldDecoration(
                  context,
                  hint: 'At least 8 characters',
                  icon: Icons.lock_outline_rounded,
                  suffix: IconButton(
                    tooltip: obscure ? 'Show passwords' : 'Hide passwords',
                    onPressed: saving
                        ? null
                        : () => setState(() => obscure = !obscure),
                    icon: Icon(obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.length < 8) {
                    return 'Use at least 8 characters';
                  }
                  if (value != value.trim()) {
                    return 'Avoid spaces at the start or end';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            FieldLabel(
              label: 'Confirm password',
              required: true,
              child: TextFormField(
                controller: confirm,
                enabled: !saving,
                obscureText: obscure,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                decoration: adminFieldDecoration(
                  context,
                  hint: 'Repeat password',
                  icon: Icons.verified_user_outlined,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Confirm your password';
                  }
                  return value != password.text
                      ? 'Passwords do not match'
                      : null;
                },
                onFieldSubmitted: (_) => submit(),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              AdminErrorBanner(message: error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        GradientButton(
          label: 'Enable login',
          icon: Icons.check_rounded,
          loading: saving,
          onPressed: saving ? null : submit,
        ),
      ],
    ),
  );
}
