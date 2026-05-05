import 'package:flutter/material.dart';

import '../theme_config.dart';

class DeliveryAddress {
  final String id;
  final String label;
  final String recipientName;
  final String phone;
  final String streetAddress;
  final bool isPrimary;

  const DeliveryAddress({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.streetAddress,
    this.isPrimary = false,
  });

  DeliveryAddress copyWith({
    String? id,
    String? label,
    String? recipientName,
    String? phone,
    String? streetAddress,
    bool? isPrimary,
  }) {
    return DeliveryAddress(
      id: id ?? this.id,
      label: label ?? this.label,
      recipientName: recipientName ?? this.recipientName,
      phone: phone ?? this.phone,
      streetAddress: streetAddress ?? this.streetAddress,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}

class DeliveryAddressResult {
  final List<DeliveryAddress> addresses;
  final String selectedAddressId;

  const DeliveryAddressResult({
    required this.addresses,
    required this.selectedAddressId,
  });
}

class DeliveryAddressScreen extends StatefulWidget {
  final List<DeliveryAddress> initialAddresses;
  final String selectedAddressId;

  const DeliveryAddressScreen({
    super.key,
    required this.initialAddresses,
    required this.selectedAddressId,
  });

  @override
  State<DeliveryAddressScreen> createState() => _DeliveryAddressScreenState();
}

class _DeliveryAddressScreenState extends State<DeliveryAddressScreen> {
  late List<DeliveryAddress> _addresses;
  late String _selectedAddressId;

  @override
  void initState() {
    super.initState();
    _addresses = List<DeliveryAddress>.from(widget.initialAddresses);
    _selectedAddressId = widget.selectedAddressId;
    if (_addresses.isNotEmpty &&
        !_addresses.any((item) => item.id == _selectedAddressId)) {
      _selectedAddressId = _addresses.first.id;
    }
  }

  void _openManageAddresses() async {
    final updatedAddresses = await Navigator.push<List<DeliveryAddress>>(
      context,
      MaterialPageRoute(
        builder: (_) => ManageAddressesScreen(initialAddresses: _addresses),
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
      DeliveryAddressResult(
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

class ManageAddressesScreen extends StatefulWidget {
  final List<DeliveryAddress> initialAddresses;

  const ManageAddressesScreen({
    super.key,
    required this.initialAddresses,
  });

  @override
  State<ManageAddressesScreen> createState() => _ManageAddressesScreenState();
}

class _ManageAddressesScreenState extends State<ManageAddressesScreen> {
  late List<DeliveryAddress> _addresses;

  @override
  void initState() {
    super.initState();
    _addresses = List<DeliveryAddress>.from(widget.initialAddresses);
  }

  void _setPrimary(String id) {
    setState(() {
      _addresses = _addresses
          .map((address) => address.copyWith(isPrimary: address.id == id))
          .toList();
    });
  }

  void _deleteAddress(String id) {
    if (_addresses.length <= 1) return;
    setState(() {
      final deletedWasPrimary =
          _addresses.any((address) => address.id == id && address.isPrimary);
      _addresses = _addresses.where((address) => address.id != id).toList();
      if (deletedWasPrimary && _addresses.isNotEmpty) {
        _addresses[0] = _addresses[0].copyWith(isPrimary: true);
      }
    });
  }

  void _upsertAddress(DeliveryAddress address) {
    setState(() {
      final index = _addresses.indexWhere((item) => item.id == address.id);
      if (address.isPrimary) {
        _addresses =
            _addresses.map((item) => item.copyWith(isPrimary: false)).toList();
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
    final created = await Navigator.push<DeliveryAddress>(
      context,
      MaterialPageRoute(builder: (_) => const AddressDetailsScreen()),
    );
    if (created == null || !mounted) return;
    _upsertAddress(created);
  }

  Future<void> _openEditAddress(DeliveryAddress current) async {
    final updated = await Navigator.push<DeliveryAddress>(
      context,
      MaterialPageRoute(builder: (_) => AddressDetailsScreen(initialAddress: current)),
    );
    if (updated == null || !mounted) return;
    _upsertAddress(updated);
  }

  void _openAddressActions(DeliveryAddress address) {
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    const Icon(Icons.share_outlined, color: AppColors.darkText, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Text(
                  '${address.recipientName}   (${address.phone})',
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

class AddressDetailsScreen extends StatefulWidget {
  final DeliveryAddress? initialAddress;

  const AddressDetailsScreen({
    super.key,
    this.initialAddress,
  });

  @override
  State<AddressDetailsScreen> createState() => _AddressDetailsScreenState();
}

class _AddressDetailsScreenState extends State<AddressDetailsScreen> {
  late final TextEditingController _labelController;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _noteController;
  late bool _isPrimary;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAddress;
    _labelController = TextEditingController(text: initial?.label ?? '');
    _nameController = TextEditingController(text: initial?.recipientName ?? '');
    _phoneController = TextEditingController(text: initial?.phone ?? '');
    _addressController =
        TextEditingController(text: initial?.streetAddress ?? '');
    _isPrimary = initial?.isPrimary ?? true;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _saveAddress() {
    final label = _labelController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final street = _addressController.text.trim();
    if (label.isEmpty || name.isEmpty || phone.isEmpty || street.isEmpty) return;

    Navigator.pop(
      context,
      DeliveryAddress(
        id: widget.initialAddress?.id ??
            'addr_${DateTime.now().microsecondsSinceEpoch}',
        label: label,
        recipientName: name,
        phone: phone,
        streetAddress: street,
        isPrimary: _isPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.initialAddress != null;
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: AppColors.darkText),
        ),
        title: Text(
          isEditMode ? 'Address Details' : 'Add New Address',
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
                  const _FieldLabel(label: 'Address Labels'),
                  _InputBox(controller: _labelController, hintText: 'Home / Work Office'),
                  const SizedBox(height: 14),
                  const _FieldLabel(label: "လက်ခံမည့်သူ အမည်"),
                  _InputBox(controller: _nameController, hintText: 'Recipient name'),
                  const SizedBox(height: 14),
                  const _FieldLabel(label: "လက်ခံမည့်သူ ဖုန်းနံပါတ်"),
                  _InputBox(controller: _phoneController, hintText: 'Phone number'),
                  const SizedBox(height: 14),
                  const _FieldLabel(label: 'လိပ်စာ'),
                  _InputBox(
                    controller: _addressController,
                    hintText: 'လမ်းအမည်၊ မြို့အမည်',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    value: _isPrimary,
                    activeColor: AppColors.primaryGreen,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (value) => setState(() => _isPrimary = value ?? false),
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
                      isEditMode ? 'Save' : 'Select Location & Continue Fill Address',
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

class _ChooseAddressCard extends StatelessWidget {
  final DeliveryAddress address;
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  const Icon(Icons.share_outlined, color: AppColors.darkText, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${address.recipientName}   (${address.phone})',
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
              const SizedBox(height: 8),
            ],
          ),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
