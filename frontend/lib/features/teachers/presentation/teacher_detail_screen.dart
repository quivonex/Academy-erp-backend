import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';
import '../data/teacher.dart';
import '../data/teacher_repository.dart';

class TeacherDetailScreen extends ConsumerStatefulWidget {
  const TeacherDetailScreen({super.key, required this.teacherUuid});
  final String teacherUuid;

  @override
  ConsumerState<TeacherDetailScreen> createState() =>
      _TeacherDetailScreenState();
}

class _TeacherDetailScreenState extends ConsumerState<TeacherDetailScreen> {
  late Future<Teacher> result;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(covariant TeacherDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teacherUuid != widget.teacherUuid) reload();
  }

  void reload() {
    result = ref.read(teacherRepositoryProvider).detail(widget.teacherUuid);
  }

  void goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/teachers');
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> toggleStatus(Teacher teacher) async {
    if (busy) return;
    final repository = ref.read(teacherRepositoryProvider);
    final uuid = teacher.uuid;
    setState(() => busy = true);
    try {
      final updated = await repository.setActive(uuid, !teacher.isActive);
      if (!mounted || widget.teacherUuid != uuid) return;
      setState(() => result = Future<Teacher>.value(updated));
      showMessage(updated.isActive
          ? 'Teacher activated successfully.'
          : 'Teacher deactivated successfully.');
    } on ApiException catch (e) {
      if (mounted && widget.teacherUuid == uuid) showMessage(e.message);
    } catch (_) {
      if (mounted && widget.teacherUuid == uuid) {
        showMessage('Could not update teacher status. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editTeacher(Teacher teacher) async {
    if (busy) return;
    final repository = ref.read(teacherRepositoryProvider);
    final uuid = teacher.uuid;
    setState(() => busy = true);
    try {
      final updated = await showDialog<Teacher>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _EditTeacherDialog(
          teacher: teacher,
          repository: repository,
        ),
      );
      if (!mounted || updated == null || widget.teacherUuid != uuid) return;
      setState(() => result = Future<Teacher>.value(updated));
      showMessage('Teacher updated successfully.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Teacher>(
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
                  label: const Text('Teachers'),
                ),
              ),
              AdminStateMessage(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load teacher',
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

      final teacher = snapshot.data!;
      final name = teacher.fullName.trim().isEmpty
          ? teacher.employeeId
          : teacher.fullName;
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
                label: const Text('Teachers'),
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
                              label: teacher.employeeId,
                              monospace: true,
                            ),
                            ActiveBadge(active: teacher.isActive),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: busy ? null : () => setState(reload),
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
                    'Teacher information',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 14),
                  _InfoRow(label: 'Employee ID', value: teacher.employeeId),
                  _InfoRow(label: 'First name', value: teacher.firstName),
                  _InfoRow(label: 'Last name', value: teacher.lastName),
                  _InfoRow(label: 'Email', value: teacher.email),
                  _InfoRow(label: 'Phone', value: teacher.phone),
                  _InfoRow(label: 'Gender', value: teacher.gender ?? ''),
                  _InfoRow(
                    label: 'Qualification',
                    value: teacher.qualification ?? '',
                  ),
                  _InfoRow(
                    label: 'Specialization',
                    value: teacher.specialization,
                  ),
                  _InfoRow(
                    label: 'Experience years',
                    value: teacher.experienceYears.toString(),
                  ),
                  _InfoRow(
                    label: 'Joined date',
                    value: teacher.joinedDate ?? '',
                  ),
                  _InfoRow(
                    label: 'Academy',
                    value: teacher.firmName ?? '',
                  ),
                  _InfoRow(label: 'Address', value: teacher.address ?? ''),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                GradientButton(
                  label: 'Edit teacher',
                  icon: Icons.edit_outlined,
                  onPressed: busy ? null : () => editTeacher(teacher),
                ),
                AdminOutlineButton(
                  label: teacher.isActive
                      ? 'Deactivate teacher'
                      : 'Activate teacher',
                  icon: teacher.isActive
                      ? Icons.person_off_outlined
                      : Icons.person_outline_rounded,
                  danger: teacher.isActive,
                  onPressed: busy ? null : () => toggleStatus(teacher),
                ),
              ],
            ),
            if (busy) ...[
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

class _EditTeacherDialog extends StatefulWidget {
  const _EditTeacherDialog({
    required this.teacher,
    required this.repository,
  });

  final Teacher teacher;
  final TeacherRepository repository;

  @override
  State<_EditTeacherDialog> createState() => _EditTeacherDialogState();
}

class _EditTeacherDialogState extends State<_EditTeacherDialog> {
  final formKey = GlobalKey<FormState>();
  late final employeeId = TextEditingController(text: widget.teacher.employeeId);
  late final firstName = TextEditingController(text: widget.teacher.firstName);
  late final lastName = TextEditingController(text: widget.teacher.lastName);
  late final email = TextEditingController(text: widget.teacher.email);
  late final phone = TextEditingController(text: widget.teacher.phone);
  late final qualification = TextEditingController(text: widget.teacher.qualification ?? '');
  late final specialization = TextEditingController(text: widget.teacher.specialization);
  late final experience = TextEditingController(
    text: widget.teacher.experienceYears.toString(),
  );
  late final address = TextEditingController(text: widget.teacher.address ?? '');

  bool saving = false;
  String? error;

  @override
  void dispose() {
    employeeId.dispose();
    firstName.dispose();
    lastName.dispose();
    email.dispose();
    phone.dispose();
    qualification.dispose();
    specialization.dispose();
    experience.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    if (!(formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final years = int.parse(experience.text.trim());
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final updated = await widget.repository.update(
        widget.teacher.uuid,
        employeeId: employeeId.text,
        firstName: firstName.text,
        lastName: lastName.text,
        email: email.text,
        phone: phone.text,
        qualification: qualification.text,
        specialization: specialization.text,
        experienceYears: years,
        address: address.text,
      );
      if (!mounted) return;
      setState(() => saving = false);
      Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not update teacher. Please try again.');
      }
    } finally {
      if (mounted && saving) setState(() => saving = false);
    }
  }

  Widget field({
    required String label,
    required TextEditingController controller,
    bool mandatory = false,
    int? maxLength,
    int maxLines = 1,
    TextInputType? keyboardType,
    FormFieldValidator<String>? validator,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return FieldLabel(
      label: label,
      required: mandatory,
      child: TextFormField(
        controller: controller,
        enabled: !saving,
        maxLength: maxLength,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autocorrect: keyboardType != TextInputType.emailAddress,
        decoration: adminFieldDecoration(
          context,
          hint: mandatory ? 'Enter ${label.toLowerCase()}' : 'Optional',
        ),
        validator: validator ?? (mandatory ? requiredField : null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AdminFormDialog(
      icon: Icons.edit_outlined,
      title: 'Edit teacher',
      subtitle: 'Update this teacher’s information.',
      onClose: saving ? null : () => Navigator.of(context).pop(),
      body: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            field(
              label: 'Employee ID',
              controller: employeeId,
              mandatory: true,
              maxLength: 50,
            ),
            const SizedBox(height: 16),
            FormRow(
              left: field(
                label: 'First name',
                controller: firstName,
                mandatory: true,
                maxLength: 100,
              ),
              right: field(
                label: 'Last name',
                controller: lastName,
                maxLength: 100,
              ),
            ),
            const SizedBox(height: 16),
            field(
              label: 'Email',
              controller: email,
              maxLength: 254,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return null;
                return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                    .hasMatch(text)
                    ? null
                    : 'Enter a valid email';
              },
            ),
            const SizedBox(height: 16),
            field(
              label: 'Phone',
              controller: phone,
              maxLength: 20,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            field(
              label: 'Qualification',
              controller: qualification,
              maxLength: 255,
            ),
            const SizedBox(height: 16),
            field(
              label: 'Specialization',
              controller: specialization,
              maxLength: 255,
            ),
            const SizedBox(height: 16),
            field(
              label: 'Experience years',
              controller: experience,
              mandatory: true,
              keyboardType: TextInputType.number,
              validator: (value) {
                final years = int.tryParse((value ?? '').trim());
                return years == null || years < 0
                    ? 'Enter a whole number, 0 or greater'
                    : null;
              },
            ),
            const SizedBox(height: 16),
            field(
              label: 'Address',
              controller: address,
              maxLines: 3,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
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
          label: 'Save changes',
          icon: Icons.check_rounded,
          loading: saving,
          onPressed: saving ? null : save,
        ),
      ],
    ),
  );
}

String? requiredField(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;
