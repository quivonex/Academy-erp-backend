import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/data/login_model.dart';
import '../network/api_exception.dart';
import '../network/dio_client.dart';
import '../network/token_storage.dart';
import '../services/auth_service.dart';
import 'user_role.dart';

class SessionState {
  const SessionState({
    this.isLoading = true,
    this.isAuthenticated = false,
    this.userUuid,
    this.role,
    this.firmUuid,
    this.firmName,
  });

  final bool isLoading;
  final bool isAuthenticated;
  final String? userUuid;
  final UserRole? role;
  final String? firmUuid;
  final String? firmName;

  static const unauthenticated = SessionState(isLoading: false);
}

class SessionController extends Notifier<SessionState> {
  late final TokenStorage _tokenStorage;
  late final Dio _authDio;
  late final AuthService _authService;

  @override
  SessionState build() {
    _tokenStorage = TokenStorage(const FlutterSecureStorage());
    _authDio = Dio(BaseOptions(
      baseUrl: apiBaseUrl,
      contentType: 'application/json',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'ngrok-skip-browser-warning': 'true'},
    ));
    _authService = AuthService(_authDio);
    Future.microtask(_restoreSession);
    return const SessionState();
  }

  SessionState _fromUser(Map<String, dynamic> user) {
    final role = UserRole.fromApi(
      user['user_type'].toString(),
    );

    if (role != UserRole.student && !role.isEnterpriseShell) {
      throw const ApiException(
        'This app currently supports students and academy admins.',
      );
    }

    return SessionState(
      isLoading: false,
      isAuthenticated: true,
      userUuid: user['uuid']?.toString(),
      role: role,
      firmUuid: user['firm_uuid']?.toString(),
      firmName: user['firm_name']?.toString(),
    );
  }

  Future<void> _restoreSession() async {
    try {
      var access = await _tokenStorage.readAccessToken();
      if (access == null) {
        state = SessionState.unauthenticated;
        return;
      }
      Map<String, dynamic> user;
      try {
        user = await _authService.me(access);
      } on DioException catch (e) {
        if (e.response?.statusCode != 401) rethrow;
        access = await refreshAccessToken();
        if (access == null) {
          await _tokenStorage.clear();
          state = SessionState.unauthenticated;
          return;
        }
        user = await _authService.me(access);
      }
      state = _fromUser(user);
    } catch (_) {
      // A network error should not destroy a valid stored refresh token.
      state = SessionState.unauthenticated;
    }
  }

  Future<void> login(LoginRequest request) async {
    state = const SessionState();
    try {
      await _tokenStorage.clear();
      final response = await _authService.login(request);
      final user = response.data.user;
      final next = _fromUser({
        'uuid': user.uuid,
        'user_type': user.userType,
        'firm_uuid': user.firmUuid,
        'firm_name': user.firmName,
      });
      if (response.data.tokens.access.isEmpty || response.data.tokens.refresh.isEmpty) {
        throw const ApiException('Login response did not include tokens.');
      }
      await _tokenStorage.save(
        access: response.data.tokens.access,
        refresh: response.data.tokens.refresh,
      );
      state = next;
    } on DioException catch (e) {
      state = SessionState.unauthenticated;
      throw ApiException.fromDioException(e);
    } catch (_) {
      state = SessionState.unauthenticated;
      rethrow;
    }
  }

  Future<String?> refreshAccessToken() async {
    final refresh = await _tokenStorage.readRefreshToken();
    if (refresh == null) return null;
    try {
      final tokens = await _authService.refresh(refresh);
      if (tokens.access.isEmpty) return null;
      await _tokenStorage.save(access: tokens.access, refresh: tokens.refresh);
      return tokens.access;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    var access = await _tokenStorage.readAccessToken();
    var refresh = await _tokenStorage.readRefreshToken();
    if (access != null && refresh != null) {
      try {
        await _authService.logout(access, refresh);
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          access = await refreshAccessToken();
          if (access != null) {
            refresh = await _tokenStorage.readRefreshToken();
            if (refresh == null) {
              throw const ApiException('Could not refresh the session. Please sign in again.');
            }
            try {
              await _authService.logout(access, refresh);
            } on DioException catch (retryError) {
              throw ApiException.fromDioException(retryError);
            }
          } else {
            throw const ApiException('Could not log out. Please try again.');
          }
        } else {
          throw ApiException.fromDioException(e);
        }
      }
    }
    // Clear local credentials once the backend has blacklisted this refresh token.
    await _tokenStorage.clear();
    state = SessionState.unauthenticated;
  }

  void forceLogout() {
    Future.microtask(() async {
      await _tokenStorage.clear();
      state = SessionState.unauthenticated;
    });
  }

  TokenStorage get tokenStorage => _tokenStorage;
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
