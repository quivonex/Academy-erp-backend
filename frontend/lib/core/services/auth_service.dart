import 'package:dio/dio.dart';

import '../network/api_urls.dart';
import '../../features/auth/data/login_model.dart';

class AuthService {
  AuthService(this._dio);
  final Dio _dio;

  Future<LoginResponse> login(LoginRequest request) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiUrls.login, data: request.toJson(),
    );
    return LoginResponse.fromJson(response.data ?? {});
  }

  /// SimpleJWT returns {access: ...}; rotated refresh is optional.
  Future<AuthTokens> refresh(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiUrls.refresh, data: {'refresh': refreshToken},
    );
    final data = response.data ?? {};
    return AuthTokens.fromJson({
      'access': data['access'],
      'refresh': data['refresh'] ?? refreshToken,
    });
  }

  Future<Map<String, dynamic>> me(String accessToken) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiUrls.me,
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return Map<String, dynamic>.from(response.data!['data'] as Map);
  }

  Future<void> logout(String accessToken, String refreshToken) async {
    await _dio.post(ApiUrls.logout,
      data: {'refresh': refreshToken},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }
}
