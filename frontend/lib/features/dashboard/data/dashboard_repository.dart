import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/utils/formatters.dart';

enum DashboardReport { collection, dues, enrollments, grading }

extension DashboardReportInfo on DashboardReport {
  String get title => switch (this) {
    DashboardReport.collection => 'Fee collection',
    DashboardReport.dues => 'Pending dues',
    DashboardReport.enrollments => 'Enrollment status',
    DashboardReport.grading => 'Pending grading',
  };

  bool get usesDates =>
      this == DashboardReport.collection || this == DashboardReport.dues;

  String get endpoint => switch (this) {
    DashboardReport.collection => '/dashboard/reports/fees/collection/',
    DashboardReport.dues => '/dashboard/reports/fees/pending-dues/',
    DashboardReport.enrollments =>
    '/dashboard/reports/enrollments/status/',
    DashboardReport.grading =>
    '/dashboard/reports/assignments/pending-grading/',
  };

  String get pageKey => switch (this) {
    DashboardReport.collection => 'payments',
    DashboardReport.dues => 'fee_accounts',
    DashboardReport.enrollments => 'enrollments',
    DashboardReport.grading => 'submissions',
  };
}

class DashboardMetric {
  const DashboardMetric(
      this.label,
      this.value, {
        this.money = false,
        this.caption,
      });

  final String label;
  final num value;
  final bool money;
  final String? caption;

  String get text => money ? formatInr(value) : value.toString();
}

class DashboardSummary {
  const DashboardSummary(this.metrics);

  final List<DashboardMetric> metrics;

  DashboardMetric metricFor(String label) {
    return metrics.firstWhere(
          (item) => item.label == label,
      orElse: () => DashboardMetric(label, 0),
    );
  }

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final metrics = <DashboardMetric>[];

    for (final entry in {
      'students': 'Students',
      'teachers': 'Teachers',
      'courses': 'Courses',
    }.entries) {
      final item = _map(json[entry.key]);

      metrics.add(
        DashboardMetric(
          entry.value,
          _number(item['total']),
          caption: '${_number(item['active'])} active',
        ),
      );
    }

    final enrollments = _map(json['enrollments']);
    final fees = _map(json['fees']);
    final assignments = _map(json['assignments']);
    final liveClasses = _map(json['live_classes']);

    metrics.addAll([
      DashboardMetric('Enrollments', _number(enrollments['total'])),
      DashboardMetric(
        'Pending enrollments',
        _number(enrollments['pending']),
      ),
      DashboardMetric(
        'Active enrollments',
        _number(enrollments['active']),
      ),
      DashboardMetric(
        'Total paid',
        _number(fees['total_paid_amount']),
        money: true,
      ),
      DashboardMetric(
        'Pending balance',
        _number(fees['total_balance_amount']),
        money: true,
      ),
      DashboardMetric(
        'Collected since month start',
        _number(fees['collected_this_month']),
        money: true,
      ),
      DashboardMetric(
        'Pending grading',
        _number(assignments['pending_grading']),
      ),
      DashboardMetric(
        'Upcoming classes',
        _number(liveClasses['upcoming']),
      ),
      DashboardMetric(
        'Live now',
        _number(liveClasses['live_now']),
      ),
    ]);

    return DashboardSummary(metrics);
  }
}

class DashboardReportRow {
  const DashboardReportRow({
    required this.title,
    required this.subtitle,
    required this.details,
    this.status,
    this.route,
  });

  final String title;
  final String subtitle;
  final List<String> details;
  final String? status;
  final String? route;
}

class DashboardReportPage {
  const DashboardReportPage({
    required this.count,
    required this.metrics,
    required this.rows,
  });

  final int count;
  final List<DashboardMetric> metrics;
  final List<DashboardReportRow> rows;

  factory DashboardReportPage.fromJson(
      DashboardReport type,
      Map<String, dynamic> json,
      ) {
    final page = _map(json[type.pageKey]);
    final rawResults = page['results'];

    if (rawResults is! List) {
      throw const FormatException('Report results are missing.');
    }

    final summary =
    type == DashboardReport.grading ? json : _map(json['summary']);

    final metrics = switch (type) {
      DashboardReport.collection => [
        DashboardMetric(
          'Collected',
          _number(summary['total_collected']),
          money: true,
        ),
        DashboardMetric('Payments', _number(summary['payment_count'])),
      ],
      DashboardReport.dues => [
        DashboardMetric(
          'Pending',
          _number(summary['total_pending_amount']),
          money: true,
        ),
        DashboardMetric(
          'Fee accounts',
          _number(summary['fee_account_count']),
        ),
      ],
      DashboardReport.enrollments => [
        DashboardMetric('Total', _number(summary['total'])),
        DashboardMetric('Active', _number(summary['active'])),
        DashboardMetric('Pending', _number(summary['pending'])),
      ],
      DashboardReport.grading => [
        DashboardMetric(
          'Pending grading',
          _number(summary['pending_grading_count']),
        ),
      ],
    };

    final rows = rawResults.map<DashboardReportRow>((item) {
      final row = _map(item);
      final student = _text(row['student_name']);
      final course = _text(row['course_name']);

      return switch (type) {
        DashboardReport.collection => DashboardReportRow(
          title: '$student • ${formatInr(_number(row['amount']))}',
          subtitle: course,
          status: _text(row['status']),
          details: [
            'Method: ${_text(row['payment_method'])}',
            'Paid: ${_date(row['payment_date'])}',
          ],
        ),
        DashboardReport.dues => DashboardReportRow(
          title: student,
          subtitle: course,
          status: _text(row['status']),
          details: [
            'Balance: ${formatInr(_number(row['balance_amount']))}',
            'Due: ${_date(row['due_date'])}',
          ],
        ),
        DashboardReport.enrollments => DashboardReportRow(
          title: student,
          subtitle: course,
          status: _text(row['status']),
          details: [
            'Admission: ${_text(row['admission_number'])}',
            'Enrolled: ${_date(row['enrolled_at'])}',
          ],
        ),
        DashboardReport.grading => DashboardReportRow(
          title: student,
          subtitle: '${_text(row['assignment_title'])} • $course',
          status: 'SUBMITTED',
          details: [
            'Admission: ${_text(row['admission_number'])}',
            'Submitted: ${_date(row['submitted_at'])}',
          ],
        ),
      };
    }).toList();

    return DashboardReportPage(
      count: _number(page['count']).toInt(),
      metrics: metrics,
      rows: rows,
    );
  }
}

class SuperAdminDashboardSummary {
  const SuperAdminDashboardSummary({
    required this.totalFirms,
    required this.activeFirms,
    required this.totalStudents,
    required this.activeStudents,
    required this.totalCourses,
    required this.activeCourses,
    required this.totalEnrollments,
    required this.activeEnrollments,
  });

  final int totalFirms;
  final int activeFirms;
  final int totalStudents;
  final int activeStudents;
  final int totalCourses;
  final int activeCourses;
  final int totalEnrollments;
  final int activeEnrollments;

  factory SuperAdminDashboardSummary.fromJson(Map<String, dynamic> json) {
    final summary = _map(json['summary']);

    return SuperAdminDashboardSummary(
      totalFirms: _count(summary['total_firms']),
      activeFirms: _count(summary['active_firms']),
      totalStudents: _count(summary['total_students']),
      activeStudents: _count(summary['active_students']),
      totalCourses: _count(summary['total_courses']),
      activeCourses: _count(summary['active_courses']),
      totalEnrollments: _count(summary['total_enrollments']),
      activeEnrollments: _count(summary['active_enrollments']),
    );
  }
}

class SuperAdminFirmOverview {
  const SuperAdminFirmOverview({
    required this.uuid,
    required this.name,
    required this.code,
    required this.isActive,
    required this.activeStudents,
    required this.activeCourses,
    required this.activeEnrollments,
    required this.paidEnrollments,
    required this.courses,
  });

  final String uuid;
  final String name;
  final String code;
  final bool isActive;
  final int activeStudents;
  final int activeCourses;
  final int activeEnrollments;
  final int paidEnrollments;
  final List<SuperAdminCourseOverview> courses;

  factory SuperAdminFirmOverview.fromJson(Map<String, dynamic> json) {
    final rawCourses = json['courses'];

    return SuperAdminFirmOverview(
      uuid: _text(json['uuid']),
      name: _text(json['name']),
      code: _text(json['code']),
      isActive: json['is_active'] == true,
      activeStudents: _number(json['active_students']).toInt(),
      activeCourses: _number(json['active_courses']).toInt(),
      activeEnrollments: _number(json['active_enrollments']).toInt(),
      paidEnrollments: _number(json['paid_enrollments']).toInt(),
      courses: rawCourses is List
          ? rawCourses
          .map((item) => SuperAdminCourseOverview.fromJson(_map(item)))
          .toList()
          : const [],
    );
  }
}

class SuperAdminCourseOverview {
  const SuperAdminCourseOverview({
    required this.name,
    required this.code,
    required this.isActive,
    required this.enrolledStudents,
    required this.activeEnrollments,
  });

  final String name;
  final String code;
  final bool isActive;
  final int enrolledStudents;
  final int activeEnrollments;

  factory SuperAdminCourseOverview.fromJson(Map<String, dynamic> json) {
    return SuperAdminCourseOverview(
      name: _text(json['name']),
      code: _text(json['code']),
      isActive: json['is_active'] == true,
      enrolledStudents: _number(json['enrolled_students']).toInt(),
      activeEnrollments: _number(json['active_enrollments']).toInt(),
    );
  }
}

class DashboardRepository {
  DashboardRepository(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> _get(
      String path, [
        Map<String, dynamic>? query,
      ]) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: query,
      );

      final body = response.data;
      if (body == null || body['success'] == false) {
        throw const FormatException('Invalid dashboard response.');
      }

      return _map(body['data'] ?? body);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<DashboardSummary> summary() async {
    return DashboardSummary.fromJson(await _get('/dashboard/summary/'));
  }

  Future<SuperAdminDashboardSummary> superAdminSummary() async {
    final data = await _get('/dashboard/super-admin/summary/');
    return SuperAdminDashboardSummary.fromJson(data);
  }

  Future<DashboardReportPage> report({
    required DashboardReport type,
    int page = 1,
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final json = await _get(
      type.endpoint,
      {
        'page': page,
        'page_size': 20,
        if (type == DashboardReport.enrollments && status != null)
          'status': status,
        if (type.usesDates && dateFrom != null)
          'date_from': _apiDate(dateFrom),
        if (type.usesDates && dateTo != null) 'date_to': _apiDate(dateTo),
      },
    );

    return DashboardReportPage.fromJson(type, json);
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>(
      (ref) => DashboardRepository(ref.watch(dioProvider)),
);

Map<String, dynamic> _map(dynamic value) {
  if (value is! Map) {
    throw const FormatException('Dashboard data is missing.');
  }
  return Map<String, dynamic>.from(value);
}

num _number(dynamic value) {
  final number = value is num ? value : num.tryParse('$value');
  return number ?? 0;
}

int _count(dynamic value) => _number(value).toInt();

String _text(dynamic value) => value?.toString() ?? '';

String _apiDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String _date(dynamic value) {
  final text = _text(value);
  if (text.isEmpty) return 'Not set';

  final date = DateTime.tryParse(text);
  if (date == null) return text;

  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}