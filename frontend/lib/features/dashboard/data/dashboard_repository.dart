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
    DashboardReport.grading => 'Pending assignment grading',
  };
  bool get usesDates => this == DashboardReport.collection || this == DashboardReport.dues;
  String get endpoint => switch (this) {
    DashboardReport.collection => '/dashboard/reports/fees/collection/',
    DashboardReport.dues => '/dashboard/reports/fees/pending-dues/',
    DashboardReport.enrollments => '/dashboard/reports/enrollments/status/',
    DashboardReport.grading => '/dashboard/reports/assignments/pending-grading/',
  };
  String get pageKey => switch (this) {
    DashboardReport.collection => 'payments',
    DashboardReport.dues => 'fee_accounts',
    DashboardReport.enrollments => 'enrollments',
    DashboardReport.grading => 'submissions',
  };
}

class DashboardMetric {
  const DashboardMetric(this.label, this.value, {this.money = false, this.caption});
  final String label;
  final num value;
  final bool money;
  final String? caption;
  String get text => money ? formatInr(value) : value.toString();
}

class DashboardSummary {
  const DashboardSummary(this.metrics);
  final List<DashboardMetric> metrics;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final metrics = <DashboardMetric>[];
    for (final entry in {'students': 'Students', 'teachers': 'Teachers', 'courses': 'Courses'}.entries) {
      final section = _map(json[entry.key]);
      metrics.add(DashboardMetric(entry.value, _count(section['total']), caption: '${_count(section['active'])} active'));
    }
    final enrollments = _map(json['enrollments']);
    metrics.add(DashboardMetric('Enrollments', _count(enrollments['total'])));
    for (final status in ['pending', 'active', 'completed', 'cancelled']) {
      metrics.add(DashboardMetric('${status[0].toUpperCase()}${status.substring(1)} enrollments', _count(enrollments[status])));
    }
    final fees = _map(json['fees']);
    metrics.addAll([
      DashboardMetric('Total fees before discount', _number(fees['total_fee_amount']), money: true),
      DashboardMetric('Total paid', _number(fees['total_paid_amount']), money: true),
      DashboardMetric('Pending balance', _number(fees['total_balance_amount']), money: true),
      DashboardMetric('Collected since month start', _number(fees['collected_this_month']), money: true,
          caption: 'Recorded payments dated from month start'),
      DashboardMetric('Unpaid accounts', _count(fees['unpaid_accounts'])),
      DashboardMetric('Partially paid accounts', _count(fees['partially_paid_accounts'])),
      DashboardMetric('Pending grading', _count(_map(json['assignments'])['pending_grading'])),
      DashboardMetric('Upcoming classes', _count(_map(json['live_classes'])['upcoming'])),
      DashboardMetric('Live now', _count(_map(json['live_classes'])['live_now'])),
    ]);
    return DashboardSummary(metrics);
  }
}

class DashboardReportRow {
  const DashboardReportRow({required this.title, required this.subtitle, required this.details, this.status, this.route});
  final String title;
  final String subtitle;
  final List<String> details;
  final String? status;
  final String? route;
}

class DashboardReportPage {
  const DashboardReportPage({required this.count, required this.metrics, required this.rows});
  final int count;
  final List<DashboardMetric> metrics;
  final List<DashboardReportRow> rows;

  factory DashboardReportPage.fromJson(DashboardReport type, Map<String, dynamic> json) {
    final page = _map(json[type.pageKey]);
    final count = _count(page['count']);
    final raw = page['results'];
    if (raw is! List) throw const FormatException('Report results are missing.');
    final summary = type == DashboardReport.grading ? json : _map(json['summary']);
    final metrics = switch (type) {
      DashboardReport.collection => [
        DashboardMetric('Total collected', _number(summary['total_collected']), money: true),
        DashboardMetric('Payments', _count(summary['payment_count'])),
      ],
      DashboardReport.dues => [
        DashboardMetric('Total pending', _number(summary['total_pending_amount']), money: true),
        DashboardMetric('Fee accounts', _count(summary['fee_account_count'])),
      ],
      DashboardReport.enrollments => [
        for (final key in ['total', 'pending', 'active', 'completed', 'cancelled'])
          DashboardMetric('${key[0].toUpperCase()}${key.substring(1)}', _count(summary[key])),
      ],
      DashboardReport.grading => [DashboardMetric('Pending grading', _count(summary['pending_grading_count']))],
    };
    final rows = raw.map<DashboardReportRow>((value) {
      final row = _map(value);
      final student = _text(row['student_name']);
      final course = _text(row['course_name']);
      switch (type) {
        case DashboardReport.collection:
          return DashboardReportRow(title: '$student • ${formatInr(_number(row['amount']))}', subtitle: course,
              status: _text(row['status']), details: [
                'Method: ${_text(row['payment_method'])}', 'Paid: ${_date(row['payment_date'])}',
                if (_text(row['transaction_reference']).isNotEmpty) 'Reference: ${_text(row['transaction_reference'])}',
                if (_text(row['recorded_by_name']).isNotEmpty) 'Recorded by: ${_text(row['recorded_by_name'])}',
              ]);
        case DashboardReport.dues:
          return DashboardReportRow(title: student, subtitle: course, status: _text(row['status']),
              route: '/fees/${_uuid(row['enrollment_uuid'])}', details: [
                'Admission: ${_text(row['admission_number'])}',
                'Balance: ${formatInr(_number(row['balance_amount']))}',
                'Paid: ${formatInr(_number(row['paid_amount']))}', 'Due: ${_date(row['due_date'])}',
              ]);
        case DashboardReport.enrollments:
          return DashboardReportRow(title: student, subtitle: course, status: _text(row['status']),
              route: '/enrollments/${_uuid(row['uuid'])}', details: [
                'Admission: ${_text(row['admission_number'])}', 'Enrolled: ${_date(row['enrolled_at'])}',
              ]);
        case DashboardReport.grading:
          return DashboardReportRow(title: student, subtitle: '${_text(row['assignment_title'])} • $course',
              route: '/assignments/${_uuid(row['assignment_uuid'])}/submissions', details: [
                'Admission: ${_text(row['admission_number'])}', 'Submitted: ${_date(row['submitted_at'])}',
              ]);
      }
    }).toList();
    return DashboardReportPage(count: count, metrics: metrics, rows: rows);
  }
}

class DashboardRepository {
  DashboardRepository(this.dio);
  final Dio dio;
  static const pageSize = 20;

  Future<Map<String, dynamic>> _get(String path, [Map<String, dynamic>? query]) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(path, queryParameters: query);
      final body = response.data;
      if (body == null || body['success'] == false) throw const FormatException('Invalid dashboard response.');
      return _map(body['data'] ?? body);
    } on DioException catch (e) { throw ApiException.fromDioException(e); }
  }

  Future<DashboardSummary> summary() async => DashboardSummary.fromJson(await _get('/dashboard/summary/'));

  Future<DashboardReportPage> report({required DashboardReport type, int page = 1,
    String? courseUuid, String? status, DateTime? dateFrom, DateTime? dateTo}) async {
    final json = await _get(type.endpoint, {
      'page': page, 'page_size': pageSize,
      if (courseUuid != null && courseUuid.isNotEmpty) 'course_uuid': courseUuid,
      if (type == DashboardReport.enrollments && status != null) 'status': status,
      if (type.usesDates && dateFrom != null) 'date_from': _apiDate(dateFrom),
      if (type.usesDates && dateTo != null) 'date_to': _apiDate(dateTo),
    });
    return DashboardReportPage.fromJson(type, json);
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) => DashboardRepository(ref.watch(dioProvider)));

Map<String, dynamic> _map(dynamic value) {
  if (value is! Map) throw const FormatException('Dashboard data is missing.');
  return Map<String, dynamic>.from(value);
}
num _number(dynamic value) {
  final number = value is num ? value : num.tryParse(value?.toString() ?? '');
  if (number == null || !number.isFinite) throw const FormatException('Invalid dashboard amount.');
  return number;
}
int _count(dynamic value) {
  final number = _number(value);
  if (number < 0 || number != number.toInt()) throw const FormatException('Invalid dashboard count.');
  return number.toInt();
}
String _text(dynamic value) => value?.toString() ?? '';
String _uuid(dynamic value) {
  final uuid = _text(value);
  if (!RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(uuid)) {
    throw const FormatException('Invalid report identifier.');
  }
  return uuid;
}
String _apiDate(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String _date(dynamic value) {
  final text = _text(value);
  if (text.isEmpty) return 'Not set';
  final date = DateTime.tryParse(text);
  if (date == null) return text;
  if (text.length == 10) return formatDate(date);
  final local = date.toLocal();
  return '${formatDate(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
