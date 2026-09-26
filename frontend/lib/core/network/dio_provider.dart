import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/session_controller.dart';
import 'dio_client.dart';

/// The single Dio instance every repository should depend on. It reads the
/// bearer token straight from [sessionControllerProvider],
/// so repositories never need to know about auth at all.
final dioProvider = Provider<Dio>((ref) {
  final session = ref.watch(sessionControllerProvider.notifier);

  return buildDio(
    tokenStorage: session.tokenStorage,
    refreshToken: session.refreshAccessToken,
    onUnauthenticated: session.forceLogout,
  );
});