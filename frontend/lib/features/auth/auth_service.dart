import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/storage/token_storage.dart';

class LoggedInUser {
  final String email;
  final String fullName;
  final String userType;
  final String? firmName;

  const LoggedInUser({
    required this.email,
    required this.fullName,
    required this.userType,
    this.firmName,
  });

  factory LoggedInUser.fromJson(Map<String, dynamic> json) {
    return LoggedInUser(
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      userType: json['user_type']?.toString() ?? '',
      firmName: json['firm_name']?.toString(),
    );
  }
}

class AuthService {
  AuthService()
      : _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );

  final Dio _dio;
  final TokenStorage _tokenStorage = TokenStorage();

  Future<LoggedInUser> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login/',
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );

      final responseData = response.data as Map<String, dynamic>;

      if (responseData['success'] != true) {
        throw Exception(
          responseData['message']?.toString() ?? 'Login failed.',
        );
      }

      final data = responseData['data'] as Map<String, dynamic>;
      final tokens = data['tokens'] as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;

      await _tokenStorage.saveTokens(
        accessToken: tokens['access'].toString(),
        refreshToken: tokens['refresh'].toString(),
      );

      return LoggedInUser.fromJson(user);
    } on DioException catch (error) {
      final responseData = error.response?.data;

      if (responseData is Map<String, dynamic>) {
        throw Exception(
          responseData['message']?.toString() ??
              'Unable to sign in. Please try again.',
        );
      }

      throw Exception(
        'Cannot connect to the backend. Check that the Django server is running.',
      );
    }
  }

  Future<void> logout() async {
    await _tokenStorage.clearTokens();
  }
}