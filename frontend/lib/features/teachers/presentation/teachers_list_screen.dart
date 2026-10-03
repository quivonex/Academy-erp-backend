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

  bool creating = false;

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
    if (creating) return;
    final repository = ref.read(teacherRepositoryProvider);
    setState(() => creating = true);
    try {
      final created = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CreateTeacherDialog(repository),
      );
      if (!mounted || created != true) return;
      setState(() {
        searchController.clear();
        search = '';
        activeFilter = null;
        page = 1;
        reload();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teacher created successfully.')),
      );
    } finally {
      if (mounted) setState(() => creating = false);
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
              onPressed: creating ? null : _openCreate,
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
              final data = snapshot.connectionState == ConnectionState.done &&
                  !snapshot.hasError
                  ? snapshot.data
                  : null;
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
                        label: search.isEmpty && activeFilter == null
                            ? 'Total teachers'
                            : 'Matching teachers',
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
    if (saving) return;
    if (!(formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final years = int.parse(experience.text.trim());
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
        experienceYears: years,
        address: address.text,
      );
      if (!mounted) return;
      setState(() => saving = false);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not create teacher. Please try again.');
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
      icon: Icons.person_add_alt_1_rounded,
      title: 'Add teacher',
      subtitle: 'Create a teacher record for your academy.',
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
          label: 'Save teacher',
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
