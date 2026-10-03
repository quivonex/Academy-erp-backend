library;

/// Models for the fee-account + installment flow
/// (backend: payments.EnrollmentFeeAccount / payments.InstallmentPayment).
///
/// DRF serialises DecimalField values as strings ("1500.00"), so every
/// amount goes through [_money].

class FeeAccountStatus {
  FeeAccountStatus._();

  static const unpaid = 'UNPAID';
  static const partiallyPaid = 'PARTIALLY_PAID';
  static const paid = 'PAID';

  static String label(String status) => switch (status.toUpperCase()) {
        unpaid => 'Unpaid',
        partiallyPaid => 'Partially paid',
        paid => 'Paid',
        _ => status,
      };
}

class InstallmentStatus {
  InstallmentStatus._();

  static const recorded = 'RECORDED';
  static const voided = 'VOIDED';
}

class PaymentMethod {
  PaymentMethod._();

  /// Mirrors InstallmentPayment.PaymentMethod choices on the backend.
  static const values = <String, String>{
    'CASH': 'Cash',
    'UPI': 'UPI',
    'BANK_TRANSFER': 'Bank transfer',
    'CARD': 'Card',
    'OTHER': 'Other',
  };

  static String label(String value) => values[value.toUpperCase()] ?? value;

  /// Methods where a transaction reference is normally available.
  static bool expectsReference(String value) =>
      value == 'UPI' || value == 'BANK_TRANSFER' || value == 'CARD';
}

class FeeAccount {
  const FeeAccount({
    required this.uuid,
    required this.enrollmentUuid,
    required this.studentUuid,
    required this.studentName,
    required this.admissionNumber,
    required this.courseUuid,
    required this.courseName,
    required this.courseCode,
    required this.totalAmount,
    required this.discountAmount,
    required this.paidAmount,
    required this.balanceAmount,
    required this.status,
    required this.notes,
    this.dueDate,
    this.createdByName,
    this.createdAt,
    this.updatedAt,
  });

  final String uuid;
  final String enrollmentUuid;
  final String studentUuid;
  final String studentName;
  final String admissionNumber;
  final String courseUuid;
  final String courseName;
  final String courseCode;

  final double totalAmount;
  final double discountAmount;
  final double paidAmount;
  final double balanceAmount;

  final String status;
  final String notes;
  final DateTime? dueDate;
  final String? createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Amount the student actually owes after discount.
  double get netPayable => totalAmount - discountAmount;

  /// 0.0 – 1.0, used for the progress bar.
  double get paidFraction {
    if (netPayable <= 0) return 1;
    return (paidAmount / netPayable).clamp(0, 1).toDouble();
  }

  bool get isPaid => status.toUpperCase() == FeeAccountStatus.paid;

  bool get isOverdue {
    final due = dueDate;
    if (due == null || isPaid || balanceAmount <= 0) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return due.isBefore(today);
  }

  factory FeeAccount.fromJson(Map<String, dynamic> json) {
    return FeeAccount(
      uuid: json['uuid']?.toString() ?? '',
      enrollmentUuid: json['enrollment_uuid']?.toString() ?? '',
      studentUuid: json['student_uuid']?.toString() ?? '',
      studentName: _text(json['student_name'], fallback: 'Student'),
      admissionNumber: json['admission_number']?.toString() ?? '',
      courseUuid: json['course_uuid']?.toString() ?? '',
      courseName: _text(json['course_name'], fallback: 'Course'),
      courseCode: json['course_code']?.toString() ?? '',
      totalAmount: _money(json['total_amount']),
      discountAmount: _money(json['discount_amount']),
      paidAmount: _money(json['paid_amount']),
      balanceAmount: _money(json['balance_amount']),
      status: json['status']?.toString() ?? FeeAccountStatus.unpaid,
      notes: json['notes']?.toString() ?? '',
      dueDate: _date(json['due_date']),
      createdByName: json['created_by_name']?.toString(),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

class Installment {
  const Installment({
    required this.uuid,
    required this.feeAccountUuid,
    required this.studentName,
    required this.admissionNumber,
    required this.courseName,
    required this.amount,
    required this.paymentMethod,
    required this.transactionReference,
    required this.notes,
    required this.status,
    this.paymentDate,
    this.recordedByName,
    this.voidedByName,
    this.voidedAt,
    this.voidReason,
    this.createdAt,
  });

  final String uuid;
  final String feeAccountUuid;
  final String studentName;
  final String admissionNumber;
  final String courseName;
  final double amount;
  final String paymentMethod;
  final String transactionReference;
  final String notes;
  final String status;
  final DateTime? paymentDate;
  final String? recordedByName;
  final String? voidedByName;
  final DateTime? voidedAt;
  final String? voidReason;
  final DateTime? createdAt;

  bool get isVoided => status.toUpperCase() == InstallmentStatus.voided;

  factory Installment.fromJson(Map<String, dynamic> json) {
    return Installment(
      uuid: json['uuid']?.toString() ?? '',
      feeAccountUuid: json['fee_account_uuid']?.toString() ?? '',
      studentName: _text(json['student_name'], fallback: 'Student'),
      admissionNumber: json['admission_number']?.toString() ?? '',
      courseName: _text(json['course_name'], fallback: 'Course'),
      amount: _money(json['amount']),
      paymentMethod: json['payment_method']?.toString() ?? '',
      transactionReference: json['transaction_reference']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      status: json['status']?.toString() ?? InstallmentStatus.recorded,
      paymentDate: _date(json['payment_date']),
      recordedByName: json['recorded_by_name']?.toString(),
      voidedByName: json['voided_by_name']?.toString(),
      voidedAt: _date(json['voided_at']),
      voidReason: json['void_reason']?.toString(),
      createdAt: _date(json['created_at']),
    );
  }
}

/// Returned by "record installment" and "void installment": both send back
/// the changed installment plus the recalculated fee account.
class InstallmentChange {
  const InstallmentChange({
    required this.installment,
    required this.feeAccount,
  });

  final Installment installment;
  final FeeAccount feeAccount;

  factory InstallmentChange.fromJson(Map<String, dynamic> json) {
    return InstallmentChange(
      installment: Installment.fromJson(
        Map<String, dynamic>.from(json['installment'] as Map? ?? {}),
      ),
      feeAccount: FeeAccount.fromJson(
        Map<String, dynamic>.from(json['fee_account'] as Map? ?? {}),
      ),
    );
  }
}

/// Generic page wrapper for the backend's
/// `{success, message, data: {count, next, previous, results}}` envelope.
class Paged<T> {
  const Paged({required this.count, required this.results});

  final int count;
  final List<T> results;

  factory Paged.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final list = data['results'] is List
        ? data['results'] as List
        : (json['results'] is List ? json['results'] as List : const []);
    final count = (data['count'] as num?)?.toInt() ?? list.length;

    return Paged(
      count: count,
      results: list
          .map((e) => itemFromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

double _money(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

DateTime? _date(dynamic value) {
  if (value == null || value.toString().isEmpty) return null;
  return DateTime.tryParse(value.toString());
}

String _text(dynamic value, {required String fallback}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

/// `2026-10-03` — format the backend's DateField expects.
String apiDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

/// Decimal string the backend's DecimalField expects ("1500.00").
String apiAmount(double value) => value.toStringAsFixed(2);
