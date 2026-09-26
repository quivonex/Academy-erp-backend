/// Lightweight Course/Batch models for the wizard's step 5/6 pickers.
/// Mirrors app.schemas.academic.CourseOut / BatchOut.
class CourseOption {
  const CourseOption({required this.id, required this.name, this.category, this.subcategory});
  final int id;
  final String name;
  final String? category;
  final String? subcategory;

  factory CourseOption.fromJson(Map<String, dynamic> json) => CourseOption(
        id: json['id'] as int,
        name: json['name'] as String,
        category: json['category'] as String?,
        subcategory: json['subcategory'] as String?,
      );
}

class BatchOption {
  const BatchOption({required this.id, required this.courseId, required this.name, this.room});
  final int id;
  final int courseId;
  final String name;
  final String? room;

  factory BatchOption.fromJson(Map<String, dynamic> json) => BatchOption(
        id: json['id'] as int,
        courseId: json['course_id'] as int,
        name: json['name'] as String,
        room: json['room'] as String?,
      );
}

/// Mirrors app.schemas.student.EnrollmentOut.
class EnrollmentRecord {
  const EnrollmentRecord({
    required this.id,
    required this.academyId,
    required this.studentId,
    this.courseId,
    this.batchId,
    required this.stage,
    required this.status,
  });

  final int id;
  final int academyId;
  final int studentId;
  final int? courseId;
  final int? batchId;
  final int stage;
  final String status;

  factory EnrollmentRecord.fromJson(Map<String, dynamic> json) => EnrollmentRecord(
        id: json['id'] as int,
        academyId: json['academy_id'] as int,
        studentId: json['student_id'] as int,
        courseId: json['course_id'] as int?,
        batchId: json['batch_id'] as int?,
        stage: json['stage'] as int,
        status: json['status'] as String,
      );
}

/// One fee line item the admin adds in Stage 7, e.g. "Base Course Tuition Fee".
class FeeComponentDraft {
  FeeComponentDraft({required this.label, required this.amount, this.description});
  String label;
  double amount;
  String? description;

  Map<String, dynamic> toJson() => {
        'label': label,
        'amount': amount,
        if (description != null) 'description': description,
      };
}

/// Mirrors app.schemas.fees.FeePlanOut.
class FeePlanRecord {
  const FeePlanRecord({
    required this.id,
    required this.grossSubtotal,
    required this.scholarshipAmount,
    required this.netPayable,
  });

  final int id;
  final double grossSubtotal;
  final double scholarshipAmount;
  final double netPayable;

  factory FeePlanRecord.fromJson(Map<String, dynamic> json) => FeePlanRecord(
        id: json['id'] as int,
        grossSubtotal: (json['gross_subtotal'] as num).toDouble(),
        scholarshipAmount: (json['scholarship_amount'] as num).toDouble(),
        netPayable: (json['net_payable'] as num).toDouble(),
      );
}

/// Mirrors app.schemas.fees.InstallmentOut.
class InstallmentRecord {
  const InstallmentRecord({
    required this.id,
    required this.trancheNo,
    required this.dueDate,
    this.milestoneGate,
    required this.amount,
    required this.status,
  });

  final int id;
  final int trancheNo;
  final DateTime dueDate;
  final String? milestoneGate;
  final double amount;
  final String status;

  factory InstallmentRecord.fromJson(Map<String, dynamic> json) => InstallmentRecord(
        id: json['id'] as int,
        trancheNo: json['tranche_no'] as int,
        dueDate: DateTime.parse(json['due_date'] as String),
        milestoneGate: json['milestone_gate'] as String?,
        amount: (json['amount'] as num).toDouble(),
        status: json['status'] as String,
      );
}

/// Mirrors app.schemas.fees.InstallmentPlanOut.
class InstallmentPlanRecord {
  const InstallmentPlanRecord({
    required this.id,
    required this.frequency,
    required this.installments,
  });

  final int id;
  final String frequency;
  final List<InstallmentRecord> installments;

  factory InstallmentPlanRecord.fromJson(Map<String, dynamic> json) => InstallmentPlanRecord(
        id: json['id'] as int,
        frequency: json['frequency'] as String,
        installments: (json['installments'] as List)
            .map((e) => InstallmentRecord.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Mirrors app.schemas.fees.PaymentOut.
class PaymentRecord {
  const PaymentRecord({required this.id, required this.receiptNo, required this.amountPaid});
  final int id;
  final String receiptNo;
  final double amountPaid;

  factory PaymentRecord.fromJson(Map<String, dynamic> json) => PaymentRecord(
        id: json['id'] as int,
        receiptNo: json['receipt_no'] as String,
        amountPaid: (json['amount_paid'] as num).toDouble(),
      );
}
