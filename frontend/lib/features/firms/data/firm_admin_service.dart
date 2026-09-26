import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_urls.dart';
import 'firm_admin_model.dart';

class FirmAdminService {
  FirmAdminService(this._dio);
  final Dio _dio;

  Future<T> _request<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<FirmAdminsListResponse> listForFirm(String firmUuid) => _request(() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiUrls.firmAdmins(firmUuid));
    return FirmAdminsListResponse.fromJson(response.data ?? {});
  });

  Future<FirmAdminsListResponse> listAll() => _request(() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiUrls.allFirmAdmins);
    return FirmAdminsListResponse.fromJson(response.data ?? {});
  });

  Future<FirmAdminDetailResponse> create(
    String firmUuid, FirmAdminCreateRequest request,
  ) => _request(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiUrls.firmAdminCreate(firmUuid), data: request.toJson());
    return FirmAdminDetailResponse.fromJson(response.data ?? {});
  });
}
