import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';

import '../data/teacher.dart';
import '../data/teacher_repository.dart';

class TeachersListScreen extends ConsumerStatefulWidget {
  const TeachersListScreen({
    super.key,
  });

  @override
  ConsumerState<TeachersListScreen> createState() =>
      _TeachersListScreenState();
}

class _TeachersListScreenState extends ConsumerState<TeachersListScreen> {
  final searchController = TextEditingController();

  late Future<TeacherPage> result;

  String search = '';

  bool? activeFilter;

  int page = 1;

  @override
  void initState() {
    super.initState();

    reload();
  }

  void reload() {
    result = ref.read(teacherRepositoryProvider).list(
          search: search,
          isActive: activeFilter,
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

  void changePage(int value) {
    setState(() {
      page = value;

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
              'Teachers',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            FilledButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text('Add Teacher'),
              onPressed: () async {
                final created = await showDialog<bool>(
                  context: context,
                  builder: (_) => _CreateTeacherDialog(
                    ref.read(
                      teacherRepositoryProvider,
                    ),
                  ),
                );

                if (created == true && mounted) {
                  setState(() {
                    page = 1;

                    reload();
                  });
                }
              },
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: refresh,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 350,
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Search teacher',
                  hintText: 'Name, employee ID, phone...',
                ),
                onSubmitted: (_) => applySearch(),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                value: activeFilter == null
                    ? 'ALL'
                    : activeFilter!
                        ? 'ACTIVE'
                        : 'INACTIVE',
                decoration: const InputDecoration(
                  labelText: 'Status',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'ALL',
                    child: Text('All'),
                  ),
                  DropdownMenuItem(
                    value: 'ACTIVE',
                    child: Text('Active'),
                  ),
                  DropdownMenuItem(
                    value: 'INACTIVE',
                    child: Text('Inactive'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    if (value == 'ACTIVE') {
                      activeFilter = true;
                    } else if (value == 'INACTIVE') {
                      activeFilter = false;
                    } else {
                      activeFilter = null;
                    }

                    page = 1;

                    reload();
                  });
                },
              ),
            ),
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
                        'Could not load teachers:\n${snapshot.error}',
                      ),
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
                  child: Text(
                    'No teachers found.',
                  ),
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: data.results.length,
                      itemBuilder: (context, index) {
                        final teacher = data.results[index];

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                teacher.fullName.isNotEmpty
                                    ? teacher.fullName[0].toUpperCase()
                                    : 'T',
                              ),
                            ),
                            title: Text(
                              teacher.fullName,
                            ),
                            subtitle: Text(
                              '${teacher.employeeId}'
                              ' • '
                              '${teacher.specialization.isEmpty ? 'No specialization' : teacher.specialization}',
                            ),
                            trailing: Chip(
                              label: Text(
                                teacher.isActive ? 'Active' : 'Inactive',
                              ),
                            ),
                            onTap: () async {
                              await context.push(
                                '/teachers/${teacher.uuid}',
                              );

                              if (mounted) {
                                refresh();
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${data.count} total • Page $page',
                      ),
                      IconButton(
                        onPressed:
                            page > 1 ? () => changePage(page - 1) : null,
                        icon: const Icon(
                          Icons.chevron_left,
                        ),
                      ),
                      IconButton(
                        onPressed: page * 20 < data.count
                            ? () => changePage(page + 1)
                            : null,
                        icon: const Icon(
                          Icons.chevron_right,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CreateTeacherDialog extends StatefulWidget {
  const _CreateTeacherDialog(
    this.repository,
  );

  final TeacherRepository repository;

  @override
  State<_CreateTeacherDialog> createState() => _CreateTeacherDialogState();
}

class _CreateTeacherDialogState extends State<_CreateTeacherDialog> {
  final formKey = GlobalKey<FormState>();

  final employeeId = TextEditingController();

  final firstName = TextEditingController();

  final lastName = TextEditingController();

  final email = TextEditingController();

  final phone = TextEditingController();

  final qualification = TextEditingController();

  final specialization = TextEditingController();

  final experience = TextEditingController(text: '0');

  final address = TextEditingController();

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
    if (!formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await widget.repository.create(
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
      title: const Text('Add Teacher'),
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
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
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
                      top: 12,
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
            saving ? 'Saving...' : 'Save Teacher',
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
