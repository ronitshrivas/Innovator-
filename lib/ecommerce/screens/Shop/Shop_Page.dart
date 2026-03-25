import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/ecommerce/model/product_model.dart';
import 'package:innovator/ecommerce/provider/product_provider.dart';

class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({Key? key}) : super(key: key);

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String sortBy = 'name';
  bool ascending = true;
  int cartCount = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

List<ProductModel> _getFilteredAndSorted(List<ProductModel> products) {
  var filtered = List<ProductModel>.from(products);  

  if (_searchQuery.isNotEmpty) {
    filtered = filtered
        .where((p) => p.name.toLowerCase().contains(_searchQuery))
        .toList();
  }

  filtered.sort((a, b) {
    int comparison = 0;
    if (sortBy == 'name') {
      comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    } else if (sortBy == 'price') {
      final priceA = double.tryParse(a.price) ?? 0;
      final priceB = double.tryParse(b.price) ?? 0;
      comparison = priceA.compareTo(priceB);
    }
    return ascending ? comparison : -comparison;
  });

  return filtered;
}

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Sort Products',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            _buildSortTile(
              title: 'Name (A → Z)',
              isSelected: sortBy == 'name' && ascending,
              onTap: () {
                setState(() { sortBy = 'name'; ascending = true; });
                Navigator.pop(context);
              },
            ),
            _buildSortTile(
              title: 'Name (Z → A)',
              isSelected: sortBy == 'name' && !ascending,
              onTap: () {
                setState(() { sortBy = 'name'; ascending = false; });
                Navigator.pop(context);
              },
            ),
            _buildSortTile(
              title: 'Price (Low → High)',
              isSelected: sortBy == 'price' && ascending,
              onTap: () {
                setState(() { sortBy = 'price'; ascending = true; });
                Navigator.pop(context);
              },
            ),
            _buildSortTile(
              title: 'Price (High → Low)',
              isSelected: sortBy == 'price' && !ascending,
              onTap: () {
                setState(() { sortBy = 'price'; ascending = false; });
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSortTile({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: isSelected ? Colors.blue : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.blue : Colors.black87,
        ),
      ),
      onTap: onTap,
    );
  }

  void _addToCart(String productName) {
    setState(() => cartCount++);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text('$productName added to cart')),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productListProvider);

    return Scaffold(
      floatingActionButton: Container(
        decoration: BoxDecoration(
          color: const Color.fromRGBO(244, 135, 6, 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cart items: $cartCount'),
                backgroundColor: Colors.blue,
              ),
            );
          },
          child: Stack(
            children: [
              const Icon(Icons.shopping_cart, color: Colors.white, size: 28),
              if (cartCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      cartCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 130),
              Expanded(
                child: productAsync.when(
                  // ── Loading ──
                  loading: () => const Center(child: CircularProgressIndicator()),

                  // ── Error ──
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load products',
                          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => ref.refresh(productListProvider),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),

                  // ── Data ──
                  data: (products) {
                    final filtered = _getFilteredAndSorted(products);
                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_bag_outlined,
                                size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No products found'
                                  : 'No products available',
                              style: TextStyle(
                                  fontSize: 18, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.only(
                          right: 5, left: 5, bottom: 80),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisSpacing: 10,
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.66,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) =>
                          _buildProductCard(filtered[index]),
                    );
                  },
                ),
              ),
            ],
          ),

          // ── Top Bar ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search products...',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : Icon(Icons.search, color: Colors.grey[600]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _showSortBottomSheet,
                  icon: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.settings_input_component,
                            size: 18, color: Colors.black),
                      ),
                      if (sortBy != 'name' || !ascending)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                                color: Colors.blue, shape: BoxShape.circle),
                            child: const Icon(Icons.check,
                                size: 8, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

Widget _buildProductCard(ProductModel product) {
  final price = double.tryParse(product.price) ?? 0.0;
  final hasImage = product.images.isNotEmpty;

  return GestureDetector(
    onTap: () {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(product.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage)
                Image.network(product.images.first.toString())
              else
                const Center(
                  child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                ),
              const SizedBox(height: 16),
              Text('Price: Rs ${price.toInt()}'),
              const SizedBox(height: 8),
              Text('Stock: ${product.stock} items'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    },
    child: Card(
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──
            Container(
              height: 140,
              width: double.infinity,
              color: Colors.grey[200],
              child: hasImage
                  ? Image.network(
                      product.images.first.toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.inventory_2_outlined, size: 52, color: Colors.grey),
                    ),
            ),

            // ── Details ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Name
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Category — only shown if not null
                    if (product.category != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha(50),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          product.category!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    // Price + Stock
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rs ${price.toInt()}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Stock: ${product.stock}',
                          style: TextStyle(
                            fontSize: 11,
                            color: product.stock > 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    // Add to Cart Button
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: ElevatedButton.icon(
                        onPressed: product.stock > 0 ? () => _addToCart(product.name) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(244, 135, 6, 1),
                          disabledBackgroundColor: Colors.grey[300],
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.add, size: 16, color: Colors.white),
                        label: Text(
                          product.stock > 0 ? 'Add to Cart' : 'Out of Stock',
                          style: const TextStyle(fontSize: 11, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}