import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../data/teacher.dart';
import '../data/teacher_repository.dart';

class TeacherDetailScreen extends ConsumerStatefulWidget {
  const TeacherDetailScreen({
    super.key,
    required this.teacherUuid,
  });

  final String teacherUuid;

  @override
  ConsumerState<TeacherDetailScreen> createState() =>
      _TeacherDetailScreenState();
}

class _TeacherDetailScreenState extends ConsumerState<TeacherDetailScreen> {
  late Future<Teacher> result;

  bool changingStatus = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    result = ref.read(teacherRepositoryProvider).detail(widget.teacherUuid);
  }

  Future<void> toggleStatus(Teacher teacher) async {
    setState(() {
      changingStatus = true;
    });

    try {
      await ref.read(teacherRepositoryProvider).setActive(
            teacher.uuid,
            !teacher.isActive,
          );

      if (mounted) {
        setState(reload);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              teacher.isActive
                  ? 'Teacher deactivated successfully.'
                  : 'Teacher activated successfully.',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          changingStatus = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Teacher>(
      future: result,
      builder: (
        context,
        snapshot,
      ) {
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
                Text(
                  'Could not load teacher:\n${snapshot.error}',
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(reload);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final teacher = snapshot.data!;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(
                  Icons.arrow_back,
                ),
                label: const Text('Teachers'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    child: Text(
                      teacher.fullName.isNotEmpty
                          ? teacher.fullName[0].toUpperCase()
                          : 'T',
                      style: const TextStyle(
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          teacher.fullName,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          teacher.employeeId,
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(
                      teacher.isActive ? 'Active' : 'Inactive',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Teacher Information',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 18),
                      _InfoRow(
                        label: 'Employee ID',
                        value: teacher.employeeId,
                      ),
                      _InfoRow(
                        label: 'First Name',
                        value: teacher.firstName,
                      ),
                      _InfoRow(
                        label: 'Last Name',
                        value: teacher.lastName,
                      ),
                      _InfoRow(
                        label: 'Email',
                        value: teacher.email.isEmpty ? '—' : teacher.email,
                      ),
                      _InfoRow(
                        label: 'Phone',
                        value: teacher.phone.isEmpty ? '—' : teacher.phone,
                      ),
                      _InfoRow(
                        label: 'Gender',
                        value: teacher.gender?.isNotEmpty == true
                            ? teacher.gender!
                            : '—',
                      ),
                      _InfoRow(
                        label: 'Qualification',
                        value: teacher.qualification?.isNotEmpty == true
                            ? teacher.qualification!
                            : '—',
                      ),
                      _InfoRow(
                        label: 'Specialization',
                        value: teacher.specialization.isEmpty
                            ? '—'
                            : teacher.specialization,
                      ),
                      _InfoRow(
                        label: 'Experience Years',
                        value: teacher.experienceYears.toString(),
                      ),
                      _InfoRow(
                        label: 'Joined Date',
                        value: teacher.joinedDate?.isNotEmpty == true
                            ? teacher.joinedDate!
                            : '—',
                      ),
                      _InfoRow(
                        label: 'Academy',
                        value: teacher.firmName?.isNotEmpty == true
                            ? teacher.firmName!
                            : '—',
                      ),
                      _InfoRow(
                        label: 'Address',
                        value: teacher.address?.isNotEmpty == true
                            ? teacher.address!
                            : '—',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Teacher'),
                    onPressed: () async {
                      final updated = await showDialog<bool>(
                        context: context,
                        builder: (_) => _EditTeacherDialog(
                          teacher: teacher,
                          repository: ref.read(
                            teacherRepositoryProvider,
                          ),
                        ),
                      );

                      if (updated == true && mounted) {
                        setState(reload);
                      }
                    },
                  ),
                  OutlinedButton.icon(
                    icon: Icon(
                      teacher.isActive ? Icons.block : Icons.check_circle,
                    ),
                    label: Text(
                      changingStatus
                          ? 'Updating...'
                          : teacher.isActive
                              ? 'Deactivate Teacher'
                              : 'Activate Teacher',
                    ),
                    onPressed: changingStatus
                        ? null
                        : () => toggleStatus(
                              teacher,
                            ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
            ),
          ),
        ],
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

  late final TextEditingController employeeId;

  late final TextEditingController firstName;

  late final TextEditingController lastName;

  late final TextEditingController email;

  late final TextEditingController phone;

  late final TextEditingController qualification;

  late final TextEditingController specialization;

  late final TextEditingController experience;

  late final TextEditingController address;

  bool saving = false;

  String? error;

  @override
  void initState() {
    super.initState();

    final teacher = widget.teacher;

    employeeId = TextEditingController(
      text: teacher.employeeId,
    );

    firstName = TextEditingController(
      text: teacher.firstName,
    );

    lastName = TextEditingController(
      text: teacher.lastName,
    );

    email = TextEditingController(
      text: teacher.email,
    );

    phone = TextEditingController(
      text: teacher.phone,
    );

    qualification = TextEditingController(
      text: teacher.qualification ?? '',
    );

    specialization = TextEditingController(
      text: teacher.specialization,
    );

    experience = TextEditingController(
      text: teacher.experienceYears.toString(),
    );

    address = TextEditingController(
      text: teacher.address ?? '',
    );
  }

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
    if (!formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await widget.repository.update(
        widget.teacher.uuid,
        employeeId: employeeId.text,
        firstName: firstName.text,
        lastName: lastName.text,
        email: email.text,
        phone: phone.text,
        qualification: qualification.text,
        specialization: specialization.text,
        experienceYears: int.tryParse(
              experience.text,
            ) ??
            0,
        address: address.text,
      );

      if (mounted) {
        Navigator.pop(
          context,
          true,
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Teacher'),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: employeeId,
                  decoration: const InputDecoration(
                    labelText: 'Employee ID',
                  ),
                  validator: requiredField,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: firstName,
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                  ),
                  validator: requiredField,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: lastName,
                  decoration: const InputDecoration(
                    labelText: 'Last Name',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: email,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: qualification,
                  decoration: const InputDecoration(
                    labelText: 'Qualification',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: specialization,
                  decoration: const InputDecoration(
                    labelText: 'Specialization',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: experience,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Experience Years',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: address,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 10,
                    ),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving
              ? null
              : () => Navigator.pop(
                    context,
                  ),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(
            saving ? 'Saving...' : 'Save Changes',
          ),
        ),
      ],
    );
  }
}

String? requiredField(
  String? value,
) {
  if (value == null || value.trim().isEmpty) {
    return 'Required';
  }

  return null;
}
