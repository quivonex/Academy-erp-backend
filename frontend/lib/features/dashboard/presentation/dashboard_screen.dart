import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/session/user_role.dart';
import '../../firms/data/firm_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    if (session.role == UserRole.superAdmin) {
      final firms = ref.watch(firmsListProvider);
      return SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Academy overview', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          firms.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Could not load firms: $e'),
              TextButton(onPressed: () => ref.invalidate(firmsListProvider), child: const Text('Retry')),
            ]),
            data: (items) => Wrap(spacing: 12, runSpacing: 12, children: [
              Card(child: Padding(padding: const EdgeInsets.all(20), child: Text('Academies: ${items.length}'))),
              Card(child: Padding(padding: const EdgeInsets.all(20), child: Text('Active: ${items.where((f) => f.isActive).length}'))),
              FilledButton(onPressed: () => context.go('/firms'), child: const Text('View firms')),
            ]),
          ),
        ],
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Welcome to Academy ERP', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      Text(session.firmName ?? 'Your academy'),
      const SizedBox(height: 8),
      Text('Signed in as ${session.role?.apiValue ?? ''}'),
    ]);
  }
}
