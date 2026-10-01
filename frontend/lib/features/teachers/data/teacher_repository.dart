import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_urls.dart';
import '../../../core/network/dio_provider.dart';

import 'teacher.dart';

class TeacherRepository {
  TeacherRepository(this._dio);

  final Dio _dio;

  Future<T> _request<T>(
    Future<T> Function() operation,
  ) async {
    try {
      return await operation();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<TeacherPage> list({
    String search = '',
    bool? isActive,
    int page = 1,
  }) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.teachers,
          queryParameters: {
            'page': page,
            'page_size': 20,
            if (search.trim().isNotEmpty) 'search': search.trim(),
            if (isActive != null) 'is_active': isActive,
          },
        );

        return TeacherPage.fromJson(
          response.data ?? {},
        );
      });

  Future<Teacher> detail(
    String uuid,
  ) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.teacherDetail(uuid),
        );

        final resData = response.data?['data'] ?? response.data ?? {};
        return Teacher.fromJson(
          Map<String, dynamic>.from(resData as Map),
        );
      });

  Future<Teacher> create({
    required String employeeId,
    required String firstName,
    String lastName = '',
    String email = '',
    String phone = '',
    String gender = '',
    String qualification = '',
    String specialization = '',
    int experienceYears = 0,
    String address = '',
    String? joinedDate,
  }) =>
      _request(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          ApiUrls.teachers,
          data: {
            'employee_id': employeeId.trim(),
            'first_name': firstName.trim(),
            'last_name': lastName.trim(),
            'email': email.trim(),
            'phone': phone.trim(),
            'gender': gender,
            'qualification': qualification.trim(),
            'specialization': specialization.trim(),
            'experience_years': experienceYears,
            'address': address.trim(),
            if (joinedDate != null) 'joined_date': joinedDate,
          },
        );

        final resData = response.data?['data'] ?? response.data ?? {};
        return Teacher.fromJson(
          Map<String, dynamic>.from(resData as Map),
        );
      });

  Future<Teacher> update(
    String uuid, {
    required String employeeId,
    required String firstName,
    String lastName = '',
    String email = '',
    String phone = '',
    String qualification = '',
    String specialization = '',
    int experienceYears = 0,
    String address = '',
  }) =>
      _request(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          ApiUrls.teacherDetail(uuid),
          data: {
            'employee_id': employeeId.trim(),
            'first_name': firstName.trim(),
            'last_name': lastName.trim(),
            'email': email.trim(),
            'phone': phone.trim(),
            'qualification': qualification.trim(),
            'specialization': specialization.trim(),
            'experience_years': experienceYears,
            'address': address.trim(),
          },
        );

        final resData = response.data?['data'] ?? response.data ?? {};
        return Teacher.fromJson(
          Map<String, dynamic>.from(resData as Map),
        );
      });

  Future<Teacher> setActive(
    String uuid,
    bool active,
  ) =>
      _request(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          active
              ? ApiUrls.teacherActivate(uuid)
              : ApiUrls.teacherDeactivate(uuid),
        );

        final resData = response.data?['data'] ?? response.data ?? {};
        return Teacher.fromJson(
          Map<String, dynamic>.from(resData as Map),
        );
      });
}

final teacherRepositoryProvider = Provider<TeacherRepository>((ref) {
  return TeacherRepository(
    ref.watch(dioProvider),
  );
});
