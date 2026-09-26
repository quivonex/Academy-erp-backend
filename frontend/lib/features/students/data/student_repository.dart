import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_urls.dart';
import '../../../core/network/dio_provider.dart';
import 'student.dart';

class StudentRepository {
  StudentRepository(this._dio);
  final Dio _dio;

  Future<T> _request<T>(Future<T> Function() operation) async {
    try { return await operation(); }
    on DioException catch (e) { throw ApiException.fromDioException(e); }
  }

  Future<StudentPage> list({String search = '', int page = 1}) => _request(() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiUrls.students, queryParameters: {
      'page': page, 'page_size': 20,
      if (search.trim().isNotEmpty) 'search': search.trim(),
    });
    return StudentPage.fromJson(response.data ?? {});
  });

  Future<Student> detail(String uuid) => _request(() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiUrls.studentDetail(uuid));
    return Student.fromJson(Map<String, dynamic>.from(response.data!['data'] as Map));
  });

  Future<Student> create({required String admissionNumber, required String firstName,
    String lastName = '', String email = '', String phone = ''}) => _request(() async {
    final response = await _dio.post<Map<String, dynamic>>(ApiUrls.students, data: {
      'admission_number': admissionNumber.trim(), 'first_name': firstName.trim(),
      'last_name': lastName.trim(), 'email': email.trim(), 'phone': phone.trim(),
    });
    return Student.fromJson(Map<String, dynamic>.from(response.data!['data'] as Map));
  });

  Future<Student> setActive(String uuid, bool active) => _request(() async {
    final response = await _dio.patch<Map<String, dynamic>>(
      ApiUrls.studentStatus(uuid, active));
    return Student.fromJson(Map<String, dynamic>.from(response.data!['data'] as Map));
  });

  Future<void> enableLogin(String uuid, {required String email,
    required String password, required String confirmPassword}) => _request(() async {
    await _dio.post(ApiUrls.studentEnableLogin(uuid), data: {
      'email': email.trim(), 'password': password,
      'confirm_password': confirmPassword,
    });
  });
}

final studentRepositoryProvider = Provider<StudentRepository>((ref) =>
  StudentRepository(ref.watch(dioProvider)));
