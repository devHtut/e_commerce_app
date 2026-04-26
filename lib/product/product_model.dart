class ProductModel {
  final String id;
  final String name;
  final String category;
  final String brand;
  final double price;
  final double rating;
  final String imageUrl;

  const ProductModel({
    required this.id,
    required this.name,
    required this.category,
    required this.brand,
    required this.price,
    required this.rating,
    required this.imageUrl,
  });
}
