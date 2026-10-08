import 'dart:typed_data';
import 'package:printing/printing.dart';

Future<void> savePdfFile(Uint8List bytes, String filename) async {
  try {
    await Printing.sharePdf(
      bytes: bytes,
      filename: filename,
    );
  } catch (_) {
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: filename,
    );
  }
}
