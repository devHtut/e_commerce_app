import 'dart:typed_data';

import 'package:image/image.dart' as img;

class OptimizedImageUpload {
  final String name;
  final String extension;
  final String contentType;
  final Uint8List bytes;

  const OptimizedImageUpload({
    required this.name,
    required this.extension,
    required this.contentType,
    required this.bytes,
  });
}

Future<OptimizedImageUpload> optimizeImageForUpload({
  required Uint8List bytes,
  required String originalName,
  int maxDimension = 1600,
  int jpegQuality = 78,
}) async {
  final optimized = await Future<Uint8List?>(() {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final oriented = img.bakeOrientation(decoded);

      final longestSide = oriented.width > oriented.height
          ? oriented.width
          : oriented.height;
      final resized = longestSide > maxDimension
          ? img.copyResize(
              oriented,
              width: oriented.width >= oriented.height ? maxDimension : null,
              height: oriented.height > oriented.width ? maxDimension : null,
              interpolation: img.Interpolation.average,
            )
          : oriented;

      return Uint8List.fromList(img.encodeJpg(resized, quality: jpegQuality));
    } catch (_) {
      return null;
    }
  });

  if (optimized == null || optimized.length >= bytes.length) {
    final extension = _extensionFromName(originalName);
    return OptimizedImageUpload(
      name: originalName,
      extension: extension,
      contentType: _contentTypeForExtension(extension),
      bytes: bytes,
    );
  }

  return OptimizedImageUpload(
    name: _withJpgExtension(originalName),
    extension: 'jpg',
    contentType: 'image/jpeg',
    bytes: optimized,
  );
}

String _extensionFromName(String name) {
  final dotIndex = name.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex == name.length - 1) return '';
  return name.substring(dotIndex + 1).toLowerCase();
}

String _contentTypeForExtension(String extension) {
  return switch (extension) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'bmp' => 'image/bmp',
    _ => 'application/octet-stream',
  };
}

String _withJpgExtension(String name) {
  final dotIndex = name.lastIndexOf('.');
  final baseName = dotIndex > 0 ? name.substring(0, dotIndex) : name;
  return '$baseName.jpg';
}
