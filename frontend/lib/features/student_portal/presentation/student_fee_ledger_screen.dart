import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/user_role.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/pdf_download_helper.dart';
import '../data/student_fee_repository.dart';

class StudentFeeLedgerScreen extends ConsumerWidget {
  const StudentFeeLedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);

    if (session.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (session.role != UserRole.student ||
        !session.isAuthenticated) {
      return const Center(
        child: Text('Sign in as a student to view fees.'),
      );
    }

    return _Ledger(
      key: ValueKey('${session.userUuid}_${session.firmUuid}'),
    );
  }
}

class _Ledger extends ConsumerStatefulWidget {
  const _Ledger({super.key});

  @override
  ConsumerState<_Ledger> createState() => _LedgerState();
}

class _LedgerState extends ConsumerState<_Ledger> {
  late Future<StudentFeePage> result;
  int page = 1;
  final Set<String> downloading = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    result = ref.read(studentFeeRepositoryProvider).list(page: page);
  }

  void changePage(int next) {
    if (next < 1) return;

    setState(() {
      page = next;
      load();
    });
  }

  String text(dynamic value) => value?.toString().trim() ?? '';

  num _parseNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    final str = value.toString().replaceAll(RegExp(r'[^0-9.-]'), '');
    return num.tryParse(str) ?? 0;
  }

  String money(dynamic value) => formatInr(_parseNum(value));

  String date(dynamic value) =>
      text(value).isEmpty ? 'Not set' : text(value);

  Widget line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );

  Widget accountCard(Map<String, dynamic> account) {
    final payments = (account['installments'] as List?) ?? [];

    final net = _parseNum(account['total_amount']) -
        _parseNum(account['discount_amount']);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              text(account['course_name']),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(text(account['course_code'])),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(text(account['status'])),
              ),
            ),
            line('Total fee', money(account['total_amount'])),
            line('Discount', money(account['discount_amount'])),
            line('Net fee', formatInr(net)),
            line('Paid', money(account['paid_amount'])),
            line('Balance', money(account['balance_amount'])),
            line('Due date', date(account['due_date'])),
            const Divider(height: 28),
            Text(
              'Installment history',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (payments.isEmpty)
              const Text('No payments recorded yet.'),
            for (final raw in payments)
              paymentCard(
                Map<String, dynamic>.from(raw as Map),
                account,
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Payment receipt design
  // ---------------------------------------------------------------------------

  int receiptStatusHex(String status) {
    switch (status.toUpperCase()) {
      case 'RECORDED':
      case 'SUCCESS':
      case 'PAID':
        return 0xFF16803C;
      case 'VOIDED':
      case 'FAILED':
        return 0xFFC0262D;
      default:
        return 0xFFB45309;
    }
  }

  Color receiptStatusColor(String status) => Color(receiptStatusHex(status));

  String receiptStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'RECORDED':
        return 'Recorded';
      case 'VOIDED':
        return 'Voided';
      default:
        if (status.isEmpty) return 'Unknown';
        final clean = status.replaceAll('_', ' ').toLowerCase();
        return clean[0].toUpperCase() + clean.substring(1);
    }
  }

  IconData receiptMethodIcon(String method) {
    switch (method.toUpperCase()) {
      case 'CASH':
        return Icons.payments_outlined;
      case 'UPI':
        return Icons.qr_code_2_rounded;
      case 'CARD':
      case 'DEBIT_CARD':
      case 'CREDIT_CARD':
        return Icons.credit_card_rounded;
      case 'BANK_TRANSFER':
      case 'NEFT':
      case 'IMPS':
      case 'RTGS':
        return Icons.account_balance_outlined;
      case 'CHEQUE':
        return Icons.edit_note_rounded;
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }

  String receiptMethodLabel(String method) {
    switch (method.toUpperCase()) {
      case 'CASH':
        return 'Cash';
      case 'UPI':
        return 'UPI';
      case 'NEFT':
      case 'IMPS':
      case 'RTGS':
        return method.toUpperCase();
      default:
        if (method.isEmpty) return 'Not set';
        final clean = method.replaceAll('_', ' ').toLowerCase();
        return clean[0].toUpperCase() + clean.substring(1);
    }
  }

  Widget receiptRow(
    String label,
    String value, {
    IconData? icon,
    bool emphasize = false,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (icon != null) ...[
            Icon(icon, size: 16, color: scheme.primary),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: emphasize ? FontWeight.w600 : FontWeight.w500,
                color: scheme.onSurface,
                letterSpacing: emphasize ? 0.3 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Perforated tear line with half-circle notches on both edges,
  /// so each installment reads like a real paper receipt.
  Widget receiptTearLine(Color background, Color lineColor) {
    const notch = 10.0;

    return SizedBox(
      height: notch * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: notch + 6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const dash = 5.0;
                const gap = 4.0;
                final count =
                    (constraints.maxWidth / (dash + gap)).floor().clamp(1, 200);

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    count,
                    (_) => SizedBox(
                      width: dash,
                      height: 1.2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: lineColor),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: -notch,
            child: Container(
              width: notch * 2,
              height: notch * 2,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
                border: Border.all(color: lineColor),
              ),
            ),
          ),
          Positioned(
            right: -notch,
            child: Container(
              width: notch * 2,
              height: notch * 2,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
                border: Border.all(color: lineColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Receipt download (PDF)
  // ---------------------------------------------------------------------------

  String receiptKey(Map<String, dynamic> payment) {
    final id = text(payment['uuid']).isNotEmpty
        ? text(payment['uuid'])
        : text(payment['id']);
    if (id.isNotEmpty) return id;
    return '${text(payment['payment_date'])}_'
        '${text(payment['amount'])}_'
        '${text(payment['transaction_reference'])}';
  }

  String receiptFileName(
    Map<String, dynamic> payment,
    Map<String, dynamic> account,
  ) {
    final raw = 'receipt_${text(account['course_code'])}_'
        '${text(payment['payment_date'])}';
    return '${raw.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.pdf';
  }

  Future<void> downloadReceipt(
    Map<String, dynamic> payment,
    Map<String, dynamic> account,
  ) async {
    final key = receiptKey(payment);
    if (downloading.contains(key)) return;

    setState(() => downloading.add(key));

    try {
      final bytes = await buildReceiptPdf(payment, account);
      final filename = receiptFileName(payment, account);

      await triggerPdfDownload(bytes, filename);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt downloaded successfully'),
            backgroundColor: Color(0xFF16803C),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not download the receipt: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => downloading.remove(key));
      }
    }
  }

  Future<Uint8List> buildReceiptPdf(
    Map<String, dynamic> payment,
    Map<String, dynamic> account,
  ) async {
    pw.Font? regular;
    pw.Font? bold;
    try {
      regular = await PdfGoogleFonts.notoSansRegular().timeout(
        const Duration(seconds: 4),
      );
      bold = await PdfGoogleFonts.notoSansBold().timeout(
        const Duration(seconds: 4),
      );
    } catch (_) {
      regular = null;
      bold = null;
    }
    final hasRupeeFont = regular != null && bold != null;

    String pdfMoney(dynamic value) {
      final formatted = money(value);
      return hasRupeeFont ? formatted : formatted.replaceAll('₹', 'Rs. ');
    }

    String pdfInr(num value) {
      final formatted = formatInr(value);
      return hasRupeeFont ? formatted : formatted.replaceAll('₹', 'Rs. ');
    }

    final status = text(payment['status']);
    final isVoided = status.toUpperCase() == 'VOIDED';
    final statusColor = PdfColor.fromInt(receiptStatusHex(status));
    const accent = PdfColor.fromInt(0xFF4338CA);
    const muted = PdfColor.fromInt(0xFF6B7280);
    const border = PdfColor.fromInt(0xFFE5E7EB);
    const soft = PdfColor.fromInt(0xFFF8F7FC);

    final reference = text(payment['transaction_reference']);
    final net = _parseNum(account['total_amount']) -
        _parseNum(account['discount_amount']);

    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final generatedOn = '${now.year}-${two(now.month)}-${two(now.day)} '
        '${two(now.hour)}:${two(now.minute)}';

    pw.Widget row(String label, String value, {bool strong = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text(
                  label,
                  style: const pw.TextStyle(fontSize: 10.5, color: muted),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Text(
                value,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: 10.5,
                  fontWeight: strong ? pw.FontWeight.bold : null,
                ),
              ),
            ],
          ),
        );

    pw.Widget section(String title, List<pw.Widget> children) => pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: border),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              ...children,
            ],
          ),
        );

    final doc = pw.Document(
      title: 'Payment receipt',
      theme: hasRupeeFont
          ? pw.ThemeData.withFont(base: regular, bold: bold)
          : null,
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(height: 5, color: statusColor),
            pw.SizedBox(height: 18),

            // Header
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Payment receipt',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: accent,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Payment date: ${date(payment['payment_date'])}',
                        style: const pw.TextStyle(fontSize: 10.5, color: muted),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: statusColor),
                    borderRadius: pw.BorderRadius.circular(12),
                  ),
                  child: pw.Text(
                    receiptStatusLabel(status),
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: statusColor,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Amount
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: soft,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    isVoided ? 'Amount (voided)' : 'Amount paid',
                    style: const pw.TextStyle(fontSize: 10.5, color: muted),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    pdfMoney(payment['amount']),
                    style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                      decoration:
                          isVoided ? pw.TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            section('Course', [
              row('Course name', text(account['course_name']), strong: true),
              row('Course code', text(account['course_code'])),
            ]),
            pw.SizedBox(height: 12),

            section('Payment details', [
              row('Payment date', date(payment['payment_date'])),
              row(
                'Payment method',
                receiptMethodLabel(text(payment['payment_method'])),
              ),
              if (reference.isNotEmpty)
                row('Transaction ref.', reference, strong: true),
              row('Status', receiptStatusLabel(status)),
            ]),
            pw.SizedBox(height: 12),

            section('Fee summary', [
              row('Total fee', pdfMoney(account['total_amount'])),
              row('Discount', pdfMoney(account['discount_amount'])),
              row('Net fee', pdfInr(net)),
              row('Paid', pdfMoney(account['paid_amount'])),
              row(
                'Balance',
                pdfMoney(account['balance_amount']),
                strong: true,
              ),
              row('Due date', date(account['due_date'])),
            ]),

            if (isVoided) ...[
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: statusColor),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  'This payment was voided and does not count toward paid fees.',
                  style: pw.TextStyle(fontSize: 10.5, color: statusColor),
                ),
              ),
            ],

            pw.Spacer(),
            pw.Divider(color: border),
            pw.SizedBox(height: 6),
            pw.Text(
              'This is a computer-generated receipt and does not need a signature.',
              style: const pw.TextStyle(fontSize: 9, color: muted),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Generated on $generatedOn',
              style: const pw.TextStyle(fontSize: 9, color: muted),
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  Widget paymentCard(
    Map<String, dynamic> payment,
    Map<String, dynamic> account,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final status = text(payment['status']);
    final isVoided = status.toUpperCase() == 'VOIDED';
    final statusColor = receiptStatusColor(status);
    final method = text(payment['payment_method']);
    final reference = text(payment['transaction_reference']);
    final isDownloading = downloading.contains(receiptKey(payment));

    final borderColor = scheme.outlineVariant;
    final cardColor = scheme.surface;
    final pageColor = Theme.of(context).cardColor;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Accent strip — colour follows the payment status
            Container(height: 4, color: statusColor),

            // Header: receipt identity + status
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: scheme.primary.withAlpha(22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment receipt',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          date(payment['payment_date']),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(24),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isVoided
                              ? Icons.block_rounded
                              : Icons.check_circle_rounded,
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          receiptStatusLabel(status),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Amount — the hero of the receipt
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isVoided ? 'Amount (voided)' : 'Amount paid',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    money(payment['amount']),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isVoided
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                      decoration:
                          isVoided ? TextDecoration.lineThrough : null,
                      decorationColor: statusColor,
                      decorationThickness: 2,
                    ),
                  ),
                ],
              ),
            ),

            receiptTearLine(pageColor, borderColor),

            // Details
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  receiptRow('Payment date', date(payment['payment_date'])),
                  receiptRow(
                    'Payment method',
                    receiptMethodLabel(method),
                    icon: receiptMethodIcon(method),
                  ),
                  if (reference.isNotEmpty)
                    receiptRow(
                      'Transaction ref.',
                      reference,
                      emphasize: true,
                    ),
                ],
              ),
            ),

            if (isVoided)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: statusColor.withAlpha(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: statusColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This payment was voided and does not count toward paid fees.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Download receipt button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: OutlinedButton.icon(
                onPressed: isDownloading
                    ? null
                    : () => downloadReceipt(payment, account),
                icon: isDownloading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.primary,
                        ),
                      )
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(
                  isDownloading ? 'Preparing receipt…' : 'Download receipt',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: scheme.primary,
                  side: BorderSide(color: scheme.primary.withAlpha(90)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Payments recorded by your academy appear here.',
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => changePage(1),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 18),
        FutureBuilder<StudentFeePage>(
          future: result,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              final error = snapshot.error;

              return Column(
                children: [
                  Text(
                    error is ApiException
                        ? error.message
                        : 'Could not load fees. Please try again.',
                  ),
                  TextButton(
                    onPressed: () => setState(load),
                    child: const Text('Retry'),
                  ),
                  if (page > 1)
                    TextButton(
                      onPressed: () => changePage(page - 1),
                      child: const Text('Previous page'),
                    ),
                ],
              );
            }

            final data = snapshot.data!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${data.count} fee accounts'),
                const SizedBox(height: 12),
                if (data.accounts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No fee accounts on this page.'),
                  ),
                for (final account in data.accounts)
                  accountCard(account),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: page > 1
                          ? () => changePage(page - 1)
                          : null,
                      child: const Text('Previous'),
                    ),
                    Text('Page $page'),
                    TextButton(
                      onPressed: data.hasNext
                          ? () => changePage(page + 1)
                          : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
