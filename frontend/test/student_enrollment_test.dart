import 'package:dio/dio.dart';
import 'package:edusphere_admin_flutter/core/network/api_exception.dart';
import 'package:edusphere_admin_flutter/features/student_portal/data/student_portal_repository.dart';
import 'package:edusphere_admin_flutter/features/student_portal/presentation/student_enrollment_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Portal extends StudentPortalRepository {
  _Portal() : super(Dio());
  bool granted = false;
  bool offline = false;

  @override
  Future<MyCourse> myCourse(String uuid) async {
    if (offline) throw const ApiException('Offline');
    if (!granted) throw const ApiException('No access', statusCode: 404);
    return const MyCourse(uuid: 'enrollment', courseUuid: 'course',
      name: 'Course', code: 'C', description: '');
  }
}

void main() {
  Future<void> mount(WidgetTester tester, _Portal portal) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [studentPortalRepositoryProvider.overrideWithValue(portal)],
      child: const MaterialApp(home: Scaffold(
        body: StudentEnrollmentAction(courseUuid: 'course'),
      )),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('students see payment guidance without any enrollment action',
      (tester) async {
    await mount(tester, _Portal());
    expect(find.text('Enroll'), findsNothing);
    expect(find.text('Continue learning'), findsNothing);
    expect(find.text('Fees & enrollment'), findsOneWidget);
    expect(find.textContaining('Firm Admin verifies payment'), findsOneWidget);
  });

  testWidgets('refresh unlocks learning only after admin grants access',
      (tester) async {
    final portal = _Portal();
    await mount(tester, portal);
    portal.granted = true;
    await tester.tap(find.text('Refresh course access'));
    await tester.pumpAndSettle();
    expect(find.text('Continue learning'), findsOneWidget);
    expect(find.text('Fees & enrollment'), findsNothing);
  });

  testWidgets('access check failures remain retryable', (tester) async {
    final portal = _Portal()..offline = true;
    await mount(tester, portal);
    expect(find.text('Try again'), findsOneWidget);
    portal.offline = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Fees & enrollment'), findsOneWidget);
  });
}
