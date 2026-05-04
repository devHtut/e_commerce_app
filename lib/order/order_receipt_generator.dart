import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

import 'order_receipt_content.dart';
import 'order_service.dart';

class OrderReceiptGenerator {
  OrderReceiptGenerator._();

  static Future<void> precacheImages(BuildContext context, OrderModel order) async {
    final urls = <String>{};
    if (order.items.isNotEmpty) {
      final logo = order.items.first.product.brandLogoUrl;
      if (logo != null && logo.isNotEmpty) urls.add(logo);
    }
    for (final item in order.items) {
      if (item.imageUrl.isNotEmpty) urls.add(item.imageUrl);
    }
    final shot = order.payment?.screenshotUrl;
    if (shot != null && shot.isNotEmpty) urls.add(shot);
    for (final url in urls) {
      try {
        await precacheImage(NetworkImage(url), context);
      } catch (_) {}
    }
  }

  static Future<Uint8List?> renderPng(BuildContext context, OrderModel order) async {
    final key = GlobalKey();
    final overlayState = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: -800,
        top: 0,
        child: Material(
          color: Colors.white,
          child: RepaintBoundary(
            key: key,
            child: OrderReceiptContent(order: order),
          ),
        ),
      ),
    );
    overlayState.insert(entry);
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 150));
    Uint8List? bytes;
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 3.0);
        final bd = await image.toByteData(format: ui.ImageByteFormat.png);
        bytes = bd?.buffer.asUint8List();
      }
    } finally {
      entry.remove();
    }
    return bytes;
  }

  static Future<File?> savePng(Uint8List bytes, String readableId) async {
    final base = await getApplicationDocumentsDirectory();
    final folder = Directory('${base.path}${Platform.pathSeparator}receipts');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final safe = readableId.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final name =
        'receipt_${safe.isEmpty ? DateTime.now().millisecondsSinceEpoch : safe}.png';
    final file = File('${folder.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
