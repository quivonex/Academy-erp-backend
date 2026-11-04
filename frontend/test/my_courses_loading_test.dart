import 'package:dio/dio.dart';
import 'package:edusphere_admin_flutter/features/student_portal/data/student_portal_repository.dart';
import 'package:edusphere_admin_flutter/features/student_portal/presentation/my_courses_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _CoursesRepository extends StudentPortalRepository {
  _CoursesRepository() : super(Dio());

  final progressRequests = <String>[];

  @override
  Future<MyCoursePage> myCourses({int page = 1}) async => MyCoursePage(
    items: List.generate(
      20,
      (index) => MyCourse(
        uuid: 'enrollment-$index',
        courseUuid: 'course-$index',
        name: 'Course $index',
        code: 'C$index',
        description: '',
      ),
    ),
    hasNext: false,
  );

  @override
  Future<Map<String, dynamic>> courseProgress(String courseUuid) async {
    progressRequests.add(courseUuid);
    return {'completion_percentage': 25, 'total_materials': 4,
      'completed_materials': 1};
  }
}

void main() {
  testWidgets('progress loads near the viewport and is cached on rebuild',
      (tester) async {
    final repository = _CoursesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentPortalRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: Scaffold(body: MyCoursesScreen())),
      ),
    );
    await tester.pumpAndSettle();

    // An eager list would issue twenty progress requests immediately.
    expect(repository.progressRequests.length, lessThan(20));
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(repository.progressRequests, isNotEmpty);
    expect(repository.progressRequests, isNot(contains('course-19')));

    final requested = repository.progressRequests.toList();
    await tester.drag(find.byType(ListView).first, const Offset(0, 500));
    await tester.pumpAndSettle();
    for (final course in requested) {
      expect(repository.progressRequests.where((item) => item == course).length, 1);
    }
    expect(tester.takeException(), isNull);
  });
}
