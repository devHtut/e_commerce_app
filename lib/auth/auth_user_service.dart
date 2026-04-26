import 'package:supabase_flutter/supabase_flutter.dart';

class AuthUserService {
  static Future<bool> emailExistsInUsers(String email) async {
    final client = Supabase.instance.client;
    final normalized = email.trim();
    final row = await client
        .from('users')
        .select('email')
        .eq('email', normalized)
        .maybeSingle();
    return row != null;
  }

  static Future<String> resolveUserType({
    required String userId,
    required String? email,
  }) async {
    final client = Supabase.instance.client;

    final byId = await client
        .from('users')
        .select('user_type')
        .eq('id', userId)
        .maybeSingle();
    if (byId != null && byId['user_type'] != null) {
      return byId['user_type'].toString();
    }

    final byUserId = await client
        .from('users')
        .select('user_type')
        .eq('user_id', userId)
        .maybeSingle();
    if (byUserId != null && byUserId['user_type'] != null) {
      return byUserId['user_type'].toString();
    }

    if (email != null && email.trim().isNotEmpty) {
      final byEmail = await client
          .from('users')
          .select('user_type')
          .eq('email', email.trim())
          .maybeSingle();
      if (byEmail != null && byEmail['user_type'] != null) {
        return byEmail['user_type'].toString();
      }
    }

    return 'customer';
  }
}
