import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_user_service.dart';
import '../auth/signin_screen.dart';
import '../customer/home_screen.dart';
import '../product/product_review_service.dart';
import '../theme_config.dart';
import '../utils/payment_assets.dart';
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
  List<String> _paymentTypes = const <String>[];

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
        _loadPaymentTypes(),
      ]);
      if (!mounted) return;
      setState(() {
        _planOrders = results[0] as List<_PlanOrder>;
        _brands = results[1] as List<_AdminBrand>;
        _reports = results[2] as List<_AdminReport>;
        _paymentMethods = results[3] as List<_AdminPaymentMethod>;
        _plans = results[4] as List<_AdminPlan>;
        _stats = results[5] as _AdminStats;
        _paymentTypes = results[6] as List<String>;
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
    final reports = <_AdminReport>[];
    for (final row in (rows as List<dynamic>).cast<Map<String, dynamic>>()) {
      final reporter = await _loadReportReporter(
        row['reporter_id']?.toString(),
      );
      final target = await _loadReportTarget(row);
      reports.add(
        _AdminReport.fromRow(row, reporter: reporter, target: target),
      );
    }
    return reports;
  }

  Future<_ReportContext> _loadReportReporter(String? reporterId) async {
    final id = reporterId?.trim() ?? '';
    if (id.isEmpty) {
      return const _ReportContext(label: 'Unknown reporter');
    }

    Map<String, dynamic>? profile;
    Map<String, dynamic>? user;
    try {
      profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name,username')
          .eq('id', id)
          .maybeSingle();
    } catch (_) {}
    try {
      user = await Supabase.instance.client
          .from('users')
          .select('email,user_type')
          .eq('id', id)
          .maybeSingle();
    } catch (_) {}

    final fullName = profile?['full_name']?.toString().trim() ?? '';
    final username = profile?['username']?.toString().trim() ?? '';
    final email = user?['email']?.toString().trim() ?? '';
    final userType = user?['user_type']?.toString().trim() ?? '';
    final label = fullName.isNotEmpty
        ? fullName
        : username.isNotEmpty
        ? '@$username'
        : email.isNotEmpty
        ? email
        : 'User ${_shortId(id)}';
    final meta = [
      if (username.isNotEmpty && !label.contains(username)) '@$username',
      if (email.isNotEmpty && email != label) email,
      if (userType.isNotEmpty) userType,
      'ID ${_shortId(id)}',
    ].join(' • ');
    return _ReportContext(label: label, meta: meta);
  }

  Future<_ReportContext> _loadReportTarget(Map<String, dynamic> row) async {
    final type = row['report_type']?.toString() ?? '';
    if (type == 'product') {
      final productId = row['product_id']?.toString() ?? '';
      if (productId.isEmpty) {
        return const _ReportContext(label: 'Missing product');
      }
      try {
        final product = await Supabase.instance.client
            .from('products')
            .select('title,brands(brand_name)')
            .eq('id', productId)
            .maybeSingle();
        final title = product?['title']?.toString().trim() ?? '';
        final brand =
            ((product?['brands'] as Map?)?['brand_name']?.toString() ?? '')
                .trim();
        return _ReportContext(
          label: title.isEmpty ? 'Product ${_shortId(productId)}' : title,
          meta: [
            if (brand.isNotEmpty) brand,
            'Product ID ${_shortId(productId)}',
          ].join(' • '),
        );
      } catch (_) {
        return _ReportContext(
          label: 'Product ${_shortId(productId)}',
          meta: productId,
        );
      }
    }

    final chatId = row['chat_id']?.toString() ?? '';
    if (chatId.isEmpty) {
      return const _ReportContext(label: 'Missing chat');
    }
    try {
      final chat = await Supabase.instance.client
          .from('chats')
          .select('type,name,last_message_text,last_message_at')
          .eq('id', chatId)
          .maybeSingle();
      final members = await Supabase.instance.client
          .from('chat_members')
          .select('user_id')
          .eq('chat_id', chatId);
      final memberIds = (members as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((member) => member['user_id']?.toString())
          .whereType<String>()
          .toList();
      final memberLabels = await _loadReportMemberLabels(memberIds);
      final name = chat?['name']?.toString().trim() ?? '';
      final typeLabel = chat?['type']?.toString().trim() ?? 'chat';
      final label = name.isNotEmpty
          ? name
          : memberLabels.isEmpty
          ? 'Chat ${_shortId(chatId)}'
          : memberLabels.take(3).join(', ');
      final lastMessage = chat?['last_message_text']?.toString().trim() ?? '';
      return _ReportContext(
        label: label,
        meta: [
          typeLabel,
          '${memberIds.length} members',
          if (lastMessage.isNotEmpty) 'Last: $lastMessage',
          'Chat ID ${_shortId(chatId)}',
        ].join(' • '),
      );
    } catch (_) {
      return _ReportContext(label: 'Chat ${_shortId(chatId)}', meta: chatId);
    }
  }

  Future<List<String>> _loadReportMemberLabels(List<String> memberIds) async {
    if (memberIds.isEmpty) return const <String>[];
    final profilesById = <String, String>{};
    final brandsByOwner = <String, String>{};
    try {
      final profiles = await Supabase.instance.client
          .from('profiles')
          .select('id,full_name,username')
          .inFilter('id', memberIds);
      for (final row
          in (profiles as List<dynamic>).cast<Map<String, dynamic>>()) {
        final id = row['id']?.toString();
        if (id == null) continue;
        final fullName = row['full_name']?.toString().trim() ?? '';
        final username = row['username']?.toString().trim() ?? '';
        profilesById[id] = fullName.isNotEmpty
            ? fullName
            : username.isNotEmpty
            ? '@$username'
            : 'User ${_shortId(id)}';
      }
    } catch (_) {}
    try {
      final brands = await Supabase.instance.client
          .from('brands')
          .select('owner_id,brand_name')
          .inFilter('owner_id', memberIds);
      for (final row
          in (brands as List<dynamic>).cast<Map<String, dynamic>>()) {
        final ownerId = row['owner_id']?.toString();
        final brandName = row['brand_name']?.toString().trim() ?? '';
        if (ownerId != null && brandName.isNotEmpty) {
          brandsByOwner[ownerId] = brandName;
        }
      }
    } catch (_) {}
    return memberIds
        .map(
          (id) =>
              brandsByOwner[id] ?? profilesById[id] ?? 'User ${_shortId(id)}',
        )
        .toList();
  }

  static String _shortId(String id) {
    final clean = id.trim();
    if (clean.length <= 8) return clean;
    return clean.substring(0, 8);
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

  Future<List<String>> _loadPaymentTypes() async {
    final rows = await AuthUserService.getPaymentTypes();
    return rows
        .map((row) => row['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
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
    final accountNameController = TextEditingController(
      text: method?.accountName ?? '',
    );
    final accountNumberController = TextEditingController(
      text: method?.accountNumber ?? '',
    );
    final paymentTypes = <String>{
      ..._paymentTypes,
      if (method?.name.trim().isNotEmpty == true) method!.name,
    }.toList();
    String? selectedPaymentType = method?.name;
    if (selectedPaymentType != null &&
        !paymentTypes.contains(selectedPaymentType)) {
      selectedPaymentType = null;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> save() async {
              final name = selectedPaymentType?.trim() ?? '';
              if (name.isEmpty) return;
              final payload = {
                'name': name,
                'account_name': accountNameController.text.trim(),
                'account_number': accountNumberController.text.trim(),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _paymentTypeDropdown(
                    paymentTypes,
                    selectedPaymentType,
                    (value) => setSheetState(() => selectedPaymentType = value),
                  ),
                  const SizedBox(height: 12),
                  _sheetField(accountNameController, 'Account name'),
                  _sheetField(accountNumberController, 'Account number'),
                  const SizedBox(height: 10),
                  _sheetSaveButton(save, 'Save Payment Method'),
                ],
              ),
            );
          },
        );
      },
    );

    accountNameController.dispose();
    accountNumberController.dispose();
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

  Widget _paymentIconWidget(String type) {
    final asset = paymentTypeAsset(type);
    if (asset != null) {
      return Image.asset(asset, fit: BoxFit.contain);
    }
    return const Icon(
      CupertinoIcons.creditcard,
      color: AppColors.primaryGreen,
      size: 24,
    );
  }

  Widget _paymentTypeDropdown(
    List<String> paymentTypes,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.lightGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
      hint: const Text('Select payment type'),
      items: paymentTypes.map((type) {
        return DropdownMenuItem(
          value: type,
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: _paymentIconWidget(type),
                ),
              ),
              const SizedBox(width: 12),
              Text(type),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
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
            _metricCard(
              'Users',
              '${_stats.totalUsers}',
              'Customers and vendors',
            ),
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
                builder: (_) => _AdminBrandDetailScreen(brand: brand),
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
          _reportDetailRow(
            icon: CupertinoIcons.person,
            label: 'Reported by',
            value: report.reporterLabel,
            detail: report.reporterMeta,
          ),
          const SizedBox(height: 8),
          _reportDetailRow(
            icon: report.reportType == 'chat'
                ? CupertinoIcons.chat_bubble_2
                : CupertinoIcons.cube_box,
            label: 'Target',
            value: report.targetLabel,
            detail: report.targetMeta,
          ),
          const SizedBox(height: 8),
          _reportDetailRow(
            icon: CupertinoIcons.exclamationmark_circle,
            label: 'Reason',
            value: report.reason.isEmpty ? 'No reason provided' : report.reason,
          ),
          if (report.details.isNotEmpty) ...[
            const SizedBox(height: 8),
            _reportDetailRow(
              icon: CupertinoIcons.text_alignleft,
              label: 'Details',
              value: report.details,
            ),
          ],
          const SizedBox(height: 8),
          _reportDetailRow(
            icon: CupertinoIcons.calendar,
            label: 'Submitted',
            value: report.createdAtLabel,
            detail: 'Report ID ${_shortId(report.id)}',
          ),
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

  Widget _reportDetailRow({
    required IconData icon,
    required String label,
    required String value,
    String detail = '',
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.subtleText),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.subtleText,
                  fontFamily: AppFonts.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.darkText,
                  fontFamily: AppFonts.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (detail.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppColors.subtleText,
                    fontFamily: AppFonts.primary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _paymentIconWidget(method.name),
            ),
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

class _AdminBrandDetailScreen extends StatefulWidget {
  final _AdminBrand brand;

  const _AdminBrandDetailScreen({required this.brand});

  @override
  State<_AdminBrandDetailScreen> createState() =>
      _AdminBrandDetailScreenState();
}

class _AdminBrandDetailScreenState extends State<_AdminBrandDetailScreen> {
  late Future<_AdminBrandDetailSnapshot> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetail();
  }

  Future<void> _refresh() async {
    final future = _loadDetail();
    setState(() => _detailFuture = future);
    await future;
  }

  Future<_AdminBrandDetailSnapshot> _loadDetail() async {
    final client = Supabase.instance.client;
    final brandId = widget.brand.id;

    final productRows = await client
        .from('products')
        .select(
          'id,title,description,base_price,created_at,plan_locked,'
          'categories(name),audiences(name),'
          'product_variants(id,size,color,stock_quantity,price_adjustment,'
          'promo_price,image_url,sku)',
        )
        .eq('brand_id', brandId)
        .order('created_at', ascending: false);

    final products = <String, _AdminBrandProductInfo>{};
    for (final row
        in (productRows as List<dynamic>).cast<Map<String, dynamic>>()) {
      final product = _AdminBrandProductInfo.fromProductRow(row);
      products[product.id] = product;
    }

    List<Map<String, dynamic>> orderItemRows = const <Map<String, dynamic>>[];
    try {
      final rows = await client
          .from('order_items')
          .select(
            'quantity,price_at_purchase,brand_id,'
            'orders!inner(id,status,total_price,created_at),'
            'product_variants(id,products!inner(id,title))',
          )
          .eq('brand_id', brandId)
          .order('created_at', referencedTable: 'orders', ascending: false);
      orderItemRows = (rows as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (_) {}

    List<Map<String, dynamic>> viewRows = const <Map<String, dynamic>>[];
    try {
      final rows = await client
          .from('product_views')
          .select('product_id,viewer_id,session_id')
          .eq('brand_id', brandId);
      viewRows = (rows as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (_) {}

    final reviewSummaries = await ProductReviewService.instance
        .loadSummariesForProducts(products.keys.toList());

    final orderStatusCounts = <String, int>{};
    var totalOrders = 0;
    var salesOrders = 0;
    var productsSold = 0;
    var totalRevenue = 0.0;

    final brandOrderIds = <String>{};
    for (final item in orderItemRows) {
      final order = item['orders'] as Map<String, dynamic>?;
      if (order == null) continue;
      final orderId = order['id']?.toString() ?? '';
      final isNewOrder = orderId.isNotEmpty && brandOrderIds.add(orderId);
      final status = order['status']?.toString() ?? 'pending';
      final normalized = _normalizeOrderStatus(status);
      final countsRevenue = _isRevenueStatus(status);
      if (isNewOrder) {
        totalOrders++;
        orderStatusCounts[normalized] =
            (orderStatusCounts[normalized] ?? 0) + 1;
        if (countsRevenue) salesOrders++;
      }

      if (item['brand_id']?.toString() != brandId) continue;
      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      final price = (item['price_at_purchase'] as num?)?.toDouble() ?? 0;
      final revenue = countsRevenue ? quantity * price : 0.0;
      final variant = item['product_variants'] as Map<String, dynamic>?;
      final productRow = variant?['products'] as Map<String, dynamic>?;
      final productId = productRow?['id']?.toString();
      if (productId == null || productId.isEmpty) continue;

      final product = products.putIfAbsent(
        productId,
        () => _AdminBrandProductInfo.placeholder(
          id: productId,
          title: productRow?['title']?.toString() ?? 'Product',
        ),
      );
      product.orderCountIds.add(orderId);
      product.quantityOrdered += quantity;
      product.grossRevenue += revenue;
      productsSold += countsRevenue ? quantity : 0;
      totalRevenue += revenue;
    }

    for (final row in viewRows) {
      final productId = row['product_id']?.toString();
      if (productId == null || productId.isEmpty) continue;
      final product = products[productId];
      if (product == null) continue;
      product.views++;
      final viewerId = row['viewer_id']?.toString();
      final sessionId = row['session_id']?.toString();
      if (viewerId != null && viewerId.isNotEmpty) {
        product.uniqueViewKeys.add(viewerId);
      } else if (sessionId != null && sessionId.isNotEmpty) {
        product.uniqueViewKeys.add(sessionId);
      }
    }

    for (final entry in reviewSummaries.entries) {
      final product = products[entry.key];
      if (product == null) continue;
      product.reviewCount = entry.value.reviewCount;
      product.averageRating = entry.value.averageRating;
    }

    final productList = products.values.toList()
      ..sort((a, b) {
        final orderedCompare = b.quantityOrdered.compareTo(a.quantityOrdered);
        if (orderedCompare != 0) return orderedCompare;
        final revenueCompare = b.grossRevenue.compareTo(a.grossRevenue);
        if (revenueCompare != 0) return revenueCompare;
        final viewCompare = b.views.compareTo(a.views);
        if (viewCompare != 0) return viewCompare;
        return a.title.compareTo(b.title);
      });

    final lowStock =
        productList
            .where((product) => product.lowStockVariantCount > 0)
            .toList()
          ..sort((a, b) => a.totalStock.compareTo(b.totalStock));

    return _AdminBrandDetailSnapshot(
      products: productList,
      lowStockProducts: lowStock,
      totalOrders: totalOrders,
      salesOrders: salesOrders,
      productsSold: productsSold,
      totalRevenue: totalRevenue,
      productViews: viewRows.length,
      orderStatusCounts: orderStatusCounts,
    );
  }

  static bool _isRevenueStatus(String status) {
    final value = status.trim().toLowerCase();
    return value == 'confirmed' ||
        value == 'confirm' ||
        value == 'in-delivery' ||
        value == 'in_delivery' ||
        value == 'in delivery' ||
        value == 'completed' ||
        value == 'delivered' ||
        value == 'arrived';
  }

  static String _normalizeOrderStatus(String status) {
    switch (status.trim().toLowerCase()) {
      case 'confirmed':
      case 'confirm':
        return 'confirmed';
      case 'in-delivery':
      case 'in_delivery':
      case 'in delivery':
        return 'in-delivery';
      case 'completed':
      case 'delivered':
      case 'arrived':
        return 'completed';
      case 'cancel':
      case 'canceled':
      case 'cancelled':
        return 'canceled';
      case 'refund':
      case 'refunded':
        return 'refund';
      default:
        return 'pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        title: Text(widget.brand.name, style: AppTextStyles.appBarTitle),
      ),
      body: SafeArea(
        child: FutureBuilder<_AdminBrandDetailSnapshot>(
          future: _detailFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CustomLoadingCenter();
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Unable to load brand product details.',
                        style: AppTextStyles.body,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final detail = snapshot.data ?? _AdminBrandDetailSnapshot.empty();
            final topProduct = detail.products.isEmpty
                ? null
                : detail.products.first;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _brandHeader(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _detailMetric(
                        'Products',
                        '${detail.products.length}',
                        'Listed items',
                      ),
                      const SizedBox(width: 10),
                      _detailMetric(
                        'Orders',
                        '${detail.totalOrders}',
                        '${detail.salesOrders} sales',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _detailMetric(
                        'Sold',
                        '${detail.productsSold}',
                        'Units ordered',
                      ),
                      const SizedBox(width: 10),
                      _detailMetric(
                        'Revenue',
                        formatKyat(detail.totalRevenue),
                        'Confirmed + delivered',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _detailMetric(
                        'Views',
                        '${detail.productViews}',
                        'Product opens',
                      ),
                      const SizedBox(width: 10),
                      _detailMetric(
                        'Low Stock',
                        '${detail.lowStockProducts.length}',
                        'Needs attention',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _topProductPanel(topProduct),
                  const SizedBox(height: 16),
                  _orderStatusPanel(detail.orderStatusCounts),
                  const SizedBox(height: 16),
                  _productPerformancePanel(detail.products),
                  const SizedBox(height: 16),
                  _lowStockPanel(detail.lowStockProducts),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _brandHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _brandAvatar(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.brand.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontFamily: AppFonts.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.brand.planLabel} • ${widget.brand.phone}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandAvatar() {
    final initial = widget.brand.name.trim().isEmpty
        ? 'B'
        : widget.brand.name.trim()[0].toUpperCase();
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: widget.brand.logoUrl.isEmpty
          ? Container(
              width: 68,
              height: 68,
              color: AppColors.lightGrey,
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppColors.primaryGreen,
                  fontFamily: AppFonts.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : Image.network(
              widget.brand.logoUrl,
              width: 68,
              height: 68,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 68,
                height: 68,
                color: AppColors.lightGrey,
                alignment: Alignment.center,
                child: Text(initial),
              ),
            ),
    );
  }

  Widget _detailMetric(String title, String value, String subtitle) {
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

  Widget _topProductPanel(_AdminBrandProductInfo? product) {
    return _detailPanel(
      title: 'Most Ordered Item',
      child: product == null || product.quantityOrdered == 0
          ? const Text('No ordered products yet.', style: AppTextStyles.body)
          : _productRow(product, showRank: false),
    );
  }

  Widget _orderStatusPanel(Map<String, int> counts) {
    final statuses = [
      'pending',
      'confirmed',
      'in-delivery',
      'completed',
      'canceled',
      'refund',
    ];
    return _detailPanel(
      title: 'Order Status',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: statuses
            .map((status) => _statusChip(status, counts[status] ?? 0))
            .toList(),
      ),
    );
  }

  Widget _productPerformancePanel(List<_AdminBrandProductInfo> products) {
    return _detailPanel(
      title: 'Product Performance',
      child: products.isEmpty
          ? const Text(
              'No products found for this brand.',
              style: AppTextStyles.body,
            )
          : Column(
              children: products
                  .asMap()
                  .entries
                  .map((entry) => _productRow(entry.value, rank: entry.key + 1))
                  .toList(),
            ),
    );
  }

  Widget _lowStockPanel(List<_AdminBrandProductInfo> products) {
    return _detailPanel(
      title: 'Low Stock Products',
      child: products.isEmpty
          ? const Text('No low-stock products.', style: AppTextStyles.body)
          : Column(
              children: products
                  .take(8)
                  .map((product) => _productRow(product, showSales: false))
                  .toList(),
            ),
    );
  }

  Widget _detailPanel({required String title, required Widget child}) {
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
          Text(
            title,
            style: const TextStyle(
              color: AppColors.darkText,
              fontFamily: AppFonts.primary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _statusChip(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: AppColors.darkText,
          fontFamily: AppFonts.primary,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _productRow(
    _AdminBrandProductInfo product, {
    int? rank,
    bool showRank = true,
    bool showSales = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showRank && rank != null) ...[
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: AppColors.primaryGreen,
                  fontFamily: AppFonts.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: product.imageUrl.isEmpty
                ? Container(
                    width: 58,
                    height: 58,
                    color: AppColors.lightGrey,
                    child: const Icon(
                      CupertinoIcons.cube_box,
                      color: AppColors.subtleText,
                    ),
                  )
                : Image.network(
                    product.imageUrl,
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 58,
                      height: 58,
                      color: AppColors.lightGrey,
                      child: const Icon(CupertinoIcons.cube_box),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontFamily: AppFonts.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.categoryLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.subtleText,
                    fontFamily: AppFonts.primary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _miniStat('${product.totalStock} stock'),
                    _miniStat('${product.variantCount} variants'),
                    _miniStat('${product.views} views'),
                    _miniStat(
                      '${product.averageRating.toStringAsFixed(1)} stars',
                    ),
                  ],
                ),
                if (showSales) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${product.quantityOrdered} sold • '
                    '${product.orderCount} orders • '
                    '${formatKyat(product.grossRevenue)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontFamily: AppFonts.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.subtleText,
          fontFamily: AppFonts.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AdminBrandDetailSnapshot {
  final List<_AdminBrandProductInfo> products;
  final List<_AdminBrandProductInfo> lowStockProducts;
  final int totalOrders;
  final int salesOrders;
  final int productsSold;
  final double totalRevenue;
  final int productViews;
  final Map<String, int> orderStatusCounts;

  const _AdminBrandDetailSnapshot({
    required this.products,
    required this.lowStockProducts,
    required this.totalOrders,
    required this.salesOrders,
    required this.productsSold,
    required this.totalRevenue,
    required this.productViews,
    required this.orderStatusCounts,
  });

  factory _AdminBrandDetailSnapshot.empty() {
    return const _AdminBrandDetailSnapshot(
      products: <_AdminBrandProductInfo>[],
      lowStockProducts: <_AdminBrandProductInfo>[],
      totalOrders: 0,
      salesOrders: 0,
      productsSold: 0,
      totalRevenue: 0,
      productViews: 0,
      orderStatusCounts: <String, int>{},
    );
  }
}

class _AdminBrandProductInfo {
  static const int lowStockThreshold = 10;

  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String category;
  final String audience;
  final double minPrice;
  final double maxPrice;
  final int variantCount;
  final int totalStock;
  final int lowStockVariantCount;
  final bool planLocked;
  final DateTime? createdAt;
  final Set<String> orderCountIds = {};
  final Set<String> uniqueViewKeys = {};

  int quantityOrdered = 0;
  double grossRevenue = 0;
  int views = 0;
  int reviewCount = 0;
  double averageRating = 0;

  _AdminBrandProductInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.category,
    required this.audience,
    required this.minPrice,
    required this.maxPrice,
    required this.variantCount,
    required this.totalStock,
    required this.lowStockVariantCount,
    required this.planLocked,
    required this.createdAt,
  });

  int get orderCount => orderCountIds.length;

  String get categoryLabel {
    final parts = [
      if (category.isNotEmpty) category,
      if (audience.isNotEmpty) audience,
      if (planLocked) 'Plan locked',
    ];
    return parts.isEmpty ? 'Uncategorized' : parts.join(' • ');
  }

  factory _AdminBrandProductInfo.placeholder({
    required String id,
    required String title,
  }) {
    return _AdminBrandProductInfo(
      id: id,
      title: title,
      description: '',
      imageUrl: '',
      category: '',
      audience: '',
      minPrice: 0,
      maxPrice: 0,
      variantCount: 0,
      totalStock: 0,
      lowStockVariantCount: 0,
      planLocked: false,
      createdAt: null,
    );
  }

  factory _AdminBrandProductInfo.fromProductRow(Map<String, dynamic> row) {
    final basePrice = (row['base_price'] as num?)?.toDouble() ?? 0;
    final variants =
        (row['product_variants'] as List<dynamic>? ?? const <dynamic>[])
            .cast<Map<String, dynamic>>();
    final prices = <double>[];
    var totalStock = 0;
    var lowStockCount = 0;
    var imageUrl = '';

    for (final variant in variants) {
      final adjustment = (variant['price_adjustment'] as num?)?.toDouble() ?? 0;
      final regularPrice = basePrice + adjustment;
      final promoPrice = (variant['promo_price'] as num?)?.toDouble();
      final price = promoPrice != null && promoPrice > 0
          ? promoPrice
          : regularPrice;
      prices.add(price);

      final stock = (variant['stock_quantity'] as num?)?.toInt() ?? 0;
      totalStock += stock;
      if (stock <= lowStockThreshold) lowStockCount++;

      final candidateImage = variant['image_url']?.toString() ?? '';
      if (imageUrl.isEmpty && candidateImage.isNotEmpty) {
        imageUrl = candidateImage;
      }
    }

    final category = ((row['categories'] as Map?)?['name']?.toString() ?? '')
        .trim();
    final audience = ((row['audiences'] as Map?)?['name']?.toString() ?? '')
        .trim();
    final createdAtText = row['created_at']?.toString();

    return _AdminBrandProductInfo(
      id: row['id']?.toString() ?? '',
      title: row['title']?.toString() ?? 'Untitled Product',
      description: row['description']?.toString() ?? '',
      imageUrl: imageUrl,
      category: category,
      audience: audience,
      minPrice: prices.isEmpty ? basePrice : prices.reduce(math.min),
      maxPrice: prices.isEmpty ? basePrice : prices.reduce(math.max),
      variantCount: variants.length,
      totalStock: totalStock,
      lowStockVariantCount: lowStockCount,
      planLocked: row['plan_locked'] as bool? ?? false,
      createdAt: createdAtText == null || createdAtText.isEmpty
          ? null
          : DateTime.tryParse(createdAtText)?.toLocal(),
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
    final activeUsers = customers + vendorUsers;
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
      totalUsers: activeUsers,
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
  final String reporterId;
  final String reporterLabel;
  final String reporterMeta;
  final String targetId;
  final String targetLabel;
  final String targetMeta;
  final String reason;
  final String details;
  final String status;
  final DateTime? createdAt;

  const _AdminReport({
    required this.id,
    required this.reportType,
    required this.reporterId,
    required this.reporterLabel,
    required this.reporterMeta,
    required this.targetId,
    required this.targetLabel,
    required this.targetMeta,
    required this.reason,
    required this.details,
    required this.status,
    required this.createdAt,
  });

  String get createdAtLabel {
    final date = createdAt;
    if (date == null) return 'Unknown date';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} • $hour:$minute $suffix';
  }

  factory _AdminReport.fromRow(
    Map<String, dynamic> row, {
    required _ReportContext reporter,
    required _ReportContext target,
  }) {
    final reportType = row['report_type']?.toString() ?? 'report';
    final targetId = reportType == 'chat'
        ? row['chat_id']?.toString() ?? ''
        : row['product_id']?.toString() ?? '';
    final createdAtText = row['created_at']?.toString();
    return _AdminReport(
      id: row['id']?.toString() ?? '',
      reportType: reportType,
      reporterId: row['reporter_id']?.toString() ?? '',
      reporterLabel: reporter.label,
      reporterMeta: reporter.meta,
      targetId: targetId,
      targetLabel: target.label,
      targetMeta: target.meta,
      reason: row['reason']?.toString() ?? '',
      details: row['details']?.toString() ?? '',
      status: row['status']?.toString() ?? 'open',
      createdAt: createdAtText == null || createdAtText.isEmpty
          ? null
          : DateTime.tryParse(createdAtText)?.toLocal(),
    );
  }
}

class _ReportContext {
  final String label;
  final String meta;

  const _ReportContext({required this.label, this.meta = ''});
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
