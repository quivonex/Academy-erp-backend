import 'package:dio/dio.dart';
import 'package:edusphere_admin_flutter/features/student_portal/data/student_portal_repository.dart';
import 'package:edusphere_admin_flutter/features/student_portal/presentation/course_learning_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ResourcesRepository extends StudentPortalRepository {
  _ResourcesRepository() : super(Dio());
  final pages = <int>[];
  bool failNext = true;

  @override
  Future<MyCourse> myCourse(String uuid) async => const MyCourse(
    uuid: 'enrollment', courseUuid: 'course', name: 'Test course',
    code: 'TEST', description: '',
  );

  @override
  Future<Map<String, dynamic>> courseProgress(String uuid) async => {};

  @override
  Future<List<Map<String, dynamic>>> assignments(String uuid) async => [];

  @override
  Future<CourseResourcePage> classesPage(String uuid, {int page = 1}) async =>
      const CourseResourcePage(items: [], hasNext: false);

  @override
  Future<CourseResourcePage> materialsPage(String uuid, {int page = 1}) async {
    pages.add(page);
    if (page == 2 && failNext) {
      failNext = false;
      throw Exception('Offline');
    }
    return CourseResourcePage(
      items: [{'uuid': 'material-$page', 'title': 'Lesson $page'}],
      hasNext: page == 1,
    );
  }
}

void main() {
  testWidgets('loads one page, retains content on failure, and retries same page',
      (tester) async {
    final repository = _ResourcesRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        studentPortalRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        home: Scaffold(body: CourseLearningScreen(courseUuid: 'course')),
      ),
    ));
    await tester.pumpAndSettle();
    expect(repository.pages, [1]);
    expect(find.text('Lesson 1'), findsOneWidget);

    await tester.ensureVisible(find.text('Load more'));
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(repository.pages, [1, 2]);
    expect(find.text('Lesson 1'), findsOneWidget);
    expect(find.text('Could not load more materials. Try again.'), findsOneWidget);

    await tester.ensureVisible(find.text('Load more'));
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(repository.pages, [1, 2, 2]);
    expect(find.text('Lesson 1'), findsOneWidget);
    expect(find.text('Lesson 2'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
