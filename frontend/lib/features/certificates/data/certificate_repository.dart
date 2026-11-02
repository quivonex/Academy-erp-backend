import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_urls.dart';
import '../../../core/network/dio_provider.dart';

class Certificate {
  const Certificate({
    required this.uuid,
    required this.certificateNumber,
    required this.verificationCode,
    required this.courseName,
    required this.courseUuid,
    required this.studentName,
    required this.issuedAt,
    required this.isRevoked,
    required this.fileAvailable,
    this.requiredWatchPercentage,
    this.achievedWatchPercentage,
    this.revokedAt,
    this.revokedReason,
  });

  final String uuid;
  final String certificateNumber;
  final String verificationCode;
  final String courseName;
  final String courseUuid;
  final String studentName;
  final String issuedAt;
  final bool isRevoked;
  final bool fileAvailable;
  final String? requiredWatchPercentage;
  final String? achievedWatchPercentage;
  final String? revokedAt;
  final String? revokedReason;

  factory Certificate.fromJson(Map<String, dynamic> json) => Certificate(
        uuid: json['uuid']?.toString() ?? '',
        certificateNumber: json['certificate_number']?.toString() ?? '',
        verificationCode: json['verification_code']?.toString() ?? '',
        courseName: json['course_name']?.toString() ?? '',
        courseUuid: json['course_uuid']?.toString() ?? '',
        studentName: json['student_name']?.toString() ?? '',
        issuedAt: json['issued_at']?.toString() ?? '',
        isRevoked: json['is_revoked'] == true,
        fileAvailable: json['file_available'] == true,
        requiredWatchPercentage:
            json['required_watch_percentage']?.toString(),
        achievedWatchPercentage:
            json['achieved_watch_percentage']?.toString(),
        revokedAt: json['revoked_at']?.toString(),
        revokedReason: json['revoked_reason']?.toString(),
      );
}

class CertificateStatus {
  const CertificateStatus({
    required this.enrollmentUuid,
    required this.courseUuid,
    required this.courseName,
    required this.isEligible,
    required this.certificateEnabled,
    required this.enrollmentIsActive,
    required this.totalVideos,
    required this.completedVideos,
    required this.achievedWatchPercentage,
    required this.requiredWatchPercentage,
    required this.feeFullyPaid,
    this.certificate,
  });

  final String enrollmentUuid;
  final String courseUuid;
  final String courseName;
  final bool isEligible;
  final bool certificateEnabled;
  final bool enrollmentIsActive;
  final int totalVideos;
  final int completedVideos;
  final String achievedWatchPercentage;
  final String requiredWatchPercentage;
  final bool feeFullyPaid;
  final Certificate? certificate;

  factory CertificateStatus.fromJson(Map<String, dynamic> json) =>
      CertificateStatus(
        enrollmentUuid: json['enrollment_uuid']?.toString() ?? '',
        courseUuid: json['course_uuid']?.toString() ?? '',
        courseName: json['course_name']?.toString() ?? '',
        isEligible: json['is_eligible'] == true,
        certificateEnabled: json['certificate_enabled'] == true,
        enrollmentIsActive: json['enrollment_is_active'] == true,
        totalVideos:
            int.tryParse(json['total_videos']?.toString() ?? '') ?? 0,
        completedVideos:
            int.tryParse(json['completed_videos']?.toString() ?? '') ?? 0,
        achievedWatchPercentage:
            json['achieved_watch_percentage']?.toString() ?? '0',
        requiredWatchPercentage:
            json['required_watch_percentage']?.toString() ?? '0',
        feeFullyPaid: json['fee_fully_paid'] == true,
        certificate: json['certificate'] is Map
            ? Certificate.fromJson(
                Map<String, dynamic>.from(json['certificate'] as Map))
            : null,
      );
}

class CertificateRepository {
  CertificateRepository(this._dio);

  final Dio _dio;

  Future<T> _request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<Certificate>> studentCertificates() => _request(() async {
        final response = await _dio.get(ApiUrls.studentCertificates);
        final body = response.data;
        final data = body is Map ? body['data'] : null;
        List<dynamic> raw;

        if (data is List) {
          raw = data;
        } else if (data is Map && data['results'] is List) {
          raw = data['results'] as List;
        } else {
          raw = [];
        }

        return raw
            .map((item) => Certificate.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList();
      });

  Future<CertificateStatus> certificateStatus(String courseUuid) =>
      _request(() async {
        final response = await _dio.get(
          ApiUrls.studentCertificateStatus(courseUuid),
        );

        return CertificateStatus.fromJson(
          Map<String, dynamic>.from(response.data['data'] as Map),
        );
      });

  Future<String> certificateDownloadUrl(String certificateUuid) =>
      _request(() async {
        final response = await _dio.get(
          ApiUrls.studentCertificateDownload(certificateUuid),
        );

        return response.data['data']['download_url']?.toString() ?? '';
      });
}

final certificateRepositoryProvider =
    Provider<CertificateRepository>((ref) {
  return CertificateRepository(ref.watch(dioProvider));
});
