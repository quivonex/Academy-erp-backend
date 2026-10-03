import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/staff.dart';
import '../data/staff_repository.dart';

class StaffDetailScreen extends ConsumerStatefulWidget {
  const StaffDetailScreen({
    super.key,
    required this.staffUuid,
  });

  final String staffUuid;

  @override
  ConsumerState<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends ConsumerState<StaffDetailScreen> {
  late Future<Staff> staffFuture;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    staffFuture = ref.read(staffRepositoryProvider).detail(widget.staffUuid);
  }

  void refresh() {
    setState(reload);
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return FutureBuilder<Staff>(
      future: staffFuture,
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
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final staff = snapshot.data!;

        return ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    staff.fullName,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _toggleActive(
                    staff,
                  ),
                  icon: Icon(
                    staff.isActive ? Icons.block : Icons.check_circle,
                  ),
                  label: Text(
                    staff.isActive ? 'Deactivate' : 'Activate',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _Info(
              label: 'Employee ID',
              value: staff.employeeId,
            ),
            _Info(
              label: 'Designation',
              value: staff.designation,
            ),
            _Info(
              label: 'Department',
              value: staff.department,
            ),
            _Info(
              label: 'Email',
              value: staff.email,
            ),
            _Info(
              label: 'Phone',
              value: staff.phone,
            ),
            _Info(
              label: 'Address',
              value: staff.address,
            ),
            _Info(
              label: 'Joined Date',
              value: staff.joinedDate ?? '-',
            ),
            _Info(
              label: 'Status',
              value: staff.isActive ? 'Active' : 'Inactive',
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleActive(
    Staff staff,
  ) async {
    try {
      await ref.read(staffRepositoryProvider).setActive(
            uuid: staff.uuid,
            active: !staff.isActive,
          );

      if (mounted) {
        refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString(),
            ),
          ),
        );
      }
    }
  }
}

class _Info extends StatelessWidget {
  const _Info({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
            ),
          ),
        ],
      ),
    );
  }
}
