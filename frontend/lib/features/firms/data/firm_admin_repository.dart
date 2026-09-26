import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import 'firm_admin_model.dart';
import 'firm_admin_service.dart';

final firmAdminServiceProvider = Provider<FirmAdminService>((ref) {
  final dio = ref.watch(dioProvider);
  return FirmAdminService(dio);
});

/// GET /firms/{uuid}/admins/ — admins for one firm.
final firmAdminsForFirmProvider =
FutureProvider.family<List<FirmAdmin>, String>((ref, firmUuid) async {
  final service = ref.watch(firmAdminServiceProvider);
  return (await service.listForFirm(firmUuid)).data;
});

/// GET /firms/firm-admins/ — every admin across every firm.
final allFirmAdminsProvider = FutureProvider<List<FirmAdmin>>((ref) async {
  final service = ref.watch(firmAdminServiceProvider);
  return (await service.listAll()).data;
});

/// Imperative façade for mutations.
class FirmAdminRepository {
  FirmAdminRepository(this._service);
  final FirmAdminService _service;

  Future<List<FirmAdmin>> listForFirm(String firmUuid) async =>
      (await _service.listForFirm(firmUuid)).data;

  Future<List<FirmAdmin>> listAll() async => (await _service.listAll()).data;

  Future<FirmAdmin> create(String firmUuid, FirmAdminCreateRequest request) async =>
      (await _service.create(firmUuid, request)).data;
}

final firmAdminRepositoryProvider = Provider<FirmAdminRepository>((ref) {
  return FirmAdminRepository(ref.watch(firmAdminServiceProvider));
});