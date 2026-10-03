import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';
import '../data/staff.dart';
import '../data/staff_repository.dart';

class StaffDetailScreen extends ConsumerStatefulWidget {
  const StaffDetailScreen({super.key, required this.staffUuid});
  final String staffUuid;

  @override
  ConsumerState<StaffDetailScreen> createState() =>
      _StaffDetailScreenState();
}

class _StaffDetailScreenState extends ConsumerState<StaffDetailScreen> {
  late Future<Staff> result;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(covariant StaffDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.staffUuid != widget.staffUuid) reload();
  }

  void reload() {
    result = ref.read(staffRepositoryProvider).detail(widget.staffUuid);
  }

  void goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/staff');
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> toggleStatus(Staff staff) async {
    if (busy) return;
    final repository = ref.read(staffRepositoryProvider);
    final uuid = staff.uuid;
    setState(() => busy = true);
    try {
      final updated = await repository.setActive(
        uuid: uuid,
        active: !staff.isActive,
      );
      if (!mounted || widget.staffUuid != uuid) return;
      setState(() => result = Future<Staff>.value(updated));
      showMessage(updated.isActive
          ? 'Staff activated successfully.'
          : 'Staff deactivated successfully.');
    } on ApiException catch (e) {
      if (mounted && widget.staffUuid == uuid) showMessage(e.message);
    } catch (_) {
      if (mounted && widget.staffUuid == uuid) {
        showMessage('Could not update staff status. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editStaff(Staff staff) async {
    if (busy) return;
    final repository = ref.read(staffRepositoryProvider);
    final uuid = staff.uuid;
    setState(() => busy = true);
    try {
      final updated = await showDialog<Staff>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _EditStaffDialog(
          staff: staff,
          repository: repository,
        ),
      );
      if (!mounted || updated == null || widget.staffUuid != uuid) return;
      setState(() => result = Future<Staff>.value(updated));
      showMessage('Staff updated successfully.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Staff>(
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
                  label: const Text('Staff'),
                ),
              ),
              AdminStateMessage(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load staff',
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

      final staff = snapshot.data!;
      final name = staff.fullName.trim().isEmpty
          ? staff.employeeId
          : staff.fullName;
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
                label: const Text('Staff'),
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
                              label: staff.employeeId,
                              monospace: true,
                            ),
                            ActiveBadge(active: staff.isActive),
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
                    'Staff information',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 14),
                  _InfoRow(label: 'Employee ID', value: staff.employeeId),
                  _InfoRow(label: 'First name', value: staff.firstName),
                  _InfoRow(label: 'Last name', value: staff.lastName),
                  _InfoRow(label: 'Email', value: staff.email),
                  _InfoRow(label: 'Phone', value: staff.phone),
                  _InfoRow(
                    label: 'Designation',
                    value: staff.designation,
                  ),
                  _InfoRow(
                    label: 'Department',
                    value: staff.department,
                  ),
                  _InfoRow(
                    label: 'Joined date',
                    value: staff.joinedDate ?? '',
                  ),
                  _InfoRow(
                    label: 'Academy',
                    value: staff.firmName ?? '',
                  ),
                  _InfoRow(label: 'Address', value: staff.address),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                GradientButton(
                  label: 'Edit staff',
                  icon: Icons.edit_outlined,
                  onPressed: busy ? null : () => editStaff(staff),
                ),
                AdminOutlineButton(
                  label: staff.isActive
                      ? 'Deactivate staff'
                      : 'Activate staff',
                  icon: staff.isActive
                      ? Icons.person_off_outlined
                      : Icons.person_outline_rounded,
                  danger: staff.isActive,
                  onPressed: busy ? null : () => toggleStatus(staff),
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

class _EditStaffDialog extends StatefulWidget {
  const _EditStaffDialog({
    required this.staff,
    required this.repository,
  });

  final Staff staff;
  final StaffRepository repository;

  @override
  State<_EditStaffDialog> createState() => _EditStaffDialogState();
}

class _EditStaffDialogState extends State<_EditStaffDialog> {
  final formKey = GlobalKey<FormState>();
  late final employeeId = TextEditingController(text: widget.staff.employeeId);
  late final firstName = TextEditingController(text: widget.staff.firstName);
  late final lastName = TextEditingController(text: widget.staff.lastName);
  late final email = TextEditingController(text: widget.staff.email);
  late final phone = TextEditingController(text: widget.staff.phone);
  late final designation = TextEditingController(text: widget.staff.designation);
  late final department = TextEditingController(text: widget.staff.department);
  late final address = TextEditingController(text: widget.staff.address);

  late DateTime? joinedDate = DateTime.tryParse(widget.staff.joinedDate ?? '');
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
      final updated = await widget.repository.update(
        uuid: widget.staff.uuid,
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
      Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not update staff. Please try again.');
      }
    } finally {
      if (mounted && saving) setState(() => saving = false);
    }
  }

  DateTime pickerInitialDate() {
    final date = joinedDate ?? DateTime.now();
    final firstDate = DateTime(1900);
    final lastDate = DateTime(2100);
    if (date.isBefore(firstDate)) return firstDate;
    if (date.isAfter(lastDate)) return lastDate;
    return date;
  }

  Future<void> pickJoinedDate() async {
    if (saving) return;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      initialDate: pickerInitialDate(),
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
      icon: Icons.edit_outlined,
      title: 'Edit staff',
      subtitle: 'Update this staff member’s information.',
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
                  tooltip: 'Reset joined date',
                  onPressed: saving
                      ? null
                      : () => setState(() {
                    joinedDate = DateTime.tryParse(
                      widget.staff.joinedDate ?? '',
                    );
                  }),
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
