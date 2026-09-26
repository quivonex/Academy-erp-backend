import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import 'attendance_models.dart';

class AttendanceRepository {
  AttendanceRepository(this._dio);
  final Dio _dio;

  /// Backend note: there is currently no "list students in a batch"
  /// endpoint (Student <-> Batch is derived via Enrollment.batch_id, not a
  /// direct FK). This screen therefore builds its roster from whichever
  /// students the admin adds via search — add a
  /// `GET /batches/{id}/students` endpoint on the backend to auto-populate
  /// the full roster instead.
  Future<void> submitAttendance({
    required int batchId,
    required DateTime sessionDate,
    required List<AttendanceMark> marks,
  }) async {
    try {
      await _dio.post('/attendance/sessions', data: {
        'batch_id': batchId,
        'session_date': sessionDate.toIso8601String().split('T').first,
        'records': marks.map((m) => m.toJson()).toList(),
      });
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(ref.watch(dioProvider));
});
