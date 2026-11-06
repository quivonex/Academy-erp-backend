import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../data/student_portal_repository.dart';

/// Course access is granted only by the Firm Admin after payment verification.
class StudentEnrollmentAction extends ConsumerStatefulWidget {
  const StudentEnrollmentAction({
    super.key,
    required this.courseUuid,
    this.courseName = 'Course',
    this.amount = '0.00',
  });

  final String courseUuid;
  final String courseName;
  final String amount;

  @override
  ConsumerState<StudentEnrollmentAction> createState() =>
      _StudentEnrollmentActionState();
}

class _StudentEnrollmentActionState extends ConsumerState<StudentEnrollmentAction> {
  late Future<bool> _access;

  @override
  void initState() {
    super.initState();
    _access = _load();
  }

  Future<bool> _load() async {
    try {
      // Includes existing chapter-only grants.
      await ref.read(studentPortalRepositoryProvider).myCourse(widget.courseUuid);
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 404) return false;
      rethrow;
    }
  }

  void _refresh() {
    final access = _load();
    setState(() {
      _access = access;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _access,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Column(children: [
          Text('Could not check course access: ${snapshot.error}'),
          TextButton(onPressed: _refresh, child: const Text('Try again')),
        ]);
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final hasAccess = snapshot.data!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(hasAccess
              ? 'You have access to this course.'
              : 'Contact your academy for UPI payment details. The Firm Admin verifies payment and enrolls you. The course will then appear in My Courses.'),
          const SizedBox(height: 14),
          if (hasAccess)
            FilledButton.icon(
              onPressed: () => context.go('/student/courses/${widget.courseUuid}'),
              icon: const Icon(Icons.play_circle_fill_rounded),
              label: const Text('Continue learning'),
            )
          else ...[
            FilledButton.icon(
              onPressed: () => context.push(Uri(
                path: '/student/course-payment/${widget.courseUuid}',
                queryParameters: {'name': widget.courseName, 'amount': widget.amount},
              ).toString()),
              icon: const Icon(Icons.info_outline_rounded),
              label: const Text('Fees & enrollment'),
            ),
            TextButton(onPressed: _refresh, child: const Text('Refresh course access')),
          ],
          OutlinedButton(
            onPressed: () => context.go('/student/courses'),
            child: const Text('View My Courses'),
          ),
        ],
      );
    },
  );
}
