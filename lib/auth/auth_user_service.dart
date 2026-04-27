import 'package:supabase_flutter/supabase_flutter.dart';

class AuthUserService {
  static Future<bool> emailExistsInUsers(String email) async {
    final client = Supabase.instance.client;
    final normalized = email.trim().toLowerCase();
    final row = await client
        .from('users')
        .select('email')
        .ilike('email', normalized)
        .maybeSingle();
    return row != null;
  }

  static Future<void> createUserProfile(
    String userId,
    String email, {
    String userType = 'customer',
  }) async {
    final client = Supabase.instance.client;
    final normalizedEmail = email.trim().toLowerCase();

    // CHANGED: Use upsert instead of insert
    await client.from('users').upsert({
      'id': userId,
      'email': normalizedEmail,
      'user_type': userType,
    });
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
        .eq('id', userId)
        .maybeSingle();
    if (byUserId != null && byUserId['user_type'] != null) {
      return byUserId['user_type'].toString();
    }

    if (email != null && email.trim().isNotEmpty) {
      final normalizedEmail = email.trim().toLowerCase();
      final byEmail = await client
          .from('users')
          .select('user_type')
          .ilike('email', normalizedEmail)
          .maybeSingle();
      if (byEmail != null && byEmail['user_type'] != null) {
        return byEmail['user_type'].toString();
      }
    }

    return 'customer';
  }

  static Future<bool> vendorHasBrandInfo(String userId) async {
    final client = Supabase.instance.client;
    final row = await client
        .from('brands')
        .select('id')
        .eq('owner_id', userId)
        .maybeSingle();
    return row != null;
  }

  static Future<Map<String, dynamic>?> getVendorBrand(String ownerId) async {
    final client = Supabase.instance.client;
    return client
        .from('brands')
        .select('id, brand_name, logo_url, description')
        .eq('owner_id', ownerId)
        .maybeSingle();
  }

  static Future<void> createVendorBrandProfile(
    String ownerId,
    String brandName,
    String description,
    String logoUrl,
  ) async {
    final client = Supabase.instance.client;
    await client.from('brands').insert({
      'owner_id': ownerId,
      'brand_name': brandName,
      'description': description,
      'logo_url': logoUrl,
    });
  }
}
