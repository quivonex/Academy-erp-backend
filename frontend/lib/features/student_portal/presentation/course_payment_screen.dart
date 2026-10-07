import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/session/user_role.dart';
import '../../../core/widgets/back_button.dart';

class CoursePaymentScreen extends ConsumerWidget {
  const CoursePaymentScreen({
    super.key,
    required this.courseUuid,
    required this.courseName,
    required this.amount,
  });

  final String courseUuid;
  final String courseName;
  final String amount;

  String get _displayAmount {
    final value = num.tryParse(amount);

    if (value == null || !value.isFinite || value < 0) {
      return 'Confirm with academy';
    }

    return '₹${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (session.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!session.isAuthenticated ||
        session.role != UserRole.student) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Sign in with your student account '
            'to view course fee information.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            AppBackButton(
              fallbackRoute: '/explore/$courseUuid',
              color: Colors.black87,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Course fees & enrollment',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colors.primaryContainer,
                  child: Icon(
                    Icons.school_outlined,
                    size: 28,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  courseName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Listed course fee: $_displayAmount',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your final payable amount and any discount '
                  'are confirmed by the academy.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: colors.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: colors.onPrimaryContainer,
                ),
                const SizedBox(height: 12),
                Text(
                  'Payments are managed by your academy',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Contact ${session.firmName ?? 'your academy'} '
                  'for enrollment and payment instructions. '
                  'The academy records verified payments '
                  'against your enrollment.',
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to continue',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                const _FlowStep(
                  number: '1',
                  title: 'Contact the academy',
                  description:
                      'Confirm enrollment, fees and '
                      'the accepted payment method.',
                ),
                const SizedBox(height: 16),
                const _FlowStep(
                  number: '2',
                  title: 'Academy records your payment',
                  description:
                      'Share payment details directly with '
                      'the academy for verification.',
                ),
                const SizedBox(height: 16),
                const _FlowStep(
                  number: '3',
                  title: 'Check My Fees and My Courses',
                  description:
                      'View your fee account and recorded '
                      'installments in My Fees. Course access '
                      'is managed separately by the academy.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => context.go('/student/fees'),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Open My Fees'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.go('/student/courses'),
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('Open My Courses'),
        ),
        const SizedBox(height: 16),
        Text(
          'If this course is missing from My Fees, '
          'ask the academy to create its enrollment fee account.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _FlowStep extends StatelessWidget {
  const _FlowStep({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: colors.primaryContainer,
          child: Text(
            number,
            style: TextStyle(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(description),
            ],
          ),
        ),
      ],
    );
  }
}
