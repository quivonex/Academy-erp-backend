import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_urls.dart';
import '../../../core/network/dio_provider.dart';

class StudentFeePage {
  const StudentFeePage({
    required this.count,
    required this.accounts,
    required this.hasNext,
  });

  final int count;
  final List<Map<String, dynamic>> accounts;
  final bool hasNext;
}

class StudentFeeRepository {
  StudentFeeRepository(this.dio);

  final Dio dio;

  Future<StudentFeePage> list({int page = 1}) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        ApiUrls.studentFeeAccounts,
        queryParameters: {
          'page': page,
          'page_size': 20,
        },
      );

      final body = response.data;

      if (body == null ||
          body['success'] != true ||
          body['data'] is! Map) {
        throw const FormatException('Invalid fee ledger response.');
      }

      final data = Map<String, dynamic>.from(body['data'] as Map);
      final count = data['count'];
      final rows = data['results'];

      if (count is! int || count < 0 || rows is! List) {
        throw const FormatException('Invalid fee ledger page.');
      }

      final accounts = rows.map((raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid fee account.');
        }

        final account = Map<String, dynamic>.from(raw);

        for (final key in [
          'total_amount',
          'discount_amount',
          'paid_amount',
          'balance_amount',
        ]) {
          final amount = num.tryParse(
            account[key]?.toString() ?? '',
          );

          if (amount == null || !amount.isFinite) {
            throw const FormatException('Invalid fee amount.');
          }
        }

        if (account['installments'] is! List) {
          throw const FormatException(
            'Installment history is missing.',
          );
        }

        for (final rawPayment in account['installments'] as List) {
          if (rawPayment is! Map) {
            throw const FormatException('Invalid installment.');
          }

          final amount = num.tryParse(
            rawPayment['amount']?.toString() ?? '',
          );

          if (amount == null || !amount.isFinite) {
            throw const FormatException(
              'Invalid installment amount.',
            );
          }
        }

        return account;
      }).toList();

      return StudentFeePage(
        count: count,
        accounts: accounts,
        hasNext: data['next'] != null,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final studentFeeRepositoryProvider = Provider<StudentFeeRepository>(
  (ref) => StudentFeeRepository(ref.watch(dioProvider)),
);
