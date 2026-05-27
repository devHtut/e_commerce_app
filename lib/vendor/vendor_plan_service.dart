import 'package:supabase_flutter/supabase_flutter.dart';

class VendorPlan {
  final String code;
  final String name;
  final int? priceMmk;
  final int? productLimit;
  final bool isPaid;
  final bool analyticsEnabled;
  final List<String> features;

  const VendorPlan({
    required this.code,
    required this.name,
    required this.priceMmk,
    required this.productLimit,
    required this.isPaid,
    required this.analyticsEnabled,
    required this.features,
  });

  factory VendorPlan.fromRow(Map<String, dynamic> row) {
    final rawFeatures = row['features'];
    return VendorPlan(
      code: row['code']?.toString() ?? '',
      name: row['name']?.toString() ?? 'Plan',
      priceMmk: (row['price_mmk'] as num?)?.toInt(),
      productLimit: (row['product_limit'] as num?)?.toInt(),
      isPaid: row['is_paid'] as bool? ?? false,
      analyticsEnabled: row['analytics_enabled'] as bool? ?? false,
      features: rawFeatures is List
          ? rawFeatures.map((item) => item.toString()).toList()
          : const <String>[],
    );
  }
}

class VendorPlanAccess {
  final String vendorId;
  final String planCode;
  final String planName;
  final bool isTrial;
  final bool isPaid;
  final bool analyticsEnabled;
  final int? productLimit;
  final DateTime? trialEndsAt;
  final DateTime? paidPlanExpiresAt;
  final int inStockProductCount;
  final int lockedProductCount;

  const VendorPlanAccess({
    required this.vendorId,
    required this.planCode,
    required this.planName,
    required this.isTrial,
    required this.isPaid,
    required this.analyticsEnabled,
    required this.productLimit,
    required this.trialEndsAt,
    required this.paidPlanExpiresAt,
    required this.inStockProductCount,
    required this.lockedProductCount,
  });

  bool get canAddProduct =>
      productLimit == null || inStockProductCount < productLimit!;

  bool get needsProductSelection =>
      !isTrial &&
      !isPaid &&
      productLimit != null &&
      inStockProductCount > productLimit!;

  int? get trialDaysRemaining {
    if (!isTrial || trialEndsAt == null) return null;
    final remaining = trialEndsAt!.difference(DateTime.now());
    if (remaining.isNegative) return 0;
    return (remaining.inHours / 24).ceil();
  }

  int? get availableProductSlots {
    if (productLimit == null) return null;
    final slots = productLimit! - inStockProductCount;
    return slots < 0 ? 0 : slots;
  }
}

class VendorPlanService {
  VendorPlanService._();

  static final VendorPlanService instance = VendorPlanService._();
  static const int trialDays = 90;
  static const String freePlanCode = 'free';
  static const String trialPlanCode = 'starter';

  final SupabaseClient _client = Supabase.instance.client;

  Future<List<VendorPlan>> loadPlans() async {
    final rows = await _client
        .from('plans')
        .select(
          'code,name,price_mmk,product_limit,is_paid,analytics_enabled,features',
        )
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(VendorPlan.fromRow)
        .toList();
  }

  Future<VendorPlan?> loadPlan(String code) async {
    final row = await _client
        .from('plans')
        .select(
          'code,name,price_mmk,product_limit,is_paid,analytics_enabled,features',
        )
        .eq('code', code)
        .maybeSingle();
    return row == null ? null : VendorPlan.fromRow(row);
  }

  Future<VendorPlanAccess> loadAccessForCurrentVendor() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Vendor is not signed in.');
    }

    final vendor = await _ensureVendorTrialFields(user.id);
    final vendorId = vendor['id']?.toString();
    if (vendorId == null || vendorId.isEmpty) {
      throw StateError('Vendor profile is missing.');
    }

    final brand = await _client
        .from('brands')
        .select('id')
        .eq('owner_id', user.id)
        .maybeSingle();
    final brandId = brand?['id']?.toString();

    final firstSignInAt = _date(vendor['first_sign_in_at']);
    final trialEndsAt = firstSignInAt?.add(const Duration(days: trialDays));
    final now = DateTime.now();
    final paidExpiresAt = _date(vendor['paid_plan_expires_at']);
    final hasActivePaidPlan =
        vendor['subscription_status']?.toString() == 'active' &&
        paidExpiresAt != null &&
        paidExpiresAt.isAfter(now);
    final trialActive =
        !hasActivePaidPlan && trialEndsAt != null && trialEndsAt.isAfter(now);
    final effectivePlanCode = hasActivePaidPlan
        ? (vendor['current_plan_code']?.toString() ?? freePlanCode)
        : trialActive
        ? trialPlanCode
        : freePlanCode;
    final plan =
        await loadPlan(effectivePlanCode) ??
        VendorPlan(
          code: effectivePlanCode,
          name: trialActive ? 'Starter Trial' : 'Free',
          priceMmk: trialActive ? 20000 : 0,
          productLimit: trialActive ? 20 : 10,
          isPaid: trialActive,
          analyticsEnabled: trialActive,
          features: const <String>[],
        );
    final count = brandId == null ? 0 : await countInStockProducts(brandId);
    final lockedCount = brandId == null
        ? 0
        : await countLockedProducts(brandId);

    return VendorPlanAccess(
      vendorId: vendorId,
      planCode: trialActive ? 'trial' : plan.code,
      planName: trialActive ? 'Starter Trial' : plan.name,
      isTrial: trialActive,
      isPaid: hasActivePaidPlan,
      analyticsEnabled: trialActive || hasActivePaidPlan,
      productLimit: plan.productLimit,
      trialEndsAt: trialEndsAt,
      paidPlanExpiresAt: paidExpiresAt,
      inStockProductCount: count,
      lockedProductCount: lockedCount,
    );
  }

  Future<Map<String, dynamic>> _ensureVendorTrialFields(String userId) async {
    final row = await _client
        .from('vendors')
        .select(
          'id,user_id,first_sign_in_at,trial_popup_shown_at,current_plan_code,subscription_status,paid_plan_started_at,paid_plan_expires_at,facebook_url,instagram_url,tiktok_url',
        )
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) {
      throw StateError('Vendor profile is missing.');
    }
    if (row['first_sign_in_at'] != null) return row;

    final updated = await _client
        .from('vendors')
        .update({
          'first_sign_in_at': DateTime.now().toIso8601String(),
          'current_plan_code':
              row['current_plan_code']?.toString() ?? freePlanCode,
          'subscription_status':
              row['subscription_status']?.toString() ?? 'trial',
        })
        .eq('id', row['id'])
        .select(
          'id,user_id,first_sign_in_at,trial_popup_shown_at,current_plan_code,subscription_status,paid_plan_started_at,paid_plan_expires_at,facebook_url,instagram_url,tiktok_url',
        )
        .single();
    return updated;
  }

  Future<bool> shouldShowTrialPopup() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final vendor = await _ensureVendorTrialFields(user.id);
    if (vendor['trial_popup_shown_at'] != null) return false;
    final access = await loadAccessForCurrentVendor();
    return access.isTrial;
  }

  Future<void> markTrialPopupShown(String vendorId) async {
    await _client
        .from('vendors')
        .update({'trial_popup_shown_at': DateTime.now().toIso8601String()})
        .eq('id', vendorId);
  }

  Future<int> countInStockProducts(String brandId) async {
    final rows = await _client
        .from('products')
        .select('id,product_variants(stock_quantity)')
        .eq('brand_id', brandId);
    return (rows as List<dynamic>).where((row) {
      final variants =
          ((row as Map<String, dynamic>)['product_variants']
              as List<dynamic>? ??
          const <dynamic>[]);
      return variants.any(
        (variant) =>
            (((variant as Map<String, dynamic>)['stock_quantity'] as num?)
                    ?.toInt() ??
                0) >
            0,
      );
    }).length;
  }

  Future<int> countLockedProducts(String brandId) async {
    final rows = await _client
        .from('products')
        .select('id')
        .eq('brand_id', brandId)
        .eq('plan_locked', true);
    return (rows as List<dynamic>).length;
  }

  Future<List<VendorSelectableProduct>>
  loadInStockProductsForSelection() async {
    final user = _client.auth.currentUser;
    if (user == null) return const <VendorSelectableProduct>[];
    final brand = await _client
        .from('brands')
        .select('id')
        .eq('owner_id', user.id)
        .maybeSingle();
    final brandId = brand?['id']?.toString();
    if (brandId == null || brandId.isEmpty) {
      return const <VendorSelectableProduct>[];
    }

    final rows = await _client
        .from('products')
        .select(
          'id,title,created_at,plan_locked,product_variants(stock_quantity,image_url)',
        )
        .eq('brand_id', brandId)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(VendorSelectableProduct.fromRow)
        .where((product) => product.stock > 0)
        .toList();
  }

  Future<void> applyManualProductSelection(
    Set<String> unlockedProductIds,
  ) async {
    final products = await loadInStockProductsForSelection();
    final now = DateTime.now().toIso8601String();
    for (final product in products) {
      final shouldLock = !unlockedProductIds.contains(product.id);
      await _client
          .from('products')
          .update({
            'plan_locked': shouldLock,
            'plan_locked_at': shouldLock ? now : null,
          })
          .eq('id', product.id);
    }
  }

  DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }
}

class VendorSelectableProduct {
  final String id;
  final String title;
  final String imageUrl;
  final int stock;
  final bool planLocked;

  const VendorSelectableProduct({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.stock,
    required this.planLocked,
  });

  factory VendorSelectableProduct.fromRow(Map<String, dynamic> row) {
    final variants =
        (row['product_variants'] as List<dynamic>? ?? const <dynamic>[])
            .cast<Map<String, dynamic>>();
    final stock = variants.fold<int>(
      0,
      (sum, variant) =>
          sum + ((variant['stock_quantity'] as num?)?.toInt() ?? 0),
    );
    final image = variants
        .map((variant) => variant['image_url']?.toString() ?? '')
        .firstWhere((url) => url.isNotEmpty, orElse: () => '');
    return VendorSelectableProduct(
      id: row['id']?.toString() ?? '',
      title: row['title']?.toString() ?? 'Untitled',
      imageUrl: image,
      stock: stock,
      planLocked: row['plan_locked'] as bool? ?? false,
    );
  }
}
