import 'package:flutter/material.dart';
import '../theme_config.dart';
import '../widgets/search_box.dart';

class VendorProductsScreen extends StatefulWidget {
  const VendorProductsScreen({super.key});

  @override
  State<VendorProductsScreen> createState() => _VendorProductsScreenState();
}

class _VendorProductsScreenState extends State<VendorProductsScreen> {
  final List<_VendorProduct> _products = [
    _VendorProduct(
      id: '1',
      name: 'Nike Zoom Mercurial Vapor',
      price: 188,
      stock: 1090,
      imageUrl:
          'https://images.unsplash.com/photo-1528701800489-20a4baa6d7f4?auto=format&fit=crop&w=900&q=80',
    ),
    _VendorProduct(
      id: '2',
      name: 'Nike Phantom GX Elite',
      price: 198,
      stock: 928,
      imageUrl:
          'https://images.unsplash.com/photo-1518893069135-5fe53a454b98?auto=format&fit=crop&w=900&q=80',
    ),
    _VendorProduct(
      id: '3',
      name: 'Nike Zoom Academy KM MG',
      price: 150,
      stock: 1623,
      imageUrl:
          'https://images.unsplash.com/photo-1519741494644-0f9754d6d4be?auto=format&fit=crop&w=900&q=80',
    ),
    _VendorProduct(
      id: '4',
      name: 'Nike Phantom GX Club',
      price: 202,
      stock: 883,
      imageUrl:
          'https://images.unsplash.com/photo-1515542622106-78bda8ba0e9d?auto=format&fit=crop&w=900&q=80',
    ),
    _VendorProduct(
      id: '5',
      name: 'Nike Phantom GX Pro',
      price: 155,
      stock: 1688,
      imageUrl:
          'https://images.unsplash.com/photo-1528701800489-20a4baa6d7f4?auto=format&fit=crop&w=900&q=80',
    ),
  ];

  String _searchQuery = '';

  List<_VendorProduct> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _products;
    return _products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.price.toString().contains(query);
    }).toList();
  }

  Future<void> _showProductDialog({required _VendorProduct product}) async {
    final nameController = TextEditingController(text: product.name);
    final priceController = TextEditingController(
      text: product.price.toString(),
    );
    final stockController = TextEditingController(
      text: product.stock.toString(),
    );

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Product'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Product name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stock quantity'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              onPressed: () {
                final updatedName = nameController.text.trim();
                final updatedPrice =
                    double.tryParse(priceController.text) ?? product.price;
                final updatedStock =
                    int.tryParse(stockController.text) ?? product.stock;
                setState(() {
                  product.name = updatedName.isEmpty
                      ? product.name
                      : updatedName;
                  product.price = updatedPrice;
                  product.stock = updatedStock;
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addProduct() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Product'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Product name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stock quantity'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              onPressed: () {
                final name = nameController.text.trim();
                final price = double.tryParse(priceController.text) ?? 0;
                final stock = int.tryParse(stockController.text) ?? 0;
                if (name.isEmpty || price <= 0) {
                  return;
                }
                setState(() {
                  _products.add(
                    _VendorProduct(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: name,
                      price: price,
                      stock: stock,
                      imageUrl:
                          'https://images.unsplash.com/photo-1515542622106-78bda8ba0e9d?auto=format&fit=crop&w=900&q=80',
                    ),
                  );
                });
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Product List',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
                      fontFamily: AppFonts.primary,
                    ),
                  ),
                  IconButton(
                    onPressed: _addProduct,
                    icon: const Icon(Icons.add, color: AppColors.primaryGreen),
                    tooltip: 'Add product',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SearchBox(
                hintText: 'Search products...',
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _filteredProducts.isEmpty
                    ? const Center(
                        child: Text(
                          'No products found.',
                          style: AppTextStyles.body,
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filteredProducts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(14),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(
                                  product.imageUrl,
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              title: Text(
                                product.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.darkText,
                                  fontFamily: AppFonts.primary,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Text(
                                    '\$${product.price.toStringAsFixed(0)} • ${product.stock} in stocks',
                                    style: const TextStyle(
                                      color: AppColors.subtleText,
                                      fontFamily: AppFonts.primary,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: TextButton(
                                onPressed: () =>
                                    _showProductDialog(product: product),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primaryGreen,
                                ),
                                child: const Text('Edit'),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VendorProduct {
  final String id;
  String name;
  double price;
  int stock;
  final String imageUrl;

  _VendorProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.imageUrl,
  });
}
