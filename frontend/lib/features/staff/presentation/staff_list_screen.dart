import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/staff.dart';
import '../data/staff_repository.dart';

class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({
    super.key,
  });

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  final searchController = TextEditingController();

  late Future<StaffPage> result;

  String search = '';
  int page = 1;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    result = ref.read(staffRepositoryProvider).list(
          search: search,
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

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Staff',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: refresh,
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () async {
                final created = await _showCreateDialog();

                if (created == true && mounted) {
                  refresh();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Staff'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Search staff',
                  hintText: 'Name, employee ID, designation...',
                ),
                onSubmitted: (_) => applySearch(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: applySearch,
              child: const Text('Search'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<StaffPage>(
            future: result,
            builder: (context, snapshot) {
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
                        'Could not load staff:\n'
                        '${snapshot.error}',
                      ),
                      TextButton(
                        onPressed: refresh,
                        child: const Text(
                          'Retry',
                        ),
                      ),
                    ],
                  ),
                );
              }

              final data = snapshot.data!;

              if (data.results.isEmpty) {
                return const Center(
                  child: Text(
                    'No staff found.',
                  ),
                );
              }

              return ListView.builder(
                itemCount: data.results.length,
                itemBuilder: (context, index) {
                  final staff = data.results[index];

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          staff.fullName.isNotEmpty
                              ? staff.fullName[0].toUpperCase()
                              : 'S',
                        ),
                      ),
                      title: Text(
                        staff.fullName,
                      ),
                      subtitle: Text(
                        '${staff.employeeId}'
                        ' • '
                        '${staff.designation.isEmpty ? 'Staff' : staff.designation}'
                        '${staff.department.isEmpty ? '' : ' • ${staff.department}'}',
                      ),
                      trailing: Chip(
                        label: Text(
                          staff.isActive ? 'Active' : 'Inactive',
                        ),
                      ),
                      onTap: () async {
                        await context.push(
                          '/staff/${staff.uuid}',
                        );

                        if (mounted) {
                          refresh();
                        }
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<bool?> _showCreateDialog() {
    final employeeId = TextEditingController();
    final firstName = TextEditingController();
    final lastName = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final designation = TextEditingController();
    final department = TextEditingController();
    final address = TextEditingController();

    DateTime? joinedDate;
    String? error;
    bool saving = false;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (employeeId.text.trim().isEmpty ||
                  firstName.text.trim().isEmpty) {
                setDialogState(() {
                  error = 'Employee ID and first name are required.';
                });
                return;
              }

              setDialogState(() {
                saving = true;
                error = null;
              });

              try {
                await ref.read(staffRepositoryProvider).create(
                      employeeId: employeeId.text,
                      firstName: firstName.text,
                      lastName: lastName.text,
                      email: email.text,
                      phone: phone.text,
                      designation: designation.text,
                      department: department.text,
                      address: address.text,
                      joinedDate: joinedDate,
                    );

                if (dialogContext.mounted) {
                  Navigator.of(
                    dialogContext,
                  ).pop(true);
                }
              } catch (e) {
                setDialogState(() {
                  saving = false;
                  error = e.toString();
                });
              }
            }

            return AlertDialog(
              title: const Text('Add Staff'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: employeeId,
                        decoration: const InputDecoration(
                          labelText: 'Employee ID *',
                        ),
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      TextField(
                        controller: firstName,
                        decoration: const InputDecoration(
                          labelText: 'First Name *',
                        ),
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      TextField(
                        controller: lastName,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                        ),
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      TextField(
                        controller: email,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                        ),
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      TextField(
                        controller: phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                        ),
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      TextField(
                        controller: designation,
                        decoration: const InputDecoration(
                          labelText: 'Designation',
                        ),
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      TextField(
                        controller: department,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                        ),
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      TextField(
                        controller: address,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                        ),
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          joinedDate == null
                              ? 'Joined Date'
                              : '${joinedDate!.day}/${joinedDate!.month}/${joinedDate!.year}',
                        ),
                        trailing: const Icon(
                          Icons.calendar_today_outlined,
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime(
                              2000,
                            ),
                            lastDate: DateTime(
                              2100,
                            ),
                            initialDate: joinedDate ?? DateTime.now(),
                          );

                          if (picked != null) {
                            setDialogState(
                              () {
                                joinedDate = picked;
                              },
                            );
                          }
                        },
                      ),
                      if (error != null) ...[
                        const SizedBox(
                          height: 12,
                        ),
                        Text(
                          error!,
                          style: const TextStyle(
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(
                            dialogContext,
                          ),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving ? null : save,
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save',
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
