import 'package:dio/dio.dart';

import 'api_urls.dart';
import 'token_storage.dart';

/// Django backend on the same local network. Override with --dart-define=API_BASE_URL=...
/// Android emulator with a server on the host PC can use http://10.0.2.2:8000/api/v1.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://192.168.31.91:8000/api/v1',
);

/// Builds the single Dio instance used by every repository.
///
/// - [tokenStorage] supplies the bearer token and persists refreshed tokens.
/// - [refreshToken] is called on a 401 to attempt a silent token refresh;
///   it should return the new access token, or null if the refresh failed.
/// - [onUnauthenticated] fires when refresh also fails, so the app can
///   drop back to the login screen.
Dio buildDio({
  required TokenStorage tokenStorage,
  required Future<String?> Function() refreshToken,
  required void Function() onUnauthenticated,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      contentType: 'application/json',
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Bypass ngrok's free-tier HTML interstitial page.
        options.headers['ngrok-skip-browser-warning'] = 'true';

        final token = await tokenStorage.readAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        handler.next(options);
      },
      onError: (error, handler) async {
        final isAuthEndpoint = error.requestOptions.path.contains('/auth/');
        if (error.response?.statusCode == 401 && !isAuthEndpoint &&
            error.requestOptions.extra['retried'] != true) {
          final newToken = await refreshToken();
          if (newToken != null) {
            final retryOptions = error.requestOptions;
            retryOptions.extra['retried'] = true;
            retryOptions.headers['Authorization'] = 'Bearer $newToken';
            try {
              final response = await dio.fetch(retryOptions);
              return handler.resolve(response);
            } catch (_) {
              // fall through to unauthenticated handling below
            }
          }
          onUnauthenticated();
        }
        handler.next(error);
      },
    ),
  );

  return dio;
}
