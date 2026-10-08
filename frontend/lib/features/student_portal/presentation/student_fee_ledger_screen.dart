import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/user_role.dart';
import '../../../core/utils/formatters.dart';
import '../data/student_fee_repository.dart';

class StudentFeeLedgerScreen extends ConsumerWidget {
  const StudentFeeLedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);

    if (session.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (session.role != UserRole.student ||
        !session.isAuthenticated) {
      return const Center(
        child: Text('Sign in as a student to view fees.'),
      );
    }

    return _Ledger(
      key: ValueKey('${session.userUuid}_${session.firmUuid}'),
    );
  }
}

class _Ledger extends ConsumerStatefulWidget {
  const _Ledger({super.key});

  @override
  ConsumerState<_Ledger> createState() => _LedgerState();
}

class _LedgerState extends ConsumerState<_Ledger> {
  late Future<StudentFeePage> result;
  int page = 1;

  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    result = ref.read(studentFeeRepositoryProvider).list(page: page);
  }

  void changePage(int next) {
    if (next < 1) return;

    setState(() {
      page = next;
      load();
    });
  }

  String text(dynamic value) => value?.toString() ?? '';

  String money(dynamic value) => formatInr(num.parse(text(value)));

  String date(dynamic value) =>
      text(value).isEmpty ? 'Not set' : text(value);

  Widget line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );

  Widget accountCard(Map<String, dynamic> account) {
    final payments = account['installments'] as List;

    final net = num.parse(text(account['total_amount'])) -
        num.parse(text(account['discount_amount']));

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              text(account['course_name']),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(text(account['course_code'])),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(text(account['status'])),
              ),
            ),
            line('Total fee', money(account['total_amount'])),
            line('Discount', money(account['discount_amount'])),
            line('Net fee', formatInr(net)),
            line('Paid', money(account['paid_amount'])),
            line('Balance', money(account['balance_amount'])),
            line('Due date', date(account['due_date'])),
            const Divider(height: 28),
            Text(
              'Installment history',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (payments.isEmpty)
              const Text('No payments recorded yet.'),
            for (final raw in payments)
              paymentCard(
                Map<String, dynamic>.from(raw as Map),
              ),
          ],
        ),
      ),
    );
  }

  Widget paymentCard(Map<String, dynamic> payment) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).dividerColor,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            line('Amount', money(payment['amount'])),
            line('Payment date', date(payment['payment_date'])),
            line('Method', text(payment['payment_method'])),
            line('Status', text(payment['status'])),
            if (text(payment['transaction_reference']).isNotEmpty)
              line(
                'Reference',
                text(payment['transaction_reference']),
              ),
            if (payment['status'] == 'VOIDED')
              const Text(
                'This payment was voided and does not count toward paid fees.',
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'My Fees',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => changePage(1),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const Text(
            'Payments recorded by your academy appear here.',
          ),
          const SizedBox(height: 18),
          FutureBuilder<StudentFeePage>(
            future: result,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                final error = snapshot.error;

                return Column(
                  children: [
                    Text(
                      error is ApiException
                          ? error.message
                          : 'Could not load fees. Please try again.',
                    ),
                    TextButton(
                      onPressed: () => setState(load),
                      child: const Text('Retry'),
                    ),
                    if (page > 1)
                      TextButton(
                        onPressed: () => changePage(page - 1),
                        child: const Text('Previous page'),
                      ),
                  ],
                );
              }

              final data = snapshot.data!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${data.count} fee accounts'),
                  const SizedBox(height: 12),
                  if (data.accounts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No fee accounts on this page.'),
                    ),
                  for (final account in data.accounts)
                    accountCard(account),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: page > 1
                            ? () => changePage(page - 1)
                            : null,
                        child: const Text('Previous'),
                      ),
                      Text('Page $page'),
                      TextButton(
                        onPressed: data.hasNext
                            ? () => changePage(page + 1)
                            : null,
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      );
}
