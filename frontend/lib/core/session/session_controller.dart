import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/data/login_model.dart';
import '../network/api_exception.dart';
import '../network/dio_client.dart';
import '../network/token_storage.dart';
import '../services/auth_service.dart';
import '../utils/brand_utils.dart';
import 'user_role.dart';

class SessionState {
  const SessionState({
    this.isLoading = true,
    this.isAuthenticated = false,
    this.userUuid,
    this.role,
    this.firmUuid,
    this.firmName,
    this.restoreError,
  });

  final bool isLoading;
  final bool isAuthenticated;
  final String? userUuid;
  final UserRole? role;
  final String? firmUuid;
  final String? firmName;
  final String? restoreError;

  static const unauthenticated = SessionState(isLoading: false);
}

final sessionTokenStorageProvider = Provider<TokenStorage>(
  (ref) => TokenStorage(const FlutterSecureStorage()),
);

final sessionAuthServiceProvider = Provider<AuthService>((ref) {
  return AuthService(Dio(BaseOptions(
    baseUrl: apiBaseUrl,
    contentType: 'application/json',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'ngrok-skip-browser-warning': 'true'},
  )));
});

final sessionRestoreTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 10),
);

class SessionController extends Notifier<SessionState> {
  late final TokenStorage _tokenStorage;
  CancelToken? _restoreCancelToken;
  int _restoreRevision = 0;
  late final AuthService _authService;
  Future<String?>? _refreshInFlight;

  @override
  SessionState build() {
    _tokenStorage = ref.read(sessionTokenStorageProvider);
    _authService = ref.read(sessionAuthServiceProvider);
    ref.onDispose(() {
      _restoreRevision++;
      _restoreCancelToken?.cancel();
    });
    Future.microtask(retryRestore);
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
      firmName: cleanFirmName(user['firm_name']?.toString()),
    );
  }

  Future<void> retryRestore() async {
    final revision = ++_restoreRevision;
    _restoreCancelToken?.cancel();
    final cancelToken = CancelToken();
    _restoreCancelToken = cancelToken;
    state = const SessionState();
    bool current() => revision == _restoreRevision && !cancelToken.isCancelled;

    Future<SessionState> restore() async {
      var access = await _tokenStorage.readAccessToken();
      if (!current()) throw const ApiException('Session check cancelled.');
      if (access == null) return SessionState.unauthenticated;
      Map<String, dynamic> user;
      try {
        user = await _authService.me(access, cancelToken: cancelToken);
      } on DioException catch (e) {
        if (e.response?.statusCode != 401 || !current()) rethrow;
        final refresh = await _tokenStorage.readRefreshToken();
        if (!current()) rethrow;
        if (refresh == null) return SessionState.unauthenticated;
        final tokens = await _authService.refresh(refresh, cancelToken: cancelToken);
        if (!current()) rethrow;
        if (tokens.access.isEmpty) {
          throw const ApiException('Session could not be refreshed.');
        }
        await _tokenStorage.save(access: tokens.access, refresh: tokens.refresh);
        if (!current()) rethrow;
        access = tokens.access;
        user = await _authService.me(access, cancelToken: cancelToken);
      }
      return _fromUser(user);
    }

    try {
      final restored = await restore().timeout(ref.read(sessionRestoreTimeoutProvider));
      if (current()) state = restored;
    } catch (error) {
      if (!current()) return;
      cancelToken.cancel('Session check finished.');
      if (error is DioException &&
          (error.response?.statusCode == 401 || error.response?.statusCode == 403)) {
        state = SessionState.unauthenticated;
      } else {
        // Preserve credentials on slow/offline networks and offer a retry.
        state = const SessionState(
          restoreError: 'Unable to connect. Check your connection and try again.',
        );
      }
    }
  }

  void continueAsGuest() {
    _restoreRevision++;
    _restoreCancelToken?.cancel();
    state = SessionState.unauthenticated;
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

  Future<String?> _refreshAccessTokenOnce() async {
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

  Future<String?> refreshAccessToken() {
    final runningRefresh = _refreshInFlight;

    if (runningRefresh != null) {
      return runningRefresh;
    }

    final refresh = _refreshAccessTokenOnce();
    _refreshInFlight = refresh;

    refresh.whenComplete(() {
      if (identical(_refreshInFlight, refresh)) {
        _refreshInFlight = null;
      }
    });

    return refresh;
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
