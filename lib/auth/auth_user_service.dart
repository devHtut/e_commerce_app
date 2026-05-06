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

    await client.from('users').upsert({
      'id': userId,
      'email': normalizedEmail,
      'user_type': userType,
    });
  }

  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final client = Supabase.instance.client;
    return client
        .from('profiles')
        .select('id, full_name, avatar_url')
        .eq('id', userId)
        .maybeSingle();
  }

  static Future<bool> userHasProfile(String userId) async {
    final profile = await getUserProfile(userId);
    return profile != null &&
        (profile['full_name']?.toString().trim().isNotEmpty ?? false);
  }

  static Future<void> upsertUserProfile(
    String userId,
    String fullName,
    String? avatarUrl,
    String prefix,
  ) async {
    final client = Supabase.instance.client;
    await client.from('profiles').upsert({
      'id': userId,
      'full_name': fullName.trim(),
      'avatar_url': avatarUrl,
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

  static Future<bool> isVendorAccount(String userId, {String? email}) async {
    final t = await resolveUserType(userId: userId, email: email);
    return t.trim().toLowerCase() == 'vendor';
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

  static Future<bool> vendorHasBusinessInfo(String userId) async {
    final client = Supabase.instance.client;
    final row = await client
        .from('vendors')
        .select('id, phone, address')
        .eq('user_id', userId)
        .maybeSingle();
    return row != null &&
        (row['phone']?.toString().trim().isNotEmpty ?? false) &&
        (row['address']?.toString().trim().isNotEmpty ?? false);
  }

  static Future<Map<String, dynamic>?> getVendorBrand(String ownerId) async {
    final client = Supabase.instance.client;
    return client
        .from('brands')
        .select('id, brand_name, logo_url, description, prefix')
        .eq('owner_id', ownerId)
        .maybeSingle();
  }

  static Future<void> upsertVendorBrandProfile(
    String ownerId,
    String brandName,
    String description,
    String logoUrl,
      String prefix,
  ) async {
    final client = Supabase.instance.client;
    final existing = await client
        .from('brands')
        .select('id')
        .eq('owner_id', ownerId)
        .maybeSingle();

    final payload = {
      'owner_id': ownerId,
      'brand_name': brandName,
      'description': description,
      'logo_url': logoUrl,
      'prefix': prefix.trim(),
    };

    if (existing != null) {
      await client.from('brands').update(payload).eq('owner_id', ownerId);
    } else {
      await client.from('brands').insert(payload);
    }
  }

  static Future<Map<String, dynamic>?> getVendorByUser(String userId) async {
    final client = Supabase.instance.client;
    return client
        .from('vendors')
        .select(
          'id, user_id, phone, address, facebook_url, instagram_url, tiktok_url',
        )
        .eq('user_id', userId)
        .maybeSingle();
  }

  static Future<Map<String, dynamic>?> upsertVendorDetails(
    String userId,
    String phone,
    String address,
  ) async {
    final client = Supabase.instance.client;
    final existing = await getVendorByUser(userId);
    final payload = {
      'user_id': userId,
      'phone': phone,
      'address': address,
      'facebook_url': existing?['facebook_url']?.toString() ?? '',
      'instagram_url': existing?['instagram_url']?.toString() ?? '',
      'tiktok_url': existing?['tiktok_url']?.toString(),
    };

    if (existing != null) {
      await client.from('vendors').update(payload).eq('user_id', userId);
      return {'id': existing['id'], ...payload};
    }

    final inserted = await client
        .from('vendors')
        .insert(payload)
        .select(
          'id, user_id, phone, address, facebook_url, instagram_url, tiktok_url',
        )
        .single();
    return inserted;
  }

  static Future<Map<String, dynamic>?> updateVendorSocialLinks({
    required String userId,
    required String facebookUrl,
    required String instagramUrl,
    required String? tiktokUrl,
  }) async {
    final client = Supabase.instance.client;
    final existing = await getVendorByUser(userId);
    final payload = {
      'user_id': userId,
      'phone': existing?['phone']?.toString() ?? '',
      'address': existing?['address']?.toString() ?? '',
      'facebook_url': facebookUrl,
      'instagram_url': instagramUrl,
      'tiktok_url': tiktokUrl,
    };

    if (existing != null) {
      await client.from('vendors').update(payload).eq('user_id', userId);
      return {'id': existing['id'], ...payload};
    }

    final inserted = await client
        .from('vendors')
        .insert(payload)
        .select(
          'id, user_id, phone, address, facebook_url, instagram_url, tiktok_url',
        )
        .single();
    return inserted;
  }

  static Future<List<Map<String, dynamic>>> getPaymentTypes() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from('payment_types')
        .select('name')
        .order('name', ascending: true);
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((row) => {'name': row['name']?.toString() ?? ''})
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getVendorPayments(
    String vendorId,
  ) async {
    final client = Supabase.instance.client;
    final rows = await client
        .from('vendor_payments')
        .select(
          'id, vendor_id, payment_type, account_name, account_number, is_active',
        )
        .eq('vendor_id', vendorId)
        .order('id', ascending: true);
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(
          (row) => {
            'id': row['id'],
            'vendor_id': row['vendor_id'],
            'payment_type': row['payment_type']?.toString() ?? '',
            'account_name': row['account_name']?.toString() ?? '',
            'account_number': row['account_number']?.toString() ?? '',
            'is_active': row['is_active'] as bool? ?? false,
          },
        )
        .toList();
  }

  static Future<String?> getVendorIdByBrandId(String brandId) async {
    final client = Supabase.instance.client;
    final brandRow = await client
        .from('brands')
        .select('owner_id')
        .eq('id', brandId)
        .maybeSingle();
    final ownerId = brandRow?['owner_id']?.toString();
    if (ownerId == null || ownerId.isEmpty) {
      return null;
    }

    final vendorRow = await client
        .from('vendors')
        .select('id')
        .eq('user_id', ownerId)
        .maybeSingle();
    return vendorRow?['id']?.toString();
  }

  static Future<List<Map<String, dynamic>>> getVendorPaymentsByBrand(
    String brandId,
  ) async {
    final vendorId = await getVendorIdByBrandId(brandId);
    if (vendorId == null) {
      return [];
    }
    return getVendorPayments(vendorId);
  }

  static Future<void> replaceVendorPayments(
    String vendorId,
    List<Map<String, String>> payments,
  ) async {
    final client = Supabase.instance.client;
    await client.from('vendor_payments').delete().eq('vendor_id', vendorId);
    if (payments.isEmpty) return;
    final rows = payments.map((payment) {
      return {
        'vendor_id': vendorId,
        'payment_type': payment['payment_type'],
        'account_name': payment['account_name'],
        'account_number': payment['account_number'],
        'is_active': true,
      };
    }).toList();
    await client.from('vendor_payments').insert(rows);
  }
}
