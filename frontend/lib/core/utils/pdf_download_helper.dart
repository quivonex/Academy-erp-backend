import 'dart:typed_data';

import 'pdf_download_stub.dart'
    if (dart.library.html) 'pdf_download_web.dart';

Future<void> triggerPdfDownload(Uint8List bytes, String filename) =>
    savePdfFile(bytes, filename);
