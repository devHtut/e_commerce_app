import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme_config.dart';
import '../widgets/custom_loading_state.dart';
import '../widgets/price_formatter.dart';
import 'vendor_plan_payment_screen.dart';
import 'vendor_plan_service.dart';
import 'vendor_product_selection_screen.dart';

class PlansPricingScreen extends StatefulWidget {
  const PlansPricingScreen({super.key});

  @override
  State<PlansPricingScreen> createState() => _PlansPricingScreenState();
}

class _PlansPricingScreenState extends State<PlansPricingScreen> {
  bool _loading = true;
  List<VendorPlan> _plans = const <VendorPlan>[];
  VendorPlanAccess? _access;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      VendorPlanService.instance.loadPlans(),
      VendorPlanService.instance.loadAccessForCurrentVendor(),
    ]);
    if (!mounted) return;
    setState(() {
      _plans = results[0] as List<VendorPlan>;
      _access = results[1] as VendorPlanAccess;
      _loading = false;
    });
  }

  Future<void> _openPayment(VendorPlan plan) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => VendorPlanPaymentScreen(plan: plan)),
    );
    if (changed == true) _load();
  }

  Future<void> _chooseProducts() async {
    final access = _access;
    final limit = access?.productLimit;
    if (limit == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VendorProductSelectionScreen(productLimit: limit),
      ),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        title: const Text('Plans & Pricing', style: AppTextStyles.appBarTitle),
      ),
      body: SafeArea(
        child: _loading
            ? const CustomLoadingCenter()
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_access != null) _currentPlanCard(_access!),
                    const SizedBox(height: 16),
                    ..._plans.map(_planCard),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _currentPlanCard(VendorPlanAccess access) {
    final limit = access.productLimit == null
        ? 'Unlimited'
        : '${access.productLimit} products';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Plan',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: AppFonts.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            access.planName,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: AppFonts.primary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${access.inStockProductCount} / $limit in stock',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: AppFonts.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (access.trialDaysRemaining != null) ...[
            const SizedBox(height: 6),
            Text(
              '${access.trialDaysRemaining} trial days remaining',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          if (access.needsProductSelection) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _chooseProducts,
              icon: const Icon(CupertinoIcons.checkmark_alt_circle),
              label: const Text('Choose Editable Products'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryGreen,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _planCard(VendorPlan plan) {
    final access = _access;
    final current =
        access != null &&
        ((access.isTrial && plan.code == VendorPlanService.trialPlanCode) ||
            (!access.isTrial && access.planCode == plan.code));
    final price = plan.priceMmk == null
        ? 'Custom pricing'
        : plan.priceMmk == 0
        ? 'Free'
        : '${formatKyat(plan.priceMmk!.toDouble())} / month';
    final limit = plan.productLimit == null
        ? 'Unlimited products'
        : '${plan.productLimit} in-stock products';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: current ? AppColors.primaryGreen : Colors.transparent,
          width: current ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontFamily: AppFonts.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (current)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Current',
                    style: TextStyle(
                      color: AppColors.primaryGreen,
                      fontFamily: AppFonts.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            price,
            style: const TextStyle(
              color: AppColors.primaryGreen,
              fontFamily: AppFonts.primary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(limit, style: AppTextStyles.body),
          const SizedBox(height: 12),
          ...plan.features
              .take(5)
              .map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        CupertinoIcons.check_mark_circled_solid,
                        color: AppColors.primaryGreen,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(feature)),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: current || !plan.isPaid || plan.priceMmk == null
                  ? null
                  : () => _openPayment(plan),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: Text(
                current
                    ? 'Current Plan'
                    : plan.priceMmk == null
                    ? 'Contact Us'
                    : plan.isPaid
                    ? 'Purchase'
                    : 'Free Plan',
                style: AppTextStyles.button,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
