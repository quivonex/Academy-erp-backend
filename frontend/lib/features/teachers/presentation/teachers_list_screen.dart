import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';

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

  Future<void> _openCreate() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateTeacherDialog(
        ref.read(teacherRepositoryProvider),
      ),
    );

    if (created == true && mounted) {
      setState(() {
        page = 1;
        reload();
      });
    }
  }

  void _setFilter(bool? value) {
    setState(() {
      activeFilter = value;
      page = 1;
      reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          eyebrow: const AdminEyebrow(
            section: 'Faculty',
            detail: 'Teacher directory & allotments',
          ),
          title: 'Teachers',
          titleTrailing: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: refresh,
            ),
          ],
          actions: [
            GradientButton(
              label: 'Add teacher',
              icon: Icons.person_add_alt_1_rounded,
              onPressed: _openCreate,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: FutureBuilder<TeacherPage>(
            future: result,
            builder: (context, snapshot) {
              final state = adminFutureState(
                snapshot,
                noun: 'teachers',
                onRetry: refresh,
              );
              final data = snapshot.data;
              final rows = data?.results ?? const <Teacher>[];
              final activeHere = rows.where((t) => t.isActive).length;
              final subjects = rows
                  .map((t) => t.specialization.trim())
                  .where((v) => v.isNotEmpty)
                  .toSet()
                  .length;
              final avgExp = rows.isEmpty
                  ? 0
                  : (rows.fold<int>(0, (a, t) => a + t.experienceYears) /
                          rows.length)
                      .round();

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  AdminKpiGrid(
                    children: [
                      AdminKpiCard(
                        label: 'Total teachers',
                        value: data == null ? '…' : '${data.count}',
                        icon: Icons.co_present_outlined,
                        caption: activeFilter == null
                            ? 'All statuses'
                            : activeFilter!
                                ? 'Active filter'
                                : 'Inactive filter',
                      ),
                      AdminKpiCard(
                        label: 'Active on this page',
                        value: data == null ? '…' : '$activeHere',
                        icon: Icons.verified_outlined,
                        iconBackground: const Color(0xFFECFDF5),
                        iconForeground: const Color(0xFF059669),
                      ),
                      AdminKpiCard(
                        label: 'Specializations',
                        value: data == null ? '…' : '$subjects',
                        icon: Icons.menu_book_outlined,
                        iconBackground: const Color(0xFFF5F3FF),
                        iconForeground: const Color(0xFF7C3AED),
                        caption: 'On this page',
                      ),
                      AdminKpiCard(
                        label: 'Avg. experience',
                        value: data == null ? '…' : '$avgExp yrs',
                        icon: Icons.workspace_premium_outlined,
                        iconBackground: const Color(0xFFFFFBEB),
                        iconForeground: const Color(0xFFD97706),
                        caption: 'On this page',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AdminToolbar(
                    controller: searchController,
                    hint: 'Search by name, employee ID or phone…',
                    onSearch: applySearch,
                    filters: [
                      CountFilterPill(
                        label: 'ALL',
                        selected: activeFilter == null,
                        onTap: () => _setFilter(null),
                      ),
                      CountFilterPill(
                        label: 'ACTIVE',
                        selected: activeFilter == true,
                        onTap: () => _setFilter(true),
                      ),
                      CountFilterPill(
                        label: 'INACTIVE',
                        selected: activeFilter == false,
                        onTap: () => _setFilter(false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (state != null)
                    state
                  else if (rows.isEmpty)
                    const AdminStateMessage(
                      icon: Icons.person_search_rounded,
                      title: 'No teachers found',
                      message: 'Try another search or status filter.',
                    )
                  else ...[
                    for (final teacher in rows)
                      AdminListRow(
                        title: teacher.fullName,
                        initials: adminInitials(teacher.fullName),
                        seed: teacher.employeeId,
                        titleBadge: SoftBadge(
                          label: teacher.employeeId,
                          monospace: true,
                          background: const Color(0xFFF1F5F9),
                          foreground: const Color(0xFF334155),
                        ),
                        subtitle: teacher.specialization.isEmpty
                            ? 'No specialization'
                            : teacher.specialization,
                        meta: [
                          MetaChip(
                            icon: Icons.workspace_premium_outlined,
                            label: '${teacher.experienceYears} yrs experience',
                          ),
                          if (teacher.email.isNotEmpty)
                            MetaChip(
                              icon: Icons.mail_outline_rounded,
                              label: teacher.email,
                            ),
                          if (teacher.phone.isNotEmpty)
                            MetaChip(
                              icon: Icons.call_outlined,
                              label: teacher.phone,
                            ),
                        ],
                        trailing: [ActiveBadge(active: teacher.isActive)],
                        onTap: () async {
                          await context.push('/teachers/${teacher.uuid}');
                          if (mounted) refresh();
                        },
                      ),
                    AdminPager(
                      page: page,
                      pageSize: 20,
                      total: data!.count,
                      noun: 'teachers',
                      onPage: changePage,
                    ),
                  ],
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
