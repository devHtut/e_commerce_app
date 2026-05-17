import 'package:supabase_flutter/supabase_flutter.dart';

enum ReportTargetType { product, chat }

class ReportService {
  ReportService._();

  static final ReportService instance = ReportService._();

  final SupabaseClient _client = Supabase.instance.client;

  Future<void> reportProduct({
    required String productId,
    required String reason,
    String? details,
  }) {
    return _createReport(
      targetType: ReportTargetType.product,
      targetId: productId,
      reason: reason,
      details: details,
    );
  }

  Future<void> reportChat({
    required String chatId,
    required String reason,
    String? details,
  }) {
    return _createReport(
      targetType: ReportTargetType.chat,
      targetId: chatId,
      reason: reason,
      details: details,
    );
  }

  Future<void> _createReport({
    required ReportTargetType targetType,
    required String targetId,
    required String reason,
    String? details,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Please sign in to submit a report.');
    }

    final trimmedDetails = details?.trim();
    await _client.from('reports').insert({
      'reporter_id': userId,
      'report_type': targetType.name,
      if (targetType == ReportTargetType.product) 'product_id': targetId,
      if (targetType == ReportTargetType.chat) 'chat_id': targetId,
      'reason': reason,
      'details': trimmedDetails?.isEmpty == true ? null : trimmedDetails,
    });
  }
}
