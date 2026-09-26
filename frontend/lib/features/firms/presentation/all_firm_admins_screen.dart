import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_pill.dart';
import '../data/firm_admin_repository.dart';

class AllFirmAdminsScreen extends ConsumerWidget {
  const AllFirmAdminsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminsAsync = ref.watch(allFirmAdminsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'All Firm Admins',
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => ref.invalidate(allFirmAdminsProvider),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: adminsAsync.when(
            data: (admins) => admins.isEmpty
                ? Center(
              child: Text(
                'No firm admins yet.',
                style: TextStyle(color: context.colors.textMuted),
              ),
            )
                : Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('NAME')),
                    DataColumn(label: Text('EMAIL')),
                    DataColumn(label: Text('FIRM')),
                    DataColumn(label: Text('JOINED')),
                    DataColumn(label: Text('STATUS')),
                  ],
                  rows: [
                    for (final a in admins)
                      DataRow(
                        onSelectChanged: (_) =>
                            context.go('/firms/${a.firmUuid}'),
                        cells: [
                          DataCell(Text(a.fullName)),
                          DataCell(Text(a.email)),
                          DataCell(Text(a.firmName)),
                          DataCell(Text(formatDate(a.dateJoined))),
                          DataCell(StatusPill(
                            label: a.isActive ? 'ACTIVE' : 'INACTIVE',
                            tone: a.isActive
                                ? PillTone.success
                                : PillTone.neutral,
                            compact: true,
                          )),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            loading: () =>
            const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Could not load firm admins: $e')),
          ),
        ),
      ],
    );
  }
}