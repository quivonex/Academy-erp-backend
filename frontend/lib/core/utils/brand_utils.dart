/// Utility functions for brand and organization display names.

String cleanFirmName(String? raw) {
  if (raw == null) return 'THE ROLEX ACADEMY';
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return 'THE ROLEX ACADEMY';
  final lower = trimmed.toLowerCase();
  if (lower.contains('vidya') ||
      lower.contains('setu') ||
      lower.contains('edusphere') ||
      lower == 'academy' ||
      lower == 'the academy' ||
      lower == 'your academy') {
    return 'THE ROLEX ACADEMY';
  }
  return trimmed;
}
