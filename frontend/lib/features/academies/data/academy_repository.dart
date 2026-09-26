import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../dashboard/data/academy_kpis.dart';
import 'academy.dart';

class AcademyRepository {
  AcademyRepository(this._dio);
  final Dio _dio;

  Future<List<Academy>> list() async {
    try {
      final response = await _dio.get('/academies');
      return (response.data as List).map((e) => Academy.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Academy> create(AcademyCreateRequest request) async {
    try {
      final response = await _dio.post('/academies', data: request.toJson());
      return Academy.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<AcademyKpis> kpis(int academyId) async {
    try {
      final response = await _dio.get('/academies/$academyId/kpis');
      return AcademyKpis.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final academyRepositoryProvider = Provider<AcademyRepository>((ref) {
  return AcademyRepository(ref.watch(dioProvider));
});

final academiesListProvider = FutureProvider<List<Academy>>((ref) {
  return ref.watch(academyRepositoryProvider).list();
});
