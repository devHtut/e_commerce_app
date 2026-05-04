import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_user_service.dart';
import '../home/home_screen.dart';
import '../order/order_service.dart';
import '../theme_config.dart';
import 'cart_item.dart';
import 'cart_service.dart';
import 'payment_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<CartItem> items;

  const CheckoutScreen({super.key, required this.items});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late List<_DeliveryAddress> _addresses;
  late String _selectedAddressId;
  bool _isPlacingOrder = false;
  bool _loadingAddresses = true;

  @override
  void initState() {
    super.initState();
    _addresses = [];
    _selectedAddressId = '';
    _loadDeliveryAddresses();
  }

  _DeliveryAddress get _selectedAddress {
    return _addresses.firstWhere(
      (address) => address.id == _selectedAddressId,
      orElse: () => _addresses.first,
    );
  }

  Future<void> _loadDeliveryAddresses() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _loadingAddresses = false);
      return;
    }
    try {
      final profile = await AuthUserService.getUserProfile(user.id);
      final fullName = profile?['full_name']?.toString() ?? '';
      final rows = await Supabase.instance.client
          .from('user_addresses')
          .select('id,label,phone_number,address_line,city,is_default')
          .eq('user_id', user.id)
          .order('is_default', ascending: false);
      final addresses = (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((row) {
            final street = row['address_line']?.toString() ?? '';
            final city = row['city']?.toString() ?? '';
            return _DeliveryAddress(
              id:
                  row['id']?.toString() ??
                  DateTime.now().microsecondsSinceEpoch.toString(),
              label: row['label']?.toString() ?? 'Home',
              recipientName: fullName,
              phone: row['phone_number']?.toString() ?? '',
              streetAddress: '$street${city.isNotEmpty ? ', $city' : ''}',
              city: city,
              isPrimary: (row['is_default'] as bool?) ?? false,
            );
          })
          .toList();
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        if (_addresses.isNotEmpty) {
          _selectedAddressId = _addresses.first.id;
        }
        _loadingAddresses = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingAddresses = false);
    }
  }

  Future<void> _openChooseDeliveryAddress() async {
    if (_addresses.isEmpty) {
      final newAddress = await Navigator.push<_DeliveryAddress>(
        context,
        MaterialPageRoute(builder: (_) => const _AddressDetailsScreen()),
      );
      if (newAddress == null || !mounted) return;
      final saved = await _saveAddressToDatabase(newAddress);
      if (!mounted || saved == null) return;
      setState(() {
        _addresses = [saved];
        _selectedAddressId = saved.id;
      });
      return;
    }

    final result = await Navigator.push<_AddressFlowResult>(
      context,
      MaterialPageRoute(
        builder: (_) => _ChooseDeliveryAddressScreen(
          initialAddresses: _addresses,
          selectedAddressId: _selectedAddressId,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _addresses = result.addresses;
      _selectedAddressId = result.selectedAddressId;
    });
  }

  Future<_DeliveryAddress?> _saveAddressToDatabase(
    _DeliveryAddress address,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    final payload = {
      'user_id': user.id,
      'label': address.label,
      'phone_number': address.phone,
      'address_line': address.streetAddress,
      'city': address.city,
      'is_default': address.isPrimary,
    };
    try {
      if (address.id.startsWith('addr_')) {
        final inserted = await Supabase.instance.client
            .from('user_addresses')
            .insert(payload)
            .select('id')
            .single();
        final id = inserted['id']?.toString() ?? address.id;
        return address.copyWith(id: id);
      }

      await Supabase.instance.client
          .from('user_addresses')
          .update(payload)
          .eq('id', address.id);
      return address;
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirmOrder() async {
    if (_addresses.isEmpty || _isPlacingOrder) return;
    setState(() => _isPlacingOrder = true);

    // Instead of processing payment here, navigate to payment screen
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          items: widget.items,
          shippingAddressId: _selectedAddress.id,
        ),
      ),
    ).then((_) {
      // When returning from payment screen, reset state
      if (mounted) {
        setState(() => _isPlacingOrder = false);
      }
    });
  }

  void _showProcessingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 46,
                  height: 46,
                  child: CircularProgressIndicator(
                    strokeWidth: 5,
                    color: AppColors.primaryGreen,
                  ),
                ),
                SizedBox(height: 18),
                Text(
                  'Processing Payments...',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    color: AppColors.darkText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showOrderConfirmedDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.auto_awesome,
                      color: Color(0xFFFFD54F),
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.auto_awesome,
                      color: Color(0xFF29B6F6),
                      size: 14,
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.auto_awesome,
                      color: Color(0xFFF06292),
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 54),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Order Confirmed!',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    color: AppColors.darkText,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Peep your order details in "My Order"\nand start planning outfits.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HomeScreen(initialIndex: 3),
                        ),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'View My Order',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: AppFonts.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HomeScreen(initialIndex: 0),
                        ),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE3ECE6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Back to Home',
                      style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontFamily: AppFonts.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.subtotal);
    const promo = '-';
    final totalPayment = subtotal;

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.darkText),
        title: const Text(
          'Checkout',
          style: TextStyle(
            fontFamily: AppFonts.primary,
            color: AppColors.darkText,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.more_vert, color: AppColors.darkText),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                children: [
                  if (_loadingAddresses)
                    const SizedBox(
                      height: 120,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    )
                  else if (_addresses.isEmpty)
                    _EmptyDeliveryAddressCard(onTap: _openChooseDeliveryAddress)
                  else
                    _SelectedDeliveryAddressTile(
                      address: _selectedAddress,
                      onTap: _openChooseDeliveryAddress,
                    ),
                  const SizedBox(height: 12),
                  _OrderSection(items: items),
                  const SizedBox(height: 12),
                  _ReviewSummaryCard(
                    itemCount: items.length,
                    subtotal: subtotal,
                    promo: promo,
                    totalPayment: totalPayment,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _selectedAddressId.isNotEmpty && !_isPlacingOrder
                        ? _confirmOrder
                        : null,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: AppColors.primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text(
                      'Confirm Order',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: AppFonts.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
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

class _DeliveryAddress {
  final String id;
  final String label;
  final String recipientName;
  final String phone;
  final String streetAddress;
  final String city;
  final bool isPrimary;

  const _DeliveryAddress({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.streetAddress,
    required this.city,
    this.isPrimary = false,
  });

  _DeliveryAddress copyWith({
    String? id,
    String? label,
    String? recipientName,
    String? phone,
    String? streetAddress,
    String? city,
    String? note,
    bool? isPrimary,
  }) {
    return _DeliveryAddress(
      id: id ?? this.id,
      label: label ?? this.label,
      recipientName: recipientName ?? this.recipientName,
      phone: phone ?? this.phone,
      streetAddress: streetAddress ?? this.streetAddress,
      city: city ?? this.city,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}

class _AddressFlowResult {
  final List<_DeliveryAddress> addresses;
  final String selectedAddressId;

  const _AddressFlowResult({
    required this.addresses,
    required this.selectedAddressId,
  });
}

class _SelectedDeliveryAddressTile extends StatelessWidget {
  final _DeliveryAddress address;
  final VoidCallback onTap;

  const _SelectedDeliveryAddressTile({
    required this.address,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: const Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Delivery Address',
                    style: TextStyle(
                      fontFamily: AppFonts.primary,
                      color: AppColors.darkText,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.black45),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.darkText,
                        fontFamily: AppFonts.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      address.streetAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontFamily: AppFonts.primary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyDeliveryAddressCard extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyDeliveryAddressCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(
                  Icons.location_on_outlined,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Choose Delivery Address',
                    style: TextStyle(
                      fontFamily: AppFonts.primary,
                      color: AppColors.darkText,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.black45),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'No delivery address found. Tap to add your address now.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontFamily: AppFonts.primary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Add Address',
                style: TextStyle(
                  color: AppColors.primaryGreen,
                  fontFamily: AppFonts.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChooseDeliveryAddressScreen extends StatefulWidget {
  final List<_DeliveryAddress> initialAddresses;
  final String selectedAddressId;

  const _ChooseDeliveryAddressScreen({
    required this.initialAddresses,
    required this.selectedAddressId,
  });

  @override
  State<_ChooseDeliveryAddressScreen> createState() =>
      _ChooseDeliveryAddressScreenState();
}

class _ChooseDeliveryAddressScreenState
    extends State<_ChooseDeliveryAddressScreen> {
  late List<_DeliveryAddress> _addresses;
  late String _selectedAddressId;

  @override
  void initState() {
    super.initState();
    _addresses = List<_DeliveryAddress>.from(widget.initialAddresses);
    _selectedAddressId = widget.selectedAddressId;
    if (!_addresses.any((item) => item.id == _selectedAddressId)) {
      _selectedAddressId = _addresses.first.id;
    }
  }

  void _openManageAddresses() async {
    final updatedAddresses = await Navigator.push<List<_DeliveryAddress>>(
      context,
      MaterialPageRoute(
        builder: (_) => _ManageAddressesScreen(initialAddresses: _addresses),
      ),
    );
    if (updatedAddresses == null || !mounted) return;

    setState(() {
      _addresses = updatedAddresses;
      if (_addresses.isEmpty) return;
      final primary = _addresses.firstWhere(
        (address) => address.isPrimary,
        orElse: () => _addresses.first,
      );
      if (!_addresses.any((item) => item.id == _selectedAddressId)) {
        _selectedAddressId = primary.id;
      }
    });
  }

  void _submitSelection() {
    if (_addresses.isEmpty) return;
    Navigator.pop(
      context,
      _AddressFlowResult(
        addresses: _addresses,
        selectedAddressId: _selectedAddressId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.darkText),
        title: const Text(
          'Choose Delivery Address',
          style: TextStyle(
            color: AppColors.darkText,
            fontFamily: AppFonts.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _openManageAddresses,
            icon: const Icon(Icons.add, color: AppColors.darkText),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                itemCount: _addresses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final address = _addresses[index];
                  final isSelected = _selectedAddressId == address.id;
                  return _ChooseAddressCard(
                    address: address,
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        _selectedAddressId = address.id;
                      });
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _submitSelection,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: AppColors.primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: AppFonts.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
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

class _ChooseAddressCard extends StatelessWidget {
  final _DeliveryAddress address;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChooseAddressCard({
    required this.address,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primaryGreen : Colors.transparent,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    address.label,
                    style: const TextStyle(
                      color: AppColors.darkText,
                      fontFamily: AppFonts.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (address.isPrimary)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primaryGreen),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Main Address',
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontFamily: AppFonts.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const Spacer(),
                  const Icon(
                    Icons.share_outlined,
                    color: AppColors.darkText,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      address.phone.isNotEmpty
                          ? address.phone
                          : 'No phone provided',
                      style: const TextStyle(
                        color: AppColors.darkText,
                        fontFamily: AppFonts.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check, color: AppColors.primaryGreen),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                address.streetAddress,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontFamily: AppFonts.primary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManageAddressesScreen extends StatefulWidget {
  final List<_DeliveryAddress> initialAddresses;

  const _ManageAddressesScreen({required this.initialAddresses});

  @override
  State<_ManageAddressesScreen> createState() => _ManageAddressesScreenState();
}

class _ManageAddressesScreenState extends State<_ManageAddressesScreen> {
  late List<_DeliveryAddress> _addresses;

  @override
  void initState() {
    super.initState();
    _addresses = List<_DeliveryAddress>.from(widget.initialAddresses);
  }

  void _setPrimary(String id) {
    setState(() {
      _addresses = _addresses
          .map((address) => address.copyWith(isPrimary: address.id == id))
          .toList();
    });
  }

  Future<void> _deleteAddressFromDatabase(String id) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client
          .from('user_addresses')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);
    } catch (_) {
      // ignore deletion failures for now
    }
  }

  void _deleteAddress(String id) {
    if (_addresses.length <= 1) return;
    if (!id.startsWith('addr_')) {
      _deleteAddressFromDatabase(id);
    }
    setState(() {
      final deletedWasPrimary = _addresses.any(
        (address) => address.id == id && address.isPrimary,
      );
      _addresses = _addresses.where((address) => address.id != id).toList();
      if (deletedWasPrimary && _addresses.isNotEmpty) {
        _addresses[0] = _addresses[0].copyWith(isPrimary: true);
      }
    });
  }

  void _upsertAddress(_DeliveryAddress address) {
    setState(() {
      final index = _addresses.indexWhere((item) => item.id == address.id);
      if (address.isPrimary) {
        _addresses = _addresses
            .map((item) => item.copyWith(isPrimary: false))
            .toList();
      }
      if (index == -1) {
        _addresses.insert(0, address);
      } else {
        _addresses[index] = address;
      }
      if (!_addresses.any((item) => item.isPrimary) && _addresses.isNotEmpty) {
        _addresses[0] = _addresses[0].copyWith(isPrimary: true);
      }
    });
  }

  Future<void> _openAddAddress() async {
    final created = await Navigator.push<_DeliveryAddress>(
      context,
      MaterialPageRoute(builder: (_) => const _AddressDetailsScreen()),
    );
    if (created == null || !mounted) return;
    _upsertAddress(created);
  }

  Future<void> _openEditAddress(_DeliveryAddress current) async {
    final updated = await Navigator.push<_DeliveryAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => _AddressDetailsScreen(initialAddress: current),
      ),
    );
    if (updated == null || !mounted) return;
    _upsertAddress(updated);
  }

  void _openAddressActions(_DeliveryAddress address) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!address.isPrimary)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on_outlined),
                    title: const Text(
                      'Set As Primary Address',
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _setPrimary(address.id);
                    },
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.delete_outline,
                    color: _addresses.length <= 1 ? Colors.grey : Colors.red,
                  ),
                  title: Text(
                    'Delete Address',
                    style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontWeight: FontWeight.w600,
                      color: _addresses.length <= 1 ? Colors.grey : Colors.red,
                    ),
                  ),
                  onTap: _addresses.length <= 1
                      ? null
                      : () {
                          Navigator.pop(context);
                          _deleteAddress(address.id);
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context, _addresses),
          icon: const Icon(Icons.arrow_back, color: AppColors.darkText),
        ),
        title: const Text(
          'Manage Addresses',
          style: TextStyle(
            color: AppColors.darkText,
            fontFamily: AppFonts.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _openAddAddress,
            icon: const Icon(Icons.add, color: AppColors.darkText),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        itemCount: _addresses.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final address = _addresses[index];
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      address.label,
                      style: const TextStyle(
                        color: AppColors.darkText,
                        fontFamily: AppFonts.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (address.isPrimary)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.primaryGreen),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Main Address',
                          style: TextStyle(
                            color: AppColors.primaryGreen,
                            fontFamily: AppFonts.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const Spacer(),
                    const Icon(
                      Icons.share_outlined,
                      color: AppColors.darkText,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Text(
                  address.phone.isNotEmpty
                      ? address.phone
                      : 'No phone provided',
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontFamily: AppFonts.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  address.streetAddress,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontFamily: AppFonts.primary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _openEditAddress(address),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primaryGreen),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text(
                          'Change Address',
                          style: TextStyle(
                            color: AppColors.primaryGreen,
                            fontFamily: AppFonts.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => _openAddressActions(address),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primaryGreen),
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                      ),
                      child: const Icon(
                        Icons.more_vert,
                        color: AppColors.primaryGreen,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AddressDetailsScreen extends StatefulWidget {
  final _DeliveryAddress? initialAddress;

  const _AddressDetailsScreen({this.initialAddress});

  @override
  State<_AddressDetailsScreen> createState() => _AddressDetailsScreenState();
}

class _AddressDetailsScreenState extends State<_AddressDetailsScreen> {
  late final TextEditingController _labelController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late bool _isPrimary;

  bool get _isEditMode => widget.initialAddress != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAddress;
    _labelController = TextEditingController(
      text: initial?.label ?? 'Work',
    );
    _phoneController = TextEditingController(
      text: initial?.phone ?? '+1 111 467 378 399',
    );
    _addressController = TextEditingController(
      text: initial?.streetAddress ?? '75 9th Ave, New York, NY 10011, USA',
    );
    _cityController = TextEditingController(text: initial?.city ?? 'New York');
    _isPrimary = initial?.isPrimary ?? true;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<String> _getProfileFullName() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return 'Customer';
    final profile = await AuthUserService.getUserProfile(user.id);
    return profile?['full_name']?.toString().trim().isNotEmpty == true
        ? profile!['full_name'].toString().trim()
        : 'Customer';
  }

  Future<_DeliveryAddress?> _persistAddressToDatabase(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    try {
      if (id.startsWith('addr_')) {
        final inserted = await Supabase.instance.client
            .from('user_addresses')
            .insert(payload)
            .select('id')
            .single();
        final newId = inserted['id']?.toString() ?? id;
        return _DeliveryAddress(
          id: newId,
          label: payload['label'].toString(),
          recipientName: await _getProfileFullName(),
          phone: payload['phone_number'].toString(),
          streetAddress: payload['address_line'].toString(),
          city: payload['city'].toString(),
          isPrimary: payload['is_default'] as bool,
        );
      }

      await Supabase.instance.client
          .from('user_addresses')
          .update(payload)
          .eq('id', id);
      return _DeliveryAddress(
        id: id,
        label: payload['label'].toString(),
        recipientName: await _getProfileFullName(),
        phone: payload['phone_number'].toString(),
        streetAddress: payload['address_line'].toString(),
        city: payload['city'].toString(),
        isPrimary: payload['is_default'] as bool,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveAddress() async {
    final label = _labelController.text.trim();
    final phone = _phoneController.text.trim();
    final street = _addressController.text.trim();
    final city = _cityController.text.trim();
    if (label.isEmpty || phone.isEmpty || street.isEmpty || city.isEmpty) {
      return;
    }

    final id =
        widget.initialAddress?.id ??
        'addr_${DateTime.now().microsecondsSinceEpoch.toString()}';
    final payload = {
      'user_id': Supabase.instance.client.auth.currentUser?.id,
      'label': label,
      'phone_number': phone,
      'address_line': street,
      'city': city,
      'is_default': _isPrimary,
    };

    final savedAddress = await _persistAddressToDatabase(id, payload);
    if (savedAddress != null && mounted) {
      Navigator.pop(context, savedAddress);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            _isEditMode ? Icons.close : Icons.close,
            color: AppColors.darkText,
          ),
        ),
        title: Text(
          _isEditMode ? 'Address Details' : 'Add New Address',
          style: const TextStyle(
            color: AppColors.darkText,
            fontFamily: AppFonts.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                children: [
                  _FieldLabel(label: 'Address Labels'),
                  _InputBox(
                    controller: _labelController,
                    hintText: 'Home / Work Office',
                  ),
                  const SizedBox(height: 14),
                  _FieldLabel(label: "Recipient's Phone Number"),
                  _InputBox(
                    controller: _phoneController,
                    hintText: 'Phone number',
                  ),
                  const SizedBox(height: 14),
                  _FieldLabel(label: 'City'),
                  _InputBox(controller: _cityController, hintText: 'City'),
                  const SizedBox(height: 14),
                  _FieldLabel(label: 'Address'),
                  _InputBox(
                    controller: _addressController,
                    hintText: 'Street, ZIP',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    value: _isPrimary,
                    activeColor: AppColors.primaryGreen,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (value) {
                      setState(() {
                        _isPrimary = value ?? false;
                      });
                    },
                    title: const Text(
                      'Set As Primary Address',
                      style: TextStyle(
                        color: AppColors.darkText,
                        fontFamily: AppFonts.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _saveAddress,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: AppColors.primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(
                      _isEditMode
                          ? 'Save'
                          : 'Select Location & Continue Fill Address',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: AppFonts.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
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

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.darkText,
          fontFamily: AppFonts.primary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final int maxLines;

  const _InputBox({
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        color: AppColors.darkText,
        fontFamily: AppFonts.primary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.grey.shade500,
          fontFamily: AppFonts.primary,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: AppColors.primaryGreen),
        ),
      ),
    );
  }
}

class _OrderSection extends StatelessWidget {
  final List<CartItem> items;

  const _OrderSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.shopping_bag_outlined,
                color: AppColors.primaryGreen,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your Order (${items.length})',
                  style: const TextStyle(
                    fontFamily: AppFonts.primary,
                    color: AppColors.darkText,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.add, color: AppColors.darkText),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          ...items.map((item) => _OrderItemTile(item: item)),
        ],
      ),
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  final CartItem item;

  const _OrderItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              item.imageUrl,
              width: 72,
              height: 86,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 72,
                height: 86,
                color: Colors.grey.shade300,
                alignment: Alignment.center,
                child: const Icon(Icons.image_not_supported, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 16,
                    color: AppColors.darkText,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Size: ${item.size}',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Color: ${item.colorName} ',
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Qty: ${item.quantity}',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '\$${item.subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontFamily: AppFonts.primary,
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewSummaryCard extends StatelessWidget {
  final int itemCount;
  final double subtotal;
  final String promo;
  final double totalPayment;

  const _ReviewSummaryCard({
    required this.itemCount,
    required this.subtotal,
    required this.promo,
    required this.totalPayment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color: AppColors.primaryGreen,
                size: 20,
              ),
              SizedBox(width: 10),
              Text(
                'Review Summary',
                style: TextStyle(
                  fontFamily: AppFonts.primary,
                  color: AppColors.darkText,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Subtotal ($itemCount items)',
            value: '\$${subtotal.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 8),
          _SummaryRow(label: 'Promo', value: promo),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Total Payment',
            value: '\$${totalPayment.toStringAsFixed(2)}',
            isTotal: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontFamily: AppFonts.primary,
      color: AppColors.darkText,
      fontSize: isTotal ? 16 : 15,
      fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: textStyle)),
        Text(value, style: textStyle),
      ],
    );
  }
}
