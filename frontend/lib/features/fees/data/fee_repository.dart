import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_urls.dart';
import '../../../core/network/dio_provider.dart';
import 'fee_models.dart';

/// Admin / staff side of the fee flow:
///   GET/POST  /payments/fee-accounts/
///   GET/POST  /payments/installments/
///   PATCH     /payments/installments/{uuid}/void/
class FeeRepository {
  FeeRepository(this._dio);

  final Dio _dio;

  static const pageSize = 20;

  Future<T> _request<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Map<String, dynamic> _data(Response<Map<String, dynamic>> response) {
    final body = response.data ?? const {};
    final data = body['data'] ?? body;
    return Map<String, dynamic>.from(data as Map);
  }

  // ───────────────────────── Fee accounts ─────────────────────────

  Future<Paged<FeeAccount>> feeAccounts({
    int page = 1,
    int size = pageSize,
    String? status,
    String? studentUuid,
    String? enrollmentUuid,
  }) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.feeAccounts,
          queryParameters: {
            'page': page,
            'page_size': size,
            if (status != null && status.isNotEmpty) 'status': status,
            if (studentUuid != null && studentUuid.isNotEmpty)
              'student_uuid': studentUuid,
            if (enrollmentUuid != null && enrollmentUuid.isNotEmpty)
              'enrollment_uuid': enrollmentUuid,
          },
        );
        return Paged.fromJson(response.data ?? {}, FeeAccount.fromJson);
      });

  /// The backend has no fee-account detail endpoint. An enrollment has at
  /// most one fee account, so we look it up by enrollment.
  Future<FeeAccount?> feeAccountForEnrollment(String enrollmentUuid) async {
    final page = await feeAccounts(enrollmentUuid: enrollmentUuid, size: 1);
    return page.results.isEmpty ? null : page.results.first;
  }

  /// Loads every fee account (all pages). Used to hide enrollments that
  /// already have one in the "create fee account" picker.
  Future<List<FeeAccount>> allFeeAccounts() async {
    final all = <FeeAccount>[];
    var page = 1;
    while (true) {
      final result = await feeAccounts(page: page, size: 100);
      all.addAll(result.results);
      if (result.results.isEmpty || all.length >= result.count) break;
      page++;
    }
    return all;
  }

  Future<FeeAccount> createFeeAccount({
    required String enrollmentUuid,
    required double totalAmount,
    double discountAmount = 0,
    DateTime? dueDate,
    String notes = '',
  }) =>
      _request(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          ApiUrls.feeAccounts,
          data: {
            'enrollment_uuid': enrollmentUuid,
            'total_amount': apiAmount(totalAmount),
            'discount_amount': apiAmount(discountAmount),
            'due_date': dueDate == null ? null : apiDate(dueDate),
            if (notes.trim().isNotEmpty) 'notes': notes.trim(),
          },
        );
        return FeeAccount.fromJson(_data(response));
      });

  // ───────────────────────── Installments ─────────────────────────

  Future<Paged<Installment>> installments({
    int page = 1,
    String? feeAccountUuid,
    String? status,
  }) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiUrls.installments,
          queryParameters: {
            'page': page,
            'page_size': pageSize,
            if (feeAccountUuid != null && feeAccountUuid.isNotEmpty)
              'fee_account_uuid': feeAccountUuid,
            if (status != null && status.isNotEmpty) 'status': status,
          },
        );
        return Paged.fromJson(response.data ?? {}, Installment.fromJson);
      });

  Future<InstallmentChange> recordInstallment({
    required String feeAccountUuid,
    required double amount,
    required String paymentMethod,
    String transactionReference = '',
    DateTime? paymentDate,
    String notes = '',
  }) =>
      _request(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          ApiUrls.installments,
          data: {
            'fee_account_uuid': feeAccountUuid,
            'amount': apiAmount(amount),
            'payment_method': paymentMethod,
            if (transactionReference.trim().isNotEmpty)
              'transaction_reference': transactionReference.trim(),
            if (paymentDate != null) 'payment_date': apiDate(paymentDate),
            if (notes.trim().isNotEmpty) 'notes': notes.trim(),
          },
        );
        return InstallmentChange.fromJson(_data(response));
      });

  Future<InstallmentChange> voidInstallment({
    required String installmentUuid,
    required String reason,
  }) =>
      _request(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          ApiUrls.installmentVoid(installmentUuid),
          data: {'void_reason': reason.trim()},
        );
        return InstallmentChange.fromJson(_data(response));
      });
}

final feeRepositoryProvider = Provider<FeeRepository>((ref) {
  return FeeRepository(ref.watch(dioProvider));
});
