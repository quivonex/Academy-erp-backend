import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_urls.dart';
import 'firm_model.dart';

class FirmService {
  FirmService(this._dio);
  final Dio _dio;

  Future<T> _request<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<FirmsListResponse> listFirms() => _request(() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiUrls.firms);
    return FirmsListResponse.fromJson(response.data ?? {});
  });

  Future<FirmDetailResponse> getFirm(String uuid) => _request(() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiUrls.firmDetail(uuid));
    return FirmDetailResponse.fromJson(response.data ?? {});
  });

  Future<FirmDetailResponse> createFirm(FirmCreateRequest request) => _request(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiUrls.firms, data: request.toJson());
    return FirmDetailResponse.fromJson(response.data ?? {});
  });

  Future<FirmDetailResponse> patchFirm(String uuid, FirmUpdateRequest request) => _request(() async {
    final response = await _dio.patch<Map<String, dynamic>>(
      ApiUrls.firmDetail(uuid), data: request.toJson());
    return FirmDetailResponse.fromJson(response.data ?? {});
  });

  Future<FirmStatusResponse> activateFirm(String uuid) => _request(() async {
    final response = await _dio.patch<Map<String, dynamic>>(ApiUrls.firmActivate(uuid));
    return FirmStatusResponse.fromJson(response.data ?? {});
  });

  Future<FirmStatusResponse> deactivateFirm(String uuid) => _request(() async {
    final response = await _dio.patch<Map<String, dynamic>>(ApiUrls.firmDeactivate(uuid));
    return FirmStatusResponse.fromJson(response.data ?? {});
  });
}
