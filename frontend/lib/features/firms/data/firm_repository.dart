import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import 'firm_model.dart';
import 'firm_service.dart';

/// Provides the FirmService wired with the shared Dio instance.
final firmServiceProvider = Provider<FirmService>((ref) {
  final dio = ref.watch(dioProvider);
  return FirmService(dio);
});

/// GET /firms/ — list of all firms.
final firmsListProvider = FutureProvider<List<Firm>>((ref) async {
  final service = ref.watch(firmServiceProvider);
  final response = await service.listFirms();
  return response.data;
});

/// GET /firms/{uuid}/ — single firm detail.
final firmDetailProvider =
FutureProvider.family<Firm, String>((ref, uuid) async {
  final service = ref.watch(firmServiceProvider);
  final response = await service.getFirm(uuid);
  return response.data;
});

/// Repository façade — used by screens for mutations / imperatively.
class FirmRepository {
  FirmRepository(this._service);
  final FirmService _service;

  Future<List<Firm>> list() async => (await _service.listFirms()).data;

  Future<Firm> detail(String uuid) async => (await _service.getFirm(uuid)).data;

  Future<Firm> create(FirmCreateRequest request) async =>
      (await _service.createFirm(request)).data;

  /// PATCH /firms/{uuid}/ — partial update.
  Future<Firm> update(String uuid, FirmUpdateRequest request) async =>
      (await _service.patchFirm(uuid, request)).data;

  /// PATCH /firms/{uuid}/activate/
  Future<FirmStatusResponse> activate(String uuid) =>
      _service.activateFirm(uuid);

  /// PATCH /firms/{uuid}/deactivate/
  Future<FirmStatusResponse> deactivate(String uuid) =>
      _service.deactivateFirm(uuid);


}

final firmRepositoryProvider = Provider<FirmRepository>((ref) {
  return FirmRepository(ref.watch(firmServiceProvider));
});