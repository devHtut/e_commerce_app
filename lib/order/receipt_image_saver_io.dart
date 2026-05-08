import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

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
  if (_supportsGallerySave) {
    await Gal.putImageBytes(bytes, name: fileName);
    return const ReceiptSaveResult(
      savedToGallery: true,
      message: 'Receipt saved to gallery.',
    );
  }

  final base = await getApplicationDocumentsDirectory();
  final folder = Directory('${base.path}${Platform.pathSeparator}receipts');
  if (!await folder.exists()) {
    await folder.create(recursive: true);
  }
  final file = File('${folder.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return ReceiptSaveResult(
    savedToGallery: false,
    message: 'Receipt saved:\n${file.path}',
  );
}

bool get _supportsGallerySave {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows;
}
