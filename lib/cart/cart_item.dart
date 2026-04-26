import '../product/product_model.dart';

class CartItem {
  final String id;
  final ProductModel product;
  final String size;
  final String colorName;
  final int colorValue;
  final String imageUrl;
  final int quantity;
  final bool isSelected;

  const CartItem({
    required this.id,
    required this.product,
    required this.size,
    required this.colorName,
    required this.colorValue,
    required this.imageUrl,
    required this.quantity,
    this.isSelected = true,
  });

  double get subtotal => product.price * quantity;

  CartItem copyWith({
    int? quantity,
    bool? isSelected,
  }) {
    return CartItem(
      id: id,
      product: product,
      size: size,
      colorName: colorName,
      colorValue: colorValue,
      imageUrl: imageUrl,
      quantity: quantity ?? this.quantity,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
