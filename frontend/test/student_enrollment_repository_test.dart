import 'package:dio/dio.dart';
import 'package:edusphere_admin_flutter/features/student_portal/data/student_enrollment_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('enrollment sends no client-controlled identity, fee or access status', () async {
    final dio = Dio();
    late RequestOptions captured;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      captured = options;
      handler.resolve(Response(requestOptions: options, data: {
        'success': true,
        'data': {'course_uuid': 'course', 'course_name': 'Course',
          'status': 'PENDING', 'has_access': false},
      }));
    }));
    final result = await StudentEnrollmentRepository(dio).request('course');
    expect(captured.method, 'POST');
    expect(captured.path, '/student/courses/course/enrollment/');
    expect(captured.data, isEmpty);
    expect(result.isPending, isTrue);
    expect(result.hasAccess, isFalse);
  });

  test('pending enrollment pagination preserves next-page state', () async {
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      expect(options.queryParameters, {'page': 2, 'page_size': 20});
      handler.resolve(Response(requestOptions: options, data: {
        'data': {
          'results': [{'course_uuid': 'course', 'course_name': 'Course',
            'status': 'PENDING', 'has_access': false}],
          'next': '/student/enrollments/?page=3',
        },
      }));
    }));
    final page = await StudentEnrollmentRepository(dio).pending(page: 2);
    expect(page.items.single.courseName, 'Course');
    expect(page.hasNext, isTrue);
  });
}
