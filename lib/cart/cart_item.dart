import '../product/product_model.dart';

class CartItem {
  final String id;
  final String? dbId;
  final String? variantId;
  final ProductModel product;
  final String size;
  final String colorName;
  final int colorValue;
  final String imageUrl;
  final int quantity;
  final bool isSelected;
  final DateTime createdAt;

  const CartItem({
    required this.id,
    this.dbId,
    this.variantId,
    required this.product,
    required this.size,
    required this.colorName,
    required this.colorValue,
    required this.imageUrl,
    required this.quantity,
    this.isSelected = true,
    required this.createdAt,
  });

  double get subtotal => product.price * quantity;

  DateTime get removalDate => createdAt.toUtc().add(const Duration(days: 30));

  int get daysRemaining {
    final remaining = removalDate.difference(DateTime.now().toUtc()).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  bool get isExpired => DateTime.now().toUtc().isAfter(removalDate);

  bool get isExpiringSoon => !isExpired && daysRemaining <= 7;

  String get expiryLabel {
    if (isExpired) {
      return 'This item is being removed from your cart.';
    }
    if (daysRemaining == 0) {
      return 'This item will be removed today.';
    }
    return 'This item will be removed in $daysRemaining day${daysRemaining == 1 ? '' : 's'}.';
  }

  CartItem copyWith({
    String? id,
    String? dbId,
    String? variantId,
    ProductModel? product,
    String? size,
    String? colorName,
    int? colorValue,
    String? imageUrl,
    int? quantity,
    bool? isSelected,
    DateTime? createdAt,
  }) {
    return CartItem(
      id: id ?? this.id,
      dbId: dbId ?? this.dbId,
      variantId: variantId ?? this.variantId,
      product: product ?? this.product,
      size: size ?? this.size,
      colorName: colorName ?? this.colorName,
      colorValue: colorValue ?? this.colorValue,
      imageUrl: imageUrl ?? this.imageUrl,
      quantity: quantity ?? this.quantity,
      isSelected: isSelected ?? this.isSelected,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
