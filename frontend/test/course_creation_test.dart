import 'package:dio/dio.dart';
import 'package:edusphere_admin_flutter/features/courses/data/course.dart';
import 'package:edusphere_admin_flutter/features/courses/data/course_repository.dart';
import 'package:edusphere_admin_flutter/features/courses/presentation/courses_list_screen.dart';
import 'package:edusphere_admin_flutter/features/course_categories/data/course_category.dart';
import 'package:edusphere_admin_flutter/features/course_categories/data/course_category_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Categories extends CourseCategoryRepository {
  _Categories() : super(Dio());
  @override
  Future<AdminCourseCategoryPage> list({String search = '', int page = 1}) async =>
      const AdminCourseCategoryPage(count: 0, results: []);
}

void main() {
  testWidgets('basic course form creates a single draft without curriculum requests',
      (tester) async {
    final dio = Dio();
    final requests = <RequestOptions>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      handler.resolve(Response(requestOptions: options, data: {
        'data': {'uuid': 'draft', ...Map<String, dynamic>.from(options.data as Map)},
      }));
    }));
    Course? created;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        courseRepositoryProvider.overrideWithValue(CourseRepository(dio)),
        courseCategoryRepositoryProvider.overrideWithValue(_Categories()),
      ],
      child: MaterialApp(home: Builder(builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async {
            created = await showDialog<Course>(context: context,
              builder: (_) => const CreateCourseDialog());
          },
          child: const Text('Open form'),
        ),
      ))),
    ));
    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    expect(find.text('Advanced settings'), findsOneWidget);
    expect(find.text('Add Subject'), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(3));
    await tester.enterText(find.byType(TextFormField).first, 'New course');
    await tester.ensureVisible(find.text('Create draft'));
    await tester.tap(find.text('Create draft'));
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    final payload = requests.single.data as Map;
    expect(payload['is_published'], false);
    expect(payload['is_purchasable_online'], false);
    expect(payload['code'], startsWith('CRS-'));
    expect(created?.uuid, 'draft');
    expect(tester.takeException(), isNull);
  });

  test('publish updates both catalogue visibility flags in one request', () async {
    final dio = Dio();
    final payloads = <Map>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      payloads.add(Map.from(options.data as Map));
      handler.resolve(Response(requestOptions: options, data: {
        'data': {'uuid': 'course', ...Map<String, dynamic>.from(options.data as Map)},
      }));
    }));
    final repository = CourseRepository(dio);
    await repository.setPublished('course', true);
    await repository.setPublished('course', false);
    expect(payloads, [
      {'is_published': true, 'is_purchasable_online': true},
      {'is_published': false, 'is_purchasable_online': false},
    ]);
  });
}
