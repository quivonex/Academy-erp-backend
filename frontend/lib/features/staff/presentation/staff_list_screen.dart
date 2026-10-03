import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';
import '../data/staff.dart';
import '../data/staff_repository.dart';

class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({super.key});
  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  final searchController = TextEditingController();
  late Future<StaffPage> result;
  String search = '';
  int page = 1;
  bool creating = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    result = ref.read(staffRepositoryProvider).list(search: search, page: page);
  }

  void goToPage(int next) {
    setState(() {
      page = next;
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
    final repository = ref.read(staffRepositoryProvider);
    setState(() => creating = true);
    try {
      final created = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CreateStaffDialog(repository),
      );
      if (!mounted || created != true) return;
      setState(() {
        searchController.clear();
        search = '';
        page = 1;
        reload();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff created successfully.')),
      );
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AdminPageHeader(
        eyebrow: const AdminEyebrow(
          section: 'Team',
          detail: 'Staff directory & departments',
        ),
        title: 'Staff',
        titleTrailing: [
          IconButton(
            onPressed: () => setState(reload),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
        actions: [
          GradientButton(
            label: 'Add staff',
            icon: Icons.person_add_alt_1_rounded,
            onPressed: creating ? null : _openCreate,
          ),
        ],
      ),
      const SizedBox(height: 20),
      Expanded(
        child: FutureBuilder<StaffPage>(
          future: result,
          builder: (context, snapshot) {
            final state = adminFutureState(
              snapshot,
              noun: 'staff',
              onRetry: () => setState(reload),
            );
            final data = snapshot.connectionState == ConnectionState.done &&
                !snapshot.hasError
                ? snapshot.data
                : null;
            final onPage = data?.results ?? const <Staff>[];
            final activeHere = onPage.where((s) => s.isActive).length;

            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                AdminKpiGrid(
                  children: [
                    AdminKpiCard(
                      label: search.isEmpty ? 'Total staff' : 'Matching staff',
                      value: data == null ? '…' : '${data.count}',
                      icon: Icons.groups_rounded,
                      caption: search.isEmpty ? 'All staff members' : 'Current search',
                    ),
                    AdminKpiCard(
                      label: 'Active on this page',
                      value: data == null ? '…' : '$activeHere',
                      icon: Icons.verified_outlined,
                      iconBackground: const Color(0xFFECFDF5),
                      iconForeground: const Color(0xFF059669),
                      caption: data == null || onPage.isEmpty
                          ? null
                          : '${(activeHere * 100 / onPage.length).round()}% active',
                      captionColor: const Color(0xFF059669),
                    ),
                    AdminKpiCard(
                      label: 'Inactive on this page',
                      value: data == null
                          ? '…'
                          : '${onPage.length - activeHere}',
                      icon: Icons.person_off_outlined,
                      iconBackground: const Color(0xFFFFF1F2),
                      iconForeground: const Color(0xFFE11D48),
                    ),
                    AdminKpiCard(
                      label: 'Current page',
                      value: '$page',
                      icon: Icons.layers_outlined,
                      iconBackground: const Color(0xFFF0F9FF),
                      iconForeground: const Color(0xFF0284C7),
                      caption: '20 per page',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                AdminToolbar(
                  controller: searchController,
                  hint: 'Search by name, employee ID, designation or department…',
                  onSearch: applySearch,
                ),
                const SizedBox(height: 18),
                if (state != null)
                  state
                else if (onPage.isEmpty)
                  AdminStateMessage(
                    icon: Icons.person_search_rounded,
                    title: 'No staff found',
                    message: search.isEmpty
                        ? 'Add your first staff to get started.'
                        : 'Try a different search.',
                  )
                else ...[
                    for (final staff in onPage)
                      AdminListRow(
                        title: staff.fullName.trim().isEmpty
                            ? staff.employeeId
                            : staff.fullName,
                        initials: adminInitials(staff.fullName.trim().isEmpty
                            ? staff.employeeId
                            : staff.fullName),
                        seed: staff.employeeId,
                        titleBadge: SoftBadge(
                          label: staff.employeeId,
                          monospace: true,
                          background: const Color(0xFFF1F5F9),
                          foreground: const Color(0xFF334155),
                        ),
                        subtitle: staff.designation.isEmpty
                            ? 'Staff'
                            : staff.designation,
                        meta: [
                          if (staff.department.isNotEmpty)
                            MetaChip(
                              icon: Icons.business_outlined,
                              label: staff.department,
                            ),
                          if (staff.email.isNotEmpty)
                            MetaChip(
                              icon: Icons.mail_outline_rounded,
                              label: staff.email,
                            ),
                          if (staff.phone.isNotEmpty)
                            MetaChip(
                              icon: Icons.call_outlined,
                              label: staff.phone,
                            ),
                          if ((staff.joinedDate ?? '').isNotEmpty)
                            MetaChip(
                              icon: Icons.event_outlined,
                              label: 'Joined ${staff.joinedDate}',
                            ),
                        ],
                        trailing: [ActiveBadge(active: staff.isActive)],
                        onTap: () async {
                          await context.push('/staff/${staff.uuid}');
                          if (mounted) setState(reload);
                        },
                      ),
                    AdminPager(
                      page: page,
                      pageSize: 20,
                      total: data!.count,
                      noun: 'staff',
                      onPage: goToPage,
                    ),
                  ],
              ],
            );
          },
        ),
      ),
    ],
  );

  void applySearch() {
    setState(() {
      search = searchController.text.trim();
      page = 1;
      reload();
    });
  }
}

class _CreateStaffDialog extends StatefulWidget {
  const _CreateStaffDialog(
      this.repository,
      );

  final StaffRepository repository;

  @override
  State<_CreateStaffDialog> createState() => _CreateStaffDialogState();
}

class _CreateStaffDialogState extends State<_CreateStaffDialog> {
  final formKey = GlobalKey<FormState>();
  final employeeId = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final designation = TextEditingController();
  final department = TextEditingController();
  final address = TextEditingController();

  DateTime? joinedDate;
  bool saving = false;
  String? error;

  @override
  void dispose() {
    employeeId.dispose();
    firstName.dispose();
    lastName.dispose();
    email.dispose();
    phone.dispose();
    designation.dispose();
    department.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    if (!(formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

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
        designation: designation.text,
        department: department.text,
        joinedDate: joinedDate,
        address: address.text,
      );
      if (!mounted) return;
      setState(() => saving = false);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not create staff. Please try again.');
      }
    } finally {
      if (mounted && saving) setState(() => saving = false);
    }
  }

  Future<void> pickJoinedDate() async {
    if (saving) return;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: joinedDate ?? DateTime.now(),
    );
    if (!mounted || saving || picked == null) return;
    setState(() => joinedDate = picked);
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
      title: 'Add staff',
      subtitle: 'Create a staff record for your academy.',
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
              label: 'Designation',
              controller: designation,
              maxLength: 150,
            ),
            const SizedBox(height: 16),
            field(
              label: 'Department',
              controller: department,
              maxLength: 150,
            ),
            const SizedBox(height: 16),
            field(
              label: 'Address',
              controller: address,
              maxLines: 3,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 16),
            FieldLabel(
              label: 'Joined date',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(joinedDate == null
                    ? 'Select date (optional)'
                    : '${joinedDate!.year}-'
                    '${joinedDate!.month.toString().padLeft(2, '0')}-'
                    '${joinedDate!.day.toString().padLeft(2, '0')}'),
                leading: const Icon(Icons.calendar_today_outlined),
                trailing: joinedDate == null
                    ? null
                    : IconButton(
                  tooltip: 'Clear joined date',
                  onPressed: saving
                      ? null
                      : () => setState(() => joinedDate = null),
                  icon: const Icon(Icons.clear_rounded),
                ),
                onTap: saving ? null : pickJoinedDate,
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
          label: 'Save staff',
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
