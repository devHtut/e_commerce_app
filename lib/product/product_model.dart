class ProductModel {
  final String id;
  final String name;
  final String category;
  final String? categoryId;
  final String brand;
  final String? brandId;
  final String? brandLogoUrl;
  final String description;
  final double price;
  final double rating;
  final String imageUrl;
  final List<String> imageUrls;

  const ProductModel({
    required this.id,
    required this.name,
    required this.category,
    this.categoryId,
    required this.brand,
    this.brandId,
    this.brandLogoUrl,
    required this.description,
    required this.price,
    required this.rating,
    required this.imageUrl,
    this.imageUrls = const [],
  });

  List<String> get galleryImages =>
      imageUrls.isEmpty ? <String>[imageUrl] : imageUrls;

  factory ProductModel.fromSupabaseRow(Map<String, dynamic> row) {
    final variants = (row['product_variants'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final imageUrls = variants
        .map((v) => v['image_url']?.toString() ?? '')
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();

    final basePrice = (row['base_price'] as num?)?.toDouble() ?? 0;
    final category = ((row['categories'] as Map?)?['name']?.toString()) ?? 'General';
    final brand = ((row['brands'] as Map?)?['brand_name']?.toString()) ?? 'Unknown Brand';

    return ProductModel(
      id: row['id'].toString(),
      name: row['title']?.toString() ?? 'Untitled',
      category: category,
      categoryId: row['category_id']?.toString(),
      brand: brand,
      brandId: row['brand_id']?.toString(),
      brandLogoUrl: ((row['brands'] as Map?)?['logo_url']?.toString()),
      description: row['description']?.toString() ?? '',
      price: basePrice,
      rating: 4.8,
      imageUrl: imageUrls.isEmpty
          ? 'https://via.placeholder.com/600x800?text=No+Image'
          : imageUrls.first,
      imageUrls: imageUrls,
    );
  }
}
