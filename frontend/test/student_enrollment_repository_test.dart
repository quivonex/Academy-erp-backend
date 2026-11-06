import 'package:dio/dio.dart';
import 'package:edusphere_admin_flutter/features/student_portal/data/student_enrollment_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('student enrollment is rejected locally without an HTTP request', () async {
    final dio = Dio();
    var requests = 0;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests++;
      handler.reject(DioException(requestOptions: options));
    }));
    await expectLater(StudentEnrollmentRepository(dio).request('course'), throwsA(
      isA<Exception>().having((e) => e.toString(), 'message', contains('Firm Admin')),
    ));
    expect(requests, 0);
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
