/// Mirrors app.schemas.academy.AcademyKPIs on the backend.
class AcademyKpis {
  const AcademyKpis({
    required this.academyId,
    required this.academyName,
    required this.totalStudents,
    required this.activeBatches,
    required this.revenueCollected,
    required this.revenuePending,
    required this.feeRealizationPct,
    required this.attendancePct,
  });

  final int academyId;
  final String academyName;
  final int totalStudents;
  final int activeBatches;
  final double revenueCollected;
  final double revenuePending;
  final double feeRealizationPct;
  final double attendancePct;

  factory AcademyKpis.fromJson(Map<String, dynamic> json) {
    return AcademyKpis(
      academyId: json['academy_id'] as int,
      academyName: json['academy_name'] as String,
      totalStudents: json['total_students'] as int,
      activeBatches: json['active_batches'] as int,
      revenueCollected: (json['revenue_collected'] as num).toDouble(),
      revenuePending: (json['revenue_pending'] as num).toDouble(),
      feeRealizationPct: (json['fee_realization_pct'] as num).toDouble(),
      attendancePct: (json['attendance_pct'] as num).toDouble(),
    );
  }
}
