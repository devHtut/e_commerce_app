// ignore_for_file: deprecated_member_use

import 'dart:typed_data';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class ReceiptSaveResult {
  final bool savedToGallery;
  final String message;

  const ReceiptSaveResult({
    required this.savedToGallery,
    required this.message,
  });
}

Future<ReceiptSaveResult> saveReceiptImage(
  Uint8List bytes,
  String fileName,
) async {
  final blob = html.Blob(<Object>[bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none'
      ..click();
  } finally {
    html.Url.revokeObjectUrl(url);
  }

  return const ReceiptSaveResult(
    savedToGallery: false,
    message: 'Receipt image downloaded.',
  );
}
