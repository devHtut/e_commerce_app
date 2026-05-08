import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme_config.dart';
import 'order_receipt_content.dart';
import 'order_receipt_generator.dart';
import 'order_service.dart';
import 'receipt_image_saver.dart';

class ReceiptScreen extends StatefulWidget {
  final OrderModel order;

  const ReceiptScreen({super.key, required this.order});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _saving = false;
  bool _precacheStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precacheStarted) return;
    _precacheStarted = true;
    OrderReceiptGenerator.precacheImages(context, widget.order);
  }

  Future<void> _saveImage() async {
    setState(() => _saving = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final bytes = await _captureReceipt();
      if (!mounted) return;
      if (bytes == null || bytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create receipt image.')),
        );
        return;
      }

      final result = await saveReceiptImage(
        bytes,
        _receiptFileName(widget.order.readableId),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Receipt save error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<Uint8List?> _captureReceipt() async {
    final boundary =
        _receiptKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  String _receiptFileName(String readableId) {
    final safeId = readableId.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final suffix = safeId.isEmpty
        ? DateTime.now().millisecondsSinceEpoch.toString()
        : safeId;
    return 'receipt_$suffix.png';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.darkText),
        centerTitle: true,
        title: const Text(
          'Receipt',
          style: TextStyle(
            color: AppColors.darkText,
            fontFamily: AppFonts.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: RepaintBoundary(
                      key: _receiptKey,
                      child: OrderReceiptContent(order: widget.order),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveImage,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_alt),
                label: Text(_saving ? 'Saving...' : 'Save Image'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
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
}
