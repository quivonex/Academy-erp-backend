import 'dart:async';

import 'package:dio/dio.dart';
import 'package:edusphere_admin_flutter/core/network/api_exception.dart';
import 'package:edusphere_admin_flutter/features/student_portal/data/student_enrollment_repository.dart';
import 'package:edusphere_admin_flutter/features/student_portal/data/student_portal_repository.dart';
import 'package:edusphere_admin_flutter/features/student_portal/presentation/student_enrollment_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const notEnrolled = StudentEnrollment(
  courseUuid: 'course', courseName: 'Course',
  status: 'NOT_ENROLLED', hasAccess: false,
);
const pendingEnrollment = StudentEnrollment(
  courseUuid: 'course', courseName: 'Course',
  status: 'PENDING', hasAccess: false,
);

class _Portal extends StudentPortalRepository {
  _Portal() : super(Dio());
  @override
  Future<MyCourse> myCourse(String uuid) async =>
      throw const ApiException('No access', statusCode: 404);
}

class _Enrollments extends StudentEnrollmentRepository {
  _Enrollments() : super(Dio());
  int submissions = 0;
  bool fail = false;
  final completion = Completer<StudentEnrollment>();

  @override
  Future<StudentEnrollment> status(String uuid) async => notEnrolled;

  @override
  Future<StudentEnrollment> request(String uuid) {
    submissions++;
    if (fail) return Future.error(const ApiException('Offline'));
    return completion.future;
  }

  @override
  Future<StudentEnrollmentPage> pending({int page = 1}) async =>
      const StudentEnrollmentPage([pendingEnrollment], false);
}

void main() {
  Future<void> mount(WidgetTester tester, _Enrollments repository,
      {Widget child = const StudentEnrollmentAction(courseUuid: 'course')}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        studentPortalRepositoryProvider.overrideWithValue(_Portal()),
        studentEnrollmentRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('enrollment submits once and shows pending without unlocking content',
      (tester) async {
    final repository = _Enrollments();
    await mount(tester, repository);
    await tester.tap(find.text('Enroll'));
    await tester.pump();
    expect(find.text('Submitting…'), findsOneWidget);
    expect(repository.submissions, 1);
    repository.completion.complete(pendingEnrollment);
    await tester.pumpAndSettle();
    expect(find.text('Enroll'), findsNothing);
    expect(find.text('Continue learning'), findsNothing);
    expect(find.text('Refresh enrollment status'), findsOneWidget);
    expect(find.textContaining('Enrollment requested.'), findsOneWidget);
  });

  testWidgets('failed enrollment remains retryable', (tester) async {
    final repository = _Enrollments()..fail = true;
    await mount(tester, repository);
    await tester.tap(find.text('Enroll'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not submit enrollment:'), findsOneWidget);
    expect(find.text('Enroll'), findsOneWidget);
    repository.fail = false;
    repository.completion.complete(pendingEnrollment);
    await tester.tap(find.text('Enroll'));
    await tester.pumpAndSettle();
    expect(repository.submissions, 2);
    expect(find.text('Refresh enrollment status'), findsOneWidget);
  });

  testWidgets('pending enrollments appear separately from accessible courses',
      (tester) async {
    await mount(tester, _Enrollments(), child: const PendingEnrollments());
    expect(find.text('Course'), findsOneWidget);
    expect(find.text('Pending academy approval'), findsOneWidget);
    expect(find.text('Continue learning'), findsNothing);
  });
}
