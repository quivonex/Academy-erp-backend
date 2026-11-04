import 'dart:async';

import 'package:dio/dio.dart';
import 'package:edusphere_admin_flutter/core/network/token_storage.dart';
import 'package:edusphere_admin_flutter/core/services/auth_service.dart';
import 'package:edusphere_admin_flutter/core/session/session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryTokens extends TokenStorage {
  _MemoryTokens() : super(const FlutterSecureStorage());
  int clears = 0;

  @override
  Future<String?> readAccessToken() async => 'stored-access';

  @override
  Future<String?> readRefreshToken() async => 'stored-refresh';

  @override
  Future<void> clear() async { clears++; }
}

class _SlowAuth extends AuthService {
  _SlowAuth() : super(Dio());
  final requests = <Completer<Map<String, dynamic>>>[];
  final cancellations = <CancelToken?>[];

  @override
  Future<Map<String, dynamic>> me(String accessToken, {CancelToken? cancelToken}) {
    cancellations.add(cancelToken);
    final result = Completer<Map<String, dynamic>>();
    requests.add(result);
    return result.future;
  }
}

void main() {
  testWidgets('slow restoration is cancellable and does not clear credentials',
      (tester) async {
    final tokens = _MemoryTokens();
    final auth = _SlowAuth();
    final container = ProviderContainer(overrides: [
      sessionTokenStorageProvider.overrideWithValue(tokens),
      sessionAuthServiceProvider.overrideWithValue(auth),
      sessionRestoreTimeoutProvider.overrideWithValue(const Duration(seconds: 1)),
    ]);
    addTearDown(container.dispose);
    container.read(sessionControllerProvider);
    await tester.pump();
    expect(auth.requests, hasLength(1));

    await tester.pump(const Duration(seconds: 2));
    expect(container.read(sessionControllerProvider).restoreError, isNotNull);
    expect(auth.cancellations.first!.isCancelled, isTrue);
    expect(tokens.clears, 0);

    container.read(sessionControllerProvider.notifier).continueAsGuest();
    auth.requests.first.complete({'uuid': 'student', 'user_type': 'STUDENT'});
    await tester.pump();
    expect(container.read(sessionControllerProvider).isAuthenticated, isFalse);
    expect(container.read(sessionControllerProvider).isLoading, isFalse);
  });

  testWidgets('retry restores a validated session and ignores an older response',
      (tester) async {
    final auth = _SlowAuth();
    final container = ProviderContainer(overrides: [
      sessionTokenStorageProvider.overrideWithValue(_MemoryTokens()),
      sessionAuthServiceProvider.overrideWithValue(auth),
    ]);
    addTearDown(container.dispose);
    container.read(sessionControllerProvider);
    await tester.pump();

    final retry = container.read(sessionControllerProvider.notifier).retryRestore();
    await tester.pump();
    auth.requests[1].complete({'uuid': 'new-user', 'user_type': 'STUDENT'});
    await tester.pump();
    await retry;
    expect(container.read(sessionControllerProvider).isAuthenticated, isTrue);
    expect(container.read(sessionControllerProvider).userUuid, 'new-user');

    auth.requests[0].complete({'uuid': 'old-user', 'user_type': 'STUDENT'});
    await tester.pump();
    expect(container.read(sessionControllerProvider).userUuid, 'new-user');
  });
}
