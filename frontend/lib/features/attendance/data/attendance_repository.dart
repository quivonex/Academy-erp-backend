import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import 'attendance_models.dart';

/// Attendance repository stub.
///
/// The backend does not yet have an attendance module. All methods throw
/// [ApiException] with a clear message until the backend endpoints are built.
class AttendanceRepository {
  AttendanceRepository(this._dio);
  final Dio _dio;

  Future<void> submitAttendance({
    required String courseUuid,
    required DateTime sessionDate,
    required List<AttendanceMark> marks,
  }) async {
    throw const ApiException(
      'Attendance tracking is not yet available. This feature is coming soon.',
    );
  }
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(ref.watch(dioProvider));
});
