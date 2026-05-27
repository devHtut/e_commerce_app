import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_user_service.dart';
import '../auth/signin_screen.dart';
import '../customer/home_screen.dart';
import '../theme_config.dart';
import '../widgets/app_bottom_navigation_bar.dart';
import '../widgets/custom_loading_state.dart';
import '../widgets/custom_pop_up.dart';
import '../widgets/price_formatter.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  bool _accessOk = false;
  bool _loading = true;
  bool _saving = false;
  String _brandPlanFilter = 'all';

  _AdminStats _stats = _AdminStats.empty();
  List<_PlanOrder> _planOrders = const <_PlanOrder>[];
  List<_AdminBrand> _brands = const <_AdminBrand>[];
  List<_AdminReport> _reports = const <_AdminReport>[];
  List<_AdminPaymentMethod> _paymentMethods = const <_AdminPaymentMethod>[];
  List<_AdminPlan> _plans = const <_AdminPlan>[];

  static const List<String> _titles = [
    'Admin Overview',
    'Brands',
    'Reports',
    'Payments',
    'Plans',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureAdminThenLoad());
  }

  Future<void> _ensureAdminThenLoad() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (route) => false,
      );
      return;
    }

    final userType = await AuthUserService.resolveUserType(
      userId: user.id,
      email: user.email,
    );
    if (userType.toLowerCase() != 'admin') {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
      return;
    }

    if (!mounted) return;
    setState(() => _accessOk = true);
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _loadPlanOrders(),
        _loadBrands(),
        _loadReports(),
        _loadPaymentMethods(),
        _loadPlans(),
        _loadStats(),
      ]);
      if (!mounted) return;
      setState(() {
        _planOrders = results[0] as List<_PlanOrder>;
        _brands = results[1] as List<_AdminBrand>;
        _reports = results[2] as List<_AdminReport>;
        _paymentMethods = results[3] as List<_AdminPaymentMethod>;
        _plans = results[4] as List<_AdminPlan>;
        _stats = results[5] as _AdminStats;
      });
    } catch (error) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Unable to load admin data',
        message: 'Please check admin table permissions and try again.',
        type: PopupType.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<_AdminStats> _loadStats() async {
    final results = await Future.wait([
      Supabase.instance.client.from('users').select('id,user_type,created_at'),
      Supabase.instance.client
          .from('orders')
          .select('id,total_price,status,created_at'),
      Supabase.instance.client
          .from('vendor_plan_orders')
          .select('id,plan_code,amount_mmk,status,created_at'),
      Supabase.instance.client
          .from('vendors')
          .select('id,subscription_status,current_plan_code'),
      Supabase.instance.client.from('reports').select('id,status'),
      Supabase.instance.client.from('brands').select('id'),
    ]);

    final users = (results[0] as List<dynamic>).cast<Map<String, dynamic>>();
    final orders = (results[1] as List<dynamic>).cast<Map<String, dynamic>>();
    final planOrders = (results[2] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final vendors = (results[3] as List<dynamic>).cast<Map<String, dynamic>>();
    final reports = (results[4] as List<dynamic>).cast<Map<String, dynamic>>();
    final brands = (results[5] as List<dynamic>).cast<Map<String, dynamic>>();

    return _AdminStats.fromRows(
      users: users,
      orders: orders,
      planOrders: planOrders,
      vendors: vendors,
      reports: reports,
      brands: brands,
    );
  }

  Future<List<_PlanOrder>> _loadPlanOrders() async {
    final rows = await Supabase.instance.client
        .from('vendor_plan_orders')
        .select(
          'id,vendor_id,plan_code,amount_mmk,status,payment_method_id,payment_screenshot_url,admin_note,paid_at,approved_at,rejected_at,created_at',
        )
        .order('created_at', ascending: false);

    final orders = <_PlanOrder>[];
    for (final row in (rows as List<dynamic>).cast<Map<String, dynamic>>()) {
      Map<String, dynamic>? vendor;
      Map<String, dynamic>? plan;
      Map<String, dynamic>? method;
      Map<String, dynamic>? brand;

      try {
        vendor = await Supabase.instance.client
            .from('vendors')
            .select('id,user_id,phone,current_plan_code,subscription_status')
            .eq('id', row['vendor_id'])
            .maybeSingle();
      } catch (_) {}
      try {
        plan = await Supabase.instance.client
            .from('plans')
            .select('code,name,product_limit')
            .eq('code', row['plan_code'])
            .maybeSingle();
      } catch (_) {}
      try {
        final userId = vendor?['user_id']?.toString();
        if (userId != null && userId.isNotEmpty) {
          brand = await Supabase.instance.client
              .from('brands')
              .select('brand_name,logo_url')
              .eq('owner_id', userId)
              .maybeSingle();
        }
      } catch (_) {}
      final methodId = row['payment_method_id']?.toString();
      if (methodId != null && methodId.isNotEmpty) {
        try {
          method = await Supabase.instance.client
              .from('admin_payment_methods')
              .select('id,name,account_name,account_number')
              .eq('id', methodId)
              .maybeSingle();
        } catch (_) {}
      }
      orders.add(_PlanOrder.fromRows(row, vendor, plan, method, brand));
    }
    return orders;
  }

  Future<List<_AdminBrand>> _loadBrands() async {
    final brandRows = await Supabase.instance.client
        .from('brands')
        .select('id,brand_name,logo_url,description,owner_id,created_at')
        .order('created_at', ascending: false);

    final brands = <_AdminBrand>[];
    for (final brand
        in (brandRows as List<dynamic>).cast<Map<String, dynamic>>()) {
      final ownerId = brand['owner_id']?.toString();
      Map<String, dynamic>? vendor;
      int productCount = 0;
      if (ownerId != null && ownerId.isNotEmpty) {
        try {
          vendor = await Supabase.instance.client
              .from('vendors')
              .select(
                'id,phone,current_plan_code,subscription_status,paid_plan_expires_at',
              )
              .eq('user_id', ownerId)
              .maybeSingle();
        } catch (_) {}
      }
      try {
        final products = await Supabase.instance.client
            .from('products')
            .select('id')
            .eq('brand_id', brand['id']);
        productCount = (products as List<dynamic>).length;
      } catch (_) {}
      brands.add(_AdminBrand.fromRows(brand, vendor, productCount));
    }
    return brands;
  }

  Future<List<_AdminReport>> _loadReports() async {
    final rows = await Supabase.instance.client
        .from('reports')
        .select(
          'id,reporter_id,report_type,product_id,chat_id,reason,details,status,created_at,updated_at',
        )
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_AdminReport.fromRow)
        .toList();
  }

  Future<List<_AdminPaymentMethod>> _loadPaymentMethods() async {
    final rows = await Supabase.instance.client
        .from('admin_payment_methods')
        .select(
          'id,name,account_name,account_number,qr_image_url,instructions,is_active,sort_order,created_at',
        )
        .order('sort_order', ascending: true);
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_AdminPaymentMethod.fromRow)
        .toList();
  }

  Future<List<_AdminPlan>> _loadPlans() async {
    final rows = await Supabase.instance.client
        .from('plans')
        .select(
          'id,code,name,price_mmk,product_limit,is_paid,analytics_enabled,features,is_active,sort_order,created_at',
        )
        .order('sort_order', ascending: true);
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_AdminPlan.fromRow)
        .toList();
  }

  Future<void> _approveOrder(_PlanOrder order) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(days: 30));
      await Supabase.instance.client
          .from('vendor_plan_orders')
          .update({
            'status': 'approved',
            'approved_at': now.toIso8601String(),
            'paid_at': now.toIso8601String(),
          })
          .eq('id', order.id);
      await Supabase.instance.client
          .from('vendors')
          .update({
            'current_plan_code': order.planCode,
            'subscription_status': 'active',
            'paid_plan_started_at': now.toIso8601String(),
            'paid_plan_expires_at': expiresAt.toIso8601String(),
          })
          .eq('id', order.vendorId);
      await Supabase.instance.client.from('vendor_plan_history').insert({
        'vendor_id': order.vendorId,
        'plan_code': order.planCode,
        'source_order_id': order.id,
        'status': 'active',
        'started_at': now.toIso8601String(),
      });
      await _unlockProductsIfAllowed(order.vendorId, order.productLimit);
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Plan approved',
        message: '${order.vendorLabel} is now on ${order.planName}.',
        type: PopupType.success,
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Approval failed',
        message: 'Unable to approve this plan order.',
        type: PopupType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _unlockProductsIfAllowed(
    String vendorId,
    int? productLimit,
  ) async {
    final ownerId = await _vendorOwnerId(vendorId);
    if (ownerId.isEmpty) return;
    final brand = await Supabase.instance.client
        .from('brands')
        .select('id')
        .eq('owner_id', ownerId)
        .maybeSingle();
    final brandId = brand?['id']?.toString();
    if (brandId == null || brandId.isEmpty) return;

    final products = await Supabase.instance.client
        .from('products')
        .select('id,product_variants(stock_quantity)')
        .eq('brand_id', brandId);
    final inStockIds = (products as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((product) {
          final variants =
              product['product_variants'] as List<dynamic>? ??
              const <dynamic>[];
          return variants.any(
            (variant) =>
                (((variant as Map<String, dynamic>)['stock_quantity'] as num?)
                        ?.toInt() ??
                    0) >
                0,
          );
        })
        .map((product) => product['id'].toString())
        .toList();
    if (productLimit != null && inStockIds.length > productLimit) return;
    for (final productId in inStockIds) {
      await Supabase.instance.client
          .from('products')
          .update({'plan_locked': false, 'plan_locked_at': null})
          .eq('id', productId);
    }
  }

  Future<String> _vendorOwnerId(String vendorId) async {
    final vendor = await Supabase.instance.client
        .from('vendors')
        .select('user_id')
        .eq('id', vendorId)
        .maybeSingle();
    return vendor?['user_id']?.toString() ?? '';
  }

  Future<void> _rejectOrder(_PlanOrder order) async {
    final noteController = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject plan order?'),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Admin note'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, noteController.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    noteController.dispose();
    if (note == null) return;

    setState(() => _saving = true);
    try {
      await Supabase.instance.client
          .from('vendor_plan_orders')
          .update({
            'status': 'rejected',
            'rejected_at': DateTime.now().toIso8601String(),
            'admin_note': note,
          })
          .eq('id', order.id);
      await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateReportStatus(_AdminReport report, String status) async {
    await Supabase.instance.client
        .from('reports')
        .update({
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', report.id);
    await _load();
  }

  Future<void> _togglePaymentMethod(_AdminPaymentMethod method) async {
    await Supabase.instance.client
        .from('admin_payment_methods')
        .update({'is_active': !method.isActive})
        .eq('id', method.id);
    await _load();
  }

  Future<void> _togglePlan(_AdminPlan plan) async {
    await Supabase.instance.client
        .from('plans')
        .update({'is_active': !plan.isActive})
        .eq('code', plan.code);
    await _load();
  }

  Future<void> _showPaymentMethodSheet({_AdminPaymentMethod? method}) async {
    final nameController = TextEditingController(text: method?.name ?? '');
    final accountNameController = TextEditingController(
      text: method?.accountName ?? '',
    );
    final accountNumberController = TextEditingController(
      text: method?.accountNumber ?? '',
    );
    final instructionsController = TextEditingController(
      text: method?.instructions ?? '',
    );
    PlatformFile? selectedQr;
    Uint8List? qrPreview;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickQr() async {
              final result = await FilePicker.pickFiles(
                type: FileType.image,
                allowMultiple: false,
                withData: true,
              );
              if (result == null || result.files.isEmpty) return;
              setSheetState(() {
                selectedQr = result.files.first;
                qrPreview = result.files.first.bytes;
              });
            }

            Future<void> save() async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              String qrUrl = method?.qrImageUrl ?? '';
              final qr = selectedQr;
              if (qr != null && qr.bytes != null) {
                final path =
                    'admin-payment-methods/${DateTime.now().millisecondsSinceEpoch}_${qr.name}';
                await Supabase.instance.client.storage
                    .from('payments')
                    .uploadBinary(path, qr.bytes!);
                qrUrl = Supabase.instance.client.storage
                    .from('payments')
                    .getPublicUrl(path);
              }
              final payload = {
                'name': name,
                'account_name': accountNameController.text.trim(),
                'account_number': accountNumberController.text.trim(),
                'instructions': instructionsController.text.trim(),
                'qr_image_url': qrUrl,
                'is_active': true,
              };
              if (method == null) {
                await Supabase.instance.client
                    .from('admin_payment_methods')
                    .insert(payload);
              } else {
                await Supabase.instance.client
                    .from('admin_payment_methods')
                    .update(payload)
                    .eq('id', method.id);
              }
              if (!context.mounted) return;
              Navigator.pop(context);
            }

            return _AdminSheet(
              title: method == null ? 'Add Payment Method' : 'Edit Payment',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _sheetField(nameController, 'Payment name'),
                  _sheetField(accountNameController, 'Account name'),
                  _sheetField(accountNumberController, 'Account number'),
                  _sheetField(
                    instructionsController,
                    'Instructions',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: pickQr,
                    child: Container(
                      height: 118,
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.lightGrey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: qrPreview == null
                          ? Text(
                              method?.qrImageUrl.isNotEmpty == true
                                  ? 'Tap to replace QR image'
                                  : 'Tap to upload QR image',
                            )
                          : Image.memory(qrPreview!, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sheetSaveButton(save, 'Save Payment Method'),
                ],
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    accountNameController.dispose();
    accountNumberController.dispose();
    instructionsController.dispose();
    await _load();
  }

  Future<void> _showPlanSheet({_AdminPlan? plan}) async {
    final codeController = TextEditingController(text: plan?.code ?? '');
    final nameController = TextEditingController(text: plan?.name ?? '');
    final priceController = TextEditingController(
      text: plan?.priceMmk == null ? '' : '${plan!.priceMmk}',
    );
    final limitController = TextEditingController(
      text: plan?.productLimit == null ? '' : '${plan!.productLimit}',
    );
    final featuresController = TextEditingController(
      text: plan?.features.join(', ') ?? '',
    );
    var isPaid = plan?.isPaid ?? true;
    var analyticsEnabled = plan?.analyticsEnabled ?? true;
    var isActive = plan?.isActive ?? true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> save() async {
              final code = codeController.text.trim().toLowerCase();
              final name = nameController.text.trim();
              if (code.isEmpty || name.isEmpty) return;
              final payload = {
                'code': code,
                'name': name,
                'price_mmk': int.tryParse(priceController.text.trim()),
                'product_limit': int.tryParse(limitController.text.trim()),
                'is_paid': isPaid,
                'analytics_enabled': analyticsEnabled,
                'is_active': isActive,
                'features': featuresController.text
                    .split(',')
                    .map((feature) => feature.trim())
                    .where((feature) => feature.isNotEmpty)
                    .toList(),
              };
              if (plan == null) {
                await Supabase.instance.client.from('plans').insert(payload);
              } else {
                await Supabase.instance.client
                    .from('plans')
                    .update(payload)
                    .eq('code', plan.code);
              }
              if (!context.mounted) return;
              Navigator.pop(context);
            }

            return _AdminSheet(
              title: plan == null ? 'Add Plan' : 'Edit Plan',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _sheetField(codeController, 'Plan code'),
                  _sheetField(nameController, 'Plan name'),
                  _sheetField(priceController, 'Price MMK'),
                  _sheetField(limitController, 'Product limit'),
                  _sheetField(
                    featuresController,
                    'Features separated by commas',
                    maxLines: 3,
                  ),
                  SwitchListTile(
                    value: isPaid,
                    activeThumbColor: AppColors.primaryGreen,
                    title: const Text('Paid plan'),
                    onChanged: (value) => setSheetState(() => isPaid = value),
                  ),
                  SwitchListTile(
                    value: analyticsEnabled,
                    activeThumbColor: AppColors.primaryGreen,
                    title: const Text('Analytics enabled'),
                    onChanged: (value) =>
                        setSheetState(() => analyticsEnabled = value),
                  ),
                  SwitchListTile(
                    value: isActive,
                    activeThumbColor: AppColors.primaryGreen,
                    title: const Text('Visible to vendors'),
                    onChanged: (value) => setSheetState(() => isActive = value),
                  ),
                  const SizedBox(height: 10),
                  _sheetSaveButton(save, 'Save Plan'),
                ],
              ),
            );
          },
        );
      },
    );

    codeController.dispose();
    nameController.dispose();
    priceController.dispose();
    limitController.dispose();
    featuresController.dispose();
    await _load();
  }

  Widget _sheetField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType:
            hint.toLowerCase().contains('price') ||
                hint.toLowerCase().contains('limit')
            ? TextInputType.number
            : TextInputType.text,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: AppColors.lightGrey,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _sheetSaveButton(Future<void> Function() onPressed, String label) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
        ),
        child: Text(label, style: AppTextStyles.button),
      ),
    );
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_accessOk || _loading) {
      return const Scaffold(body: CustomLoadingCenter());
    }

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(_titles[_currentIndex], style: AppTextStyles.appBarTitle),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(CupertinoIcons.refresh),
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(CupertinoIcons.square_arrow_right),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chart_bar_square),
            activeIcon: Icon(CupertinoIcons.chart_bar_square_fill),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront),
            label: 'Brands',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.flag),
            activeIcon: Icon(CupertinoIcons.flag_fill),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.creditcard),
            activeIcon: Icon(CupertinoIcons.creditcard_fill),
            label: 'Payments',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.layers),
            activeIcon: Icon(CupertinoIcons.layers_fill),
            label: 'Plans',
          ),
        ],
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (_currentIndex == 3) {
      return FloatingActionButton(
        onPressed: () => _showPaymentMethodSheet(),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        child: const Icon(CupertinoIcons.add),
      );
    }
    if (_currentIndex == 4) {
      return FloatingActionButton(
        onPressed: () => _showPlanSheet(),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        child: const Icon(CupertinoIcons.add),
      );
    }
    return null;
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _load,
      child: switch (_currentIndex) {
        0 => _buildOverviewPage(),
        1 => _buildBrandsPage(),
        2 => _buildReportsPage(),
        3 => _buildPaymentMethodsPage(),
        _ => _buildPlansPage(),
      },
    );
  }

  Widget _buildOverviewPage() {
    final pendingOrders = _planOrders
        .where(
          (order) => order.status == 'pending' || order.status == 'submitted',
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildOverviewHeader(),
        const SizedBox(height: 14),
        Row(
          children: [
            _metricCard('Users', '${_stats.totalUsers}', 'All app accounts'),
            const SizedBox(width: 10),
            _metricCard('Brands', '${_stats.totalBrands}', 'Vendor shops'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _metricCard(
              'Revenue',
              formatKyat(_stats.planRevenue.toDouble()),
              'Approved plans',
            ),
            const SizedBox(width: 10),
            _metricCard('Reports', '${_stats.openReports}', 'Open reports'),
          ],
        ),
        const SizedBox(height: 16),
        _analyticsPanel(
          title: 'Active Users',
          trailing: '${_stats.totalUsers} total',
          child: Column(
            children: [
              SizedBox(
                height: 190,
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: _AdminPieChart(
                        segments: _stats.userSegments,
                        total: _stats.totalUsers,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _stats.userSegments
                            .map((segment) => _legendRow(segment))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _analyticsPanel(
          title: 'Plan Revenue',
          trailing: formatKyat(_stats.planRevenue.toDouble()),
          child: _AdminBarChart(
            bars: _stats.revenueBars,
            emptyText: 'No approved plan revenue yet.',
          ),
        ),
        const SizedBox(height: 16),
        _analyticsPanel(
          title: 'Order Revenue',
          trailing: formatKyat(_stats.orderRevenue.toDouble()),
          child: _AdminBarChart(
            bars: _stats.orderRevenueBars,
            emptyText: 'No completed order revenue yet.',
          ),
        ),
        const SizedBox(height: 16),
        _sectionTitle('Plan Orders'),
        const SizedBox(height: 8),
        if (pendingOrders.isEmpty)
          _emptyCard('No pending plan payments.')
        else
          ...pendingOrders.map(_planOrderCard),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildOverviewHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Burma Brands Operations',
            style: TextStyle(
              color: Colors.white,
              fontFamily: AppFonts.primary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_stats.activeVendors} active vendors • ${_stats.pendingPlanOrders} pending plan payments',
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: AppFonts.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String title, String value, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.darkText,
                fontFamily: AppFonts.primary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.darkText,
                fontFamily: AppFonts.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.subtleText,
                fontFamily: AppFonts.primary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandsPage() {
    final filterOptions = [
      'all',
      'free',
      'trial',
      ..._plans.map((p) => p.code),
    ];
    final filtered = _brandPlanFilter == 'all'
        ? _brands
        : _brands
              .where(
                (brand) => brand.planCode.toLowerCase() == _brandPlanFilter,
              )
              .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filterOptions.toSet().length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final option = filterOptions.toSet().toList()[index];
              final selected = _brandPlanFilter == option;
              return ChoiceChip(
                label: Text(option == 'all' ? 'All Plans' : option),
                selected: selected,
                showCheckmark: false,
                selectedColor: AppColors.primaryGreen,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.darkText,
                  fontFamily: AppFonts.primary,
                  fontWeight: FontWeight.w800,
                ),
                onSelected: (_) => setState(() => _brandPlanFilter = option),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          _emptyCard('No brands match this plan.')
        else
          ...filtered.map(_brandCard),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _brandCard(_AdminBrand brand) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    _AdminBrandDetailPlaceholderScreen(brand: brand),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _imageAvatar(brand.logoUrl, brand.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        brand.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.darkText,
                          fontFamily: AppFonts.primary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${brand.productCount} products • ${brand.phone}',
                        style: const TextStyle(
                          color: AppColors.subtleText,
                          fontFamily: AppFonts.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _smallPill(brand.planLabel, AppColors.primaryGreen),
                          _smallPill(brand.subscriptionStatus, Colors.blueGrey),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(CupertinoIcons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportsPage() {
    final open = _reports.where((report) => report.status == 'open').toList();
    final reviewing = _reports
        .where((report) => report.status == 'reviewing')
        .toList();
    final resolved = _reports
        .where((report) => report.status == 'resolved')
        .toList();
    final dismissed = _reports
        .where((report) => report.status == 'dismissed')
        .toList();
    final ordered = [...open, ...reviewing, ...resolved, ...dismissed];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _metricCard('Open', '${open.length}', 'Needs review'),
            const SizedBox(width: 10),
            _metricCard('Resolved', '${resolved.length}', 'Handled reports'),
          ],
        ),
        const SizedBox(height: 14),
        if (ordered.isEmpty)
          _emptyCard('No reports found.')
        else
          ...ordered.map(_reportCard),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _reportCard(_AdminReport report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${report.reportType.toUpperCase()} report',
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontFamily: AppFonts.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _statusPill(report.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(report.reason, style: AppTextStyles.body),
          if (report.details.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(report.details),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusButton(report, 'reviewing'),
              _statusButton(report, 'resolved'),
              _statusButton(report, 'dismissed'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusButton(_AdminReport report, String status) {
    return OutlinedButton(
      onPressed: report.status == status
          ? null
          : () => _updateReportStatus(report, status),
      child: Text(status),
    );
  }

  Widget _buildPaymentMethodsPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_paymentMethods.isEmpty)
          _emptyCard('No admin payment methods yet.')
        else
          ..._paymentMethods.map(_paymentMethodCard),
        const SizedBox(height: 90),
      ],
    );
  }

  Widget _paymentMethodCard(_AdminPaymentMethod method) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: method.qrImageUrl.isEmpty
                ? null
                : () => _showImage(method.qrImageUrl),
            child: _imageAvatar(method.qrImageUrl, method.name),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  method.name,
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontFamily: AppFonts.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(method.accountName),
                Text(method.accountNumber),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showPaymentMethodSheet(method: method),
            icon: const Icon(CupertinoIcons.pencil),
          ),
          Switch(
            value: method.isActive,
            activeThumbColor: AppColors.primaryGreen,
            onChanged: (_) => _togglePaymentMethod(method),
          ),
        ],
      ),
    );
  }

  Widget _buildPlansPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_plans.isEmpty)
          _emptyCard('No plans found.')
        else
          ..._plans.map(_planCard),
        const SizedBox(height: 90),
      ],
    );
  }

  Widget _planCard(_AdminPlan plan) {
    final limit = plan.productLimit == null
        ? 'Unlimited products'
        : '${plan.productLimit} products';
    final price = plan.priceMmk == null
        ? 'Custom'
        : plan.priceMmk == 0
        ? 'Free'
        : formatKyat(plan.priceMmk!.toDouble());
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _statusPill(plan.isActive ? 'active' : 'hidden'),
            ],
          ),
          const SizedBox(height: 8),
          Text('$price • $limit', style: AppTextStyles.body),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _smallPill(plan.code, Colors.blueGrey),
              if (plan.analyticsEnabled)
                _smallPill('analytics', AppColors.primaryGreen),
              if (plan.isPaid) _smallPill('paid', Colors.deepOrange),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showPlanSheet(plan: plan),
                  icon: const Icon(CupertinoIcons.pencil),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _togglePlan(plan),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: plan.isActive
                        ? Colors.grey.shade700
                        : AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(plan.isActive ? 'Hide' : 'Show'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _planOrderCard(_PlanOrder order) {
    final pending = order.status == 'pending' || order.status == 'submitted';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.planName,
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontFamily: AppFonts.primary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _statusPill(order.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(order.vendorLabel, style: AppTextStyles.body),
          const SizedBox(height: 8),
          Text(
            formatKyat(order.amountMmk.toDouble()),
            style: const TextStyle(
              color: AppColors.primaryGreen,
              fontFamily: AppFonts.primary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text('Payment: ${order.paymentMethodLabel}'),
          const SizedBox(height: 10),
          Row(
            children: [
              if (order.screenshotUrl.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showImage(order.screenshotUrl),
                    icon: const Icon(CupertinoIcons.photo),
                    label: const Text('Screenshot'),
                  ),
                ),
              if (pending && order.screenshotUrl.isNotEmpty)
                const SizedBox(width: 10),
              if (pending)
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : () => _approveOrder(order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Approve'),
                  ),
                ),
            ],
          ),
          if (pending) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _saving ? null : () => _rejectOrder(order),
                child: const Text('Reject'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _analyticsPanel({
    required String title,
    required String trailing,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontFamily: AppFonts.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                trailing,
                style: const TextStyle(
                  color: AppColors.primaryGreen,
                  fontFamily: AppFonts.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _legendRow(_ChartSegment segment) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: segment.color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              segment.label,
              style: const TextStyle(
                color: AppColors.darkText,
                fontFamily: AppFonts.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '${segment.value}',
            style: TextStyle(
              color: segment.color,
              fontFamily: AppFonts.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.darkText,
        fontFamily: AppFonts.primary,
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: AppTextStyles.body),
    );
  }

  Widget _smallPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontFamily: AppFonts.primary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    final color = switch (status) {
      'approved' || 'active' || 'resolved' => AppColors.primaryGreen,
      'rejected' || 'hidden' || 'dismissed' => AppColors.errorRed,
      'reviewing' => Colors.blue.shade700,
      'cancelled' => Colors.grey,
      _ => Colors.amber.shade800,
    };
    return _smallPill(status.toUpperCase(), color);
  }

  Widget _imageAvatar(String imageUrl, String fallback) {
    final initial = fallback.trim().isEmpty
        ? 'B'
        : fallback.trim()[0].toUpperCase();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: imageUrl.isEmpty
          ? Container(
              width: 62,
              height: 62,
              color: AppColors.lightGrey,
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppColors.primaryGreen,
                  fontFamily: AppFonts.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : Image.network(
              imageUrl,
              width: 62,
              height: 62,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 62,
                height: 62,
                color: AppColors.lightGrey,
                alignment: Alignment.center,
                child: Text(initial),
              ),
            ),
    );
  }

  void _showImage(String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _AdminBrandDetailPlaceholderScreen extends StatelessWidget {
  final _AdminBrand brand;

  const _AdminBrandDetailPlaceholderScreen({required this.brand});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(title: Text(brand.name, style: AppTextStyles.appBarTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    brand.name,
                    style: const TextStyle(
                      color: AppColors.darkText,
                      fontFamily: AppFonts.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${brand.planLabel} • ${brand.productCount} products'),
                  const SizedBox(height: 12),
                  const Text(
                    'Brand detail tools will be added in the next step.',
                    style: AppTextStyles.body,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminSheet extends StatelessWidget {
  final String title;
  final Widget child;

  const _AdminSheet({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: 12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontFamily: AppFonts.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminPieChart extends StatelessWidget {
  final List<_ChartSegment> segments;
  final int total;

  const _AdminPieChart({required this.segments, required this.total});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: const Size.square(156),
          painter: _AdminPiePainter(
            segments: segments.where((segment) => segment.value > 0).toList(),
            total: total,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$total',
              style: const TextStyle(
                color: AppColors.darkText,
                fontFamily: AppFonts.primary,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Text('users'),
          ],
        ),
      ],
    );
  }
}

class _AdminPiePainter extends CustomPainter {
  final List<_ChartSegment> segments;
  final int total;

  const _AdminPiePainter({required this.segments, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final backgroundPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round
      ..color = Colors.grey.shade200;
    canvas.drawArc(rect, 0, math.pi * 2, false, backgroundPaint);
    if (total <= 0) return;
    var startAngle = -math.pi / 2;
    for (final segment in segments) {
      final sweep = (segment.value / total) * math.pi * 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round
        ..color = segment.color;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _AdminPiePainter oldDelegate) {
    return oldDelegate.segments != segments || oldDelegate.total != total;
  }
}

class _AdminBarChart extends StatelessWidget {
  final List<_BarValue> bars;
  final String emptyText;

  const _AdminBarChart({required this.bars, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    final visible = bars.where((bar) => bar.value > 0).toList();
    if (visible.isEmpty) {
      return Text(emptyText, style: AppTextStyles.body);
    }
    final maxValue = visible.fold<int>(
      0,
      (max, bar) => math.max(max, bar.value),
    );
    return Column(
      children: visible.map((bar) {
        final factor = maxValue == 0 ? 0.0 : bar.value / maxValue;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bar.label,
                      style: const TextStyle(
                        color: AppColors.darkText,
                        fontFamily: AppFonts.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(formatKyat(bar.value.toDouble())),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 12,
                  value: factor.clamp(0, 1),
                  color: bar.color,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ChartSegment {
  final String label;
  final int value;
  final Color color;

  const _ChartSegment(this.label, this.value, this.color);
}

class _BarValue {
  final String label;
  final int value;
  final Color color;

  const _BarValue(this.label, this.value, this.color);
}

class _AdminStats {
  final int totalUsers;
  final int totalBrands;
  final int activeVendors;
  final int pendingPlanOrders;
  final int openReports;
  final int planRevenue;
  final int orderRevenue;
  final List<_ChartSegment> userSegments;
  final List<_BarValue> revenueBars;
  final List<_BarValue> orderRevenueBars;

  const _AdminStats({
    required this.totalUsers,
    required this.totalBrands,
    required this.activeVendors,
    required this.pendingPlanOrders,
    required this.openReports,
    required this.planRevenue,
    required this.orderRevenue,
    required this.userSegments,
    required this.revenueBars,
    required this.orderRevenueBars,
  });

  factory _AdminStats.empty() {
    return const _AdminStats(
      totalUsers: 0,
      totalBrands: 0,
      activeVendors: 0,
      pendingPlanOrders: 0,
      openReports: 0,
      planRevenue: 0,
      orderRevenue: 0,
      userSegments: <_ChartSegment>[],
      revenueBars: <_BarValue>[],
      orderRevenueBars: <_BarValue>[],
    );
  }

  factory _AdminStats.fromRows({
    required List<Map<String, dynamic>> users,
    required List<Map<String, dynamic>> orders,
    required List<Map<String, dynamic>> planOrders,
    required List<Map<String, dynamic>> vendors,
    required List<Map<String, dynamic>> reports,
    required List<Map<String, dynamic>> brands,
  }) {
    final customers = users.where((u) => u['user_type'] == 'customer').length;
    final vendorUsers = users.where((u) => u['user_type'] == 'vendor').length;
    final admins = users.where((u) => u['user_type'] == 'admin').length;
    final approvedPlanOrders = planOrders
        .where((order) => order['status'] == 'approved')
        .toList();
    final planRevenue = approvedPlanOrders.fold<int>(
      0,
      (sum, order) => sum + ((order['amount_mmk'] as num?)?.toInt() ?? 0),
    );
    final orderRevenue = orders
        .where((order) => order['status'] == 'completed')
        .fold<int>(
          0,
          (sum, order) => sum + ((order['total_price'] as num?)?.toInt() ?? 0),
        );
    final revenueByPlan = <String, int>{};
    for (final order in approvedPlanOrders) {
      final code = order['plan_code']?.toString() ?? 'unknown';
      revenueByPlan[code] =
          (revenueByPlan[code] ?? 0) +
          ((order['amount_mmk'] as num?)?.toInt() ?? 0);
    }
    final orderRevenueByStatus = <String, int>{};
    for (final order in orders) {
      final status = order['status']?.toString() ?? 'unknown';
      orderRevenueByStatus[status] =
          (orderRevenueByStatus[status] ?? 0) +
          ((order['total_price'] as num?)?.toInt() ?? 0);
    }

    return _AdminStats(
      totalUsers: users.length,
      totalBrands: brands.length,
      activeVendors: vendors
          .where((v) => v['subscription_status'] == 'active')
          .length,
      pendingPlanOrders: planOrders
          .where(
            (order) =>
                order['status'] == 'pending' || order['status'] == 'submitted',
          )
          .length,
      openReports: reports.where((report) => report['status'] == 'open').length,
      planRevenue: planRevenue,
      orderRevenue: orderRevenue,
      userSegments: [
        _ChartSegment('Customers', customers, Colors.blue.shade700),
        _ChartSegment('Vendors', vendorUsers, AppColors.primaryGreen),
        _ChartSegment('Admins', admins, Colors.deepOrange.shade700),
      ],
      revenueBars: revenueByPlan.entries
          .map(
            (entry) =>
                _BarValue(entry.key, entry.value, AppColors.primaryGreen),
          )
          .toList(),
      orderRevenueBars: orderRevenueByStatus.entries
          .map(
            (entry) => _BarValue(entry.key, entry.value, Colors.blue.shade700),
          )
          .toList(),
    );
  }
}

class _PlanOrder {
  final String id;
  final String vendorId;
  final String planCode;
  final String planName;
  final int? productLimit;
  final int amountMmk;
  final String status;
  final String screenshotUrl;
  final String vendorLabel;
  final String paymentMethodLabel;

  const _PlanOrder({
    required this.id,
    required this.vendorId,
    required this.planCode,
    required this.planName,
    required this.productLimit,
    required this.amountMmk,
    required this.status,
    required this.screenshotUrl,
    required this.vendorLabel,
    required this.paymentMethodLabel,
  });

  factory _PlanOrder.fromRows(
    Map<String, dynamic> row,
    Map<String, dynamic>? vendor,
    Map<String, dynamic>? plan,
    Map<String, dynamic>? method,
    Map<String, dynamic>? brand,
  ) {
    final brandName = brand?['brand_name']?.toString();
    final phone = vendor?['phone']?.toString();
    return _PlanOrder(
      id: row['id']?.toString() ?? '',
      vendorId: row['vendor_id']?.toString() ?? '',
      planCode: row['plan_code']?.toString() ?? '',
      planName: plan?['name']?.toString() ?? row['plan_code']?.toString() ?? '',
      productLimit: (plan?['product_limit'] as num?)?.toInt(),
      amountMmk: (row['amount_mmk'] as num?)?.toInt() ?? 0,
      status: row['status']?.toString() ?? 'pending',
      screenshotUrl: row['payment_screenshot_url']?.toString() ?? '',
      vendorLabel: brandName?.isNotEmpty == true
          ? brandName!
          : phone?.isNotEmpty == true
          ? phone!
          : 'Vendor ${row['vendor_id']}',
      paymentMethodLabel:
          method?['name']?.toString() ??
          row['payment_method_id']?.toString() ??
          '-',
    );
  }
}

class _AdminBrand {
  final String id;
  final String name;
  final String logoUrl;
  final String phone;
  final String planCode;
  final String planLabel;
  final String subscriptionStatus;
  final int productCount;

  const _AdminBrand({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.phone,
    required this.planCode,
    required this.planLabel,
    required this.subscriptionStatus,
    required this.productCount,
  });

  factory _AdminBrand.fromRows(
    Map<String, dynamic> brand,
    Map<String, dynamic>? vendor,
    int productCount,
  ) {
    final planCode = vendor?['current_plan_code']?.toString() ?? 'free';
    final status = vendor?['subscription_status']?.toString() ?? 'free';
    return _AdminBrand(
      id: brand['id']?.toString() ?? '',
      name: brand['brand_name']?.toString() ?? 'Untitled Brand',
      logoUrl: brand['logo_url']?.toString() ?? '',
      phone: vendor?['phone']?.toString() ?? 'No phone',
      planCode: status == 'trial' ? 'trial' : planCode,
      planLabel: status == 'trial' ? 'Starter Trial' : planCode,
      subscriptionStatus: status,
      productCount: productCount,
    );
  }
}

class _AdminReport {
  final String id;
  final String reportType;
  final String reason;
  final String details;
  final String status;

  const _AdminReport({
    required this.id,
    required this.reportType,
    required this.reason,
    required this.details,
    required this.status,
  });

  factory _AdminReport.fromRow(Map<String, dynamic> row) {
    return _AdminReport(
      id: row['id']?.toString() ?? '',
      reportType: row['report_type']?.toString() ?? 'report',
      reason: row['reason']?.toString() ?? '',
      details: row['details']?.toString() ?? '',
      status: row['status']?.toString() ?? 'open',
    );
  }
}

class _AdminPaymentMethod {
  final String id;
  final String name;
  final String accountName;
  final String accountNumber;
  final String qrImageUrl;
  final String instructions;
  final bool isActive;

  const _AdminPaymentMethod({
    required this.id,
    required this.name,
    required this.accountName,
    required this.accountNumber,
    required this.qrImageUrl,
    required this.instructions,
    required this.isActive,
  });

  factory _AdminPaymentMethod.fromRow(Map<String, dynamic> row) {
    return _AdminPaymentMethod(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? 'Payment',
      accountName: row['account_name']?.toString() ?? '',
      accountNumber: row['account_number']?.toString() ?? '',
      qrImageUrl: row['qr_image_url']?.toString() ?? '',
      instructions: row['instructions']?.toString() ?? '',
      isActive: row['is_active'] as bool? ?? false,
    );
  }
}

class _AdminPlan {
  final String code;
  final String name;
  final int? priceMmk;
  final int? productLimit;
  final bool isPaid;
  final bool analyticsEnabled;
  final bool isActive;
  final List<String> features;

  const _AdminPlan({
    required this.code,
    required this.name,
    required this.priceMmk,
    required this.productLimit,
    required this.isPaid,
    required this.analyticsEnabled,
    required this.isActive,
    required this.features,
  });

  factory _AdminPlan.fromRow(Map<String, dynamic> row) {
    final rawFeatures = row['features'];
    return _AdminPlan(
      code: row['code']?.toString() ?? '',
      name: row['name']?.toString() ?? 'Plan',
      priceMmk: (row['price_mmk'] as num?)?.toInt(),
      productLimit: (row['product_limit'] as num?)?.toInt(),
      isPaid: row['is_paid'] as bool? ?? false,
      analyticsEnabled: row['analytics_enabled'] as bool? ?? false,
      isActive: row['is_active'] as bool? ?? false,
      features: rawFeatures is List
          ? rawFeatures.map((item) => item.toString()).toList()
          : const <String>[],
    );
  }
}
