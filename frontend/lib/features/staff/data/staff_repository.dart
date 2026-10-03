import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_urls.dart';
import '../../../core/network/dio_provider.dart';

import 'staff.dart';

class StaffRepository {
  StaffRepository(this._dio);

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

  Future<StaffPage> list({
    String search = '',
    bool? isActive,
    int page = 1,
  }) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.staff,
          queryParameters: {
            'page': page,
            'page_size': 20,
            if (search.trim().isNotEmpty) 'search': search.trim(),
            if (isActive != null) 'is_active': isActive,
          },
        );

        return StaffPage.fromJson(
          response.data ?? {},
        );
      });

  Future<Staff> detail(
    String uuid,
  ) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.staffDetail(uuid),
        );

        final data = response.data?['data'] ?? response.data ?? {};

        return Staff.fromJson(
          Map<String, dynamic>.from(
            data as Map,
          ),
        );
      });

  Future<Staff> create({
    required String employeeId,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String designation,
    required String department,
    String address = '',
    DateTime? joinedDate,
  }) =>
      _request(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          ApiUrls.staff,
          data: {
            'employee_id': employeeId.trim(),
            'first_name': firstName.trim(),
            'last_name': lastName.trim(),
            'email': email.trim(),
            'phone': phone.trim(),
            'designation': designation.trim(),
            'department': department.trim(),
            'address': address.trim(),
            if (joinedDate != null) 'joined_date': _dateOnly(joinedDate),
          },
        );

        final data = response.data?['data'] ?? response.data ?? {};

        return Staff.fromJson(
          Map<String, dynamic>.from(
            data as Map,
          ),
        );
      });

  Future<Staff> update({
    required String uuid,
    String? employeeId,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? designation,
    String? department,
    String? address,
    DateTime? joinedDate,
  }) =>
      _request(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          ApiUrls.staffDetail(uuid),
          data: {
            if (employeeId != null) 'employee_id': employeeId.trim(),
            if (firstName != null) 'first_name': firstName.trim(),
            if (lastName != null) 'last_name': lastName.trim(),
            if (email != null) 'email': email.trim(),
            if (phone != null) 'phone': phone.trim(),
            if (designation != null) 'designation': designation.trim(),
            if (department != null) 'department': department.trim(),
            if (address != null) 'address': address.trim(),
            if (joinedDate != null) 'joined_date': _dateOnly(joinedDate),
          },
        );

        final data = response.data?['data'] ?? response.data ?? {};

        return Staff.fromJson(
          Map<String, dynamic>.from(
            data as Map,
          ),
        );
      });

  Future<Staff> setActive({
    required String uuid,
    required bool active,
  }) =>
      _request(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          active ? ApiUrls.staffActivate(uuid) : ApiUrls.staffDeactivate(uuid),
        );

        final data = response.data?['data'] ?? response.data ?? {};

        return Staff.fromJson(
          Map<String, dynamic>.from(
            data as Map,
          ),
        );
      });

  static String _dateOnly(
    DateTime date,
  ) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  return StaffRepository(
    ref.watch(dioProvider),
  );
});
