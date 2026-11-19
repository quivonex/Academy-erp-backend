    final response = await _dio.get(ApiUrls.publicCategories);

    return _items(response.data)
        .map(
          (item) => CourseCategory.fromJson(
        Map<String, dynamic>.from(item as Map),
      ),
    )
        .toList();
  });

  Future<PublicCoursePage> publicCourses({
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

        final body = response.data;
        final data = body is Map ? body['data'] : null;

        if (data is! Map || data['results'] is! List) {
          throw const ApiException('Unexpected course list response.');
        }

        final items = (data['results'] as List)
            .map(
              (item) => PublicCourse.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();

        final next = data['next'];

        return PublicCoursePage(
          items: items,
          hasNext: next != null && next.toString().isNotEmpty,
        );
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

  Future<MyCoursePage> myCourses({
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

        final body = response.data;
        final data = body is Map ? body['data'] : null;

        if (data is! Map || data['results'] is! List) {
          throw const ApiException('Unexpected course list response.');
        }

        final items = (data['results'] as List)
            .map(
              (item) => MyCourse.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();

        final next = data['next'];

        return MyCoursePage(
          items: items,
          hasNext: next != null && next.toString().isNotEmpty,
        );
      });

  Future<MyCourse> myCourse(String uuid) => _request(() async {
    final response = await _dio.get(ApiUrls.myCourse(uuid));

    return MyCourse.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  });

  Future<Map<String, dynamic>> courseEnrollmentStatus(
    String courseUuid,
  ) =>
      _request(() async {
        final response = await _dio.get(
          ApiUrls.studentCourseEnrollment(courseUuid),
        );
        return Map<String, dynamic>.from(
          response.data['data'] as Map,
        );
      });

  Future<CourseResourcePage> _resourcePage(String path, int page) =>
      _request(() async {
        final response = await _dio.get(
          path,
          queryParameters: {'page': page, 'page_size': 20},
        );
        final body = response.data;
        final data = body is Map ? body['data'] : null;
        final next = data is Map ? data['next'] : null;
        return CourseResourcePage(
          items: _items(body)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList(),
          hasNext: next != null && next.toString().isNotEmpty,
        );
      });

  Future<CourseResourcePage> materialsPage(String uuid, {int page = 1}) =>
      _resourcePage(ApiUrls.myCourseMaterials(uuid), page);

  Future<CourseResourcePage> classesPage(String uuid, {int page = 1}) =>
      _resourcePage(ApiUrls.myCourseClasses(uuid), page);

  Future<List<Map<String, dynamic>>> _allPages(String path) =>
      _request(() async {
        final items = <Map<String, dynamic>>[];
        var page = 1;

        while (true) {
          final response = await _dio.get(
            path,
            queryParameters: {
              'page': page,
              'page_size': 100,
            },
          );

          items.addAll(