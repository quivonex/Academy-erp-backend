import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_urls.dart';
import '../../../core/network/dio_provider.dart';

List<dynamic> _items(dynamic response) {
  final data = response is Map ? response['data'] : null;

  if (data is List) return data;

  if (data is Map && data['results'] is List) {
    return data['results'] as List;
  }

  throw const ApiException('Unexpected list response from server.');
}

class PublicCourse {
  const PublicCourse({
    required this.uuid,
    required this.name,
    required this.code,
    required this.description,
    required this.price,
    required this.deliveryMode,
    required this.isFeatured,
    this.categoryName,
    this.firmName,
    this.durationMonths,
  });

  final String uuid;
  final String name;
  final String code;
  final String description;
  final String price;
  final String deliveryMode;
  final String? categoryName;
  final String? firmName;
  final int? durationMonths;
  final bool isFeatured;

  factory PublicCourse.fromJson(Map<String, dynamic> json) => PublicCourse(
    uuid: json['uuid'].toString(),
    name: json['name']?.toString() ?? '',
    code: json['code']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    price: json['price']?.toString() ?? '0',
    deliveryMode: json['delivery_mode']?.toString() ?? '',
    isFeatured: json['is_featured'] == true,
    categoryName: json['category_name']?.toString(),
    firmName: json['firm_name']?.toString(),
    durationMonths: json['duration_months'] is int
        ? json['duration_months'] as int
        : null,
  );
}

class CourseCategory {
  const CourseCategory({
    required this.uuid,
    required this.name,
  });

  final String uuid;
  final String name;

  factory CourseCategory.fromJson(Map<String, dynamic> json) =>
      CourseCategory(
        uuid: json['uuid'].toString(),
        name: json['name']?.toString() ?? '',
      );
}

class MyCourse {
  const MyCourse({
    required this.uuid,
    required this.courseUuid,
    required this.name,
    required this.code,
    required this.description,
    this.categoryName,
    this.accessEndAt,
  });

  final String uuid;
  final String courseUuid;
  final String name;
  final String code;
  final String description;
  final String? categoryName;
  final String? accessEndAt;

  factory MyCourse.fromJson(Map<String, dynamic> json) => MyCourse(
    uuid: json['uuid'].toString(),
    courseUuid: json['course_uuid'].toString(),
    name: json['course_name']?.toString() ?? '',
    code: json['course_code']?.toString() ?? '',
    description: json['course_description']?.toString() ?? '',
    categoryName: json['category_name']?.toString(),
    accessEndAt: json['access_end_at']?.toString(),
  );
}

class StudentPortalRepository {
  StudentPortalRepository(this._dio);

  final Dio _dio;

  Future<T> _request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<CourseCategory>> categories() => _request(() async {
    final response = await _dio.get(ApiUrls.publicCategories);

    return _items(response.data)
        .map(
          (item) => CourseCategory.fromJson(
        Map<String, dynamic>.from(item as Map),
      ),
    )
        .toList();
  });

  Future<List<PublicCourse>> publicCourses({
    String? search,
    String? categoryUuid,
    int page = 1,
  }) =>
      _request(() async {
        final response = await _dio.get(
          ApiUrls.publicCourses,
          queryParameters: {
            if (search != null && search.trim().isNotEmpty)
              'search': search.trim(),
            if (categoryUuid != null) 'category_uuid': categoryUuid,
            'page': page,
            'page_size': 20,
          },
        );

        return _items(response.data)
            .map(
              (item) => PublicCourse.fromJson(
            Map<String, dynamic>.from(
              item as Map,
            ),
          ),
        )
            .toList();
      });

  Future<PublicCourse> publicCourse(String uuid) => _request(() async {
    final response = await _dio.get(ApiUrls.publicCourse(uuid));

    return PublicCourse.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  });

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) =>
      _request(() async {
        await _dio.post(
          ApiUrls.studentRegister,
          data: {
            'first_name': firstName,
            'last_name': lastName,
            'email': email,
            'phone': phone,
            'password': password,
            'confirm_password': password,
          },
        );
      });

  Future<List<MyCourse>> myCourses({
    int page = 1,
  }) =>
      _request(() async {
        final response = await _dio.get(
          ApiUrls.myCourses,
          queryParameters: {
            'page': page,
            'page_size': 20,
          },
        );

        return _items(response.data)
            .map(
              (item) => MyCourse.fromJson(
            Map<String, dynamic>.from(
              item as Map,
            ),
          ),
        )
            .toList();
      });

  Future<MyCourse> myCourse(String uuid) => _request(() async {
    final response = await _dio.get(ApiUrls.myCourse(uuid));

    return MyCourse.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  });

  Future<List<Map<String, dynamic>>> materials(String uuid) =>
      _request(() async {
        final response = await _dio.get(ApiUrls.myCourseMaterials(uuid));

        return _items(response.data)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      });

  Future<List<Map<String, dynamic>>> classes(String uuid) =>
      _request(() async {
        final response = await _dio.get(ApiUrls.myCourseClasses(uuid));

        return _items(response.data)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      });
  Future<List<Map<String, dynamic>>> banners({
    String? firmUuid,
  }) =>
      _request(() async {
        final response = await _dio.get(
          ApiUrls.publicBanners,
          queryParameters: {
            if (firmUuid != null) 'firm_uuid': firmUuid,
          },
        );

        return _items(response.data)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      });

  Future<Map<String, dynamic>> material(String uuid) =>
      _request(() async {
        final response = await _dio.get(
          ApiUrls.studentMaterial(uuid),
        );

        return Map<String, dynamic>.from(
          response.data['data'] as Map,
        );
      });

  Future<Map<String, dynamic>> materialProgress(
      String materialUuid,
      ) =>
      _request(() async {
        final response = await _dio.get(
          ApiUrls.materialProgress(materialUuid),
        );

        return Map<String, dynamic>.from(
          response.data['data'] as Map,
        );
      });

  Future<Map<String, dynamic>> saveMaterialProgress({
    required String materialUuid,
    int? watchedSeconds,
    int? lastPositionSeconds,
    bool markCompleted = false,
  }) =>
      _request(() async {
        final response = await _dio.post(
          ApiUrls.materialProgress(materialUuid),
          data: {
            if (watchedSeconds != null)
              'watched_seconds': watchedSeconds,
            if (lastPositionSeconds != null)
              'last_position_seconds': lastPositionSeconds,
            'mark_completed': markCompleted,
          },
        );

        return Map<String, dynamic>.from(
          response.data['data'] as Map,
        );
      });

  Future<Map<String, dynamic>> courseProgress(
      String courseUuid,
      ) =>
      _request(() async {
        final response = await _dio.get(
          ApiUrls.courseProgress(courseUuid),
        );

        return Map<String, dynamic>.from(
          response.data['data'] as Map,
        );
      });

  Future<Map<String, dynamic>> liveClass(
      String liveClassUuid,
      ) =>
      _request(() async {
        final response = await _dio.get(
          ApiUrls.studentLiveClass(liveClassUuid),
        );

        return Map<String, dynamic>.from(
          response.data['data'] as Map,
        );
      });

  Future<List<Map<String, dynamic>>> allLiveClasses({
    String? status,
  }) =>
      _request(() async {
        final response = await _dio.get(
          ApiUrls.studentLiveClasses,
          queryParameters: {
            if (status != null) 'status': status,
            'page_size': 100,
          },
        );

        return _items(response.data)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      });

  Future<List<Map<String, dynamic>>> assignments(
      String courseUuid,
      ) =>
      _request(() async {
        final response = await _dio.get(
          ApiUrls.courseAssignments(courseUuid),
        );

        return _items(response.data)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      });

  Future<Map<String, dynamic>> assignment(
      String assignmentUuid,
      ) =>
      _request(() async {
        final response = await _dio.get(
          ApiUrls.assignmentDetail(assignmentUuid),
        );

        return Map<String, dynamic>.from(
          response.data['data'] as Map,
        );
      });

  Future<void> submitAssignment({
    required String assignmentUuid,
    required List<Map<String, dynamic>> answers,
  }) =>
      _request(() async {
        await _dio.post(
          ApiUrls.assignmentSubmit(assignmentUuid),
          data: {'answers': answers},
        );
      });

  Future<Map<String, dynamic>> assignmentResult(
      String assignmentUuid,
      ) =>
      _request(() async {
        final response = await _dio.get(
          ApiUrls.assignmentResult(assignmentUuid),
        );

        return Map<String, dynamic>.from(
          response.data['data'] as Map,
        );
      });
}

final studentPortalRepositoryProvider =
Provider<StudentPortalRepository>((ref) {
  return StudentPortalRepository(ref.watch(dioProvider));
});