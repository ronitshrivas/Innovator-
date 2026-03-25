import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/Innovator/widget/Custom_refresh_Indicator.dart';
import 'package:innovator/ecommerce/screens/Shop/Cart_List/cart_screen.dart';
import 'package:skeletonizer/skeletonizer.dart';
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
  final Set<String> _cartProductIds = {};
  // ── Fake products for skeleton loading ──
  static final _skeletonProducts = List.generate(
    6,
    (i) => ProductModel(
      id: '$i',
      name: 'Product Name Here',
      price: '999',
      stock: 10,
      images: [],
      category: 'Category',
    ),
  );

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    ref.refresh(productListProvider);
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text.toLowerCase());
  }

  List<ProductModel> _getFilteredAndSorted(List<ProductModel> products) {
    var filtered = List<ProductModel>.from(products);

    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered
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

  // ── Add to Cart with feedback ──
  Future<void> _addToCart(ProductModel product) async {
    if (_cartProductIds.contains(product.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 2),
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Already in cart!', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
      return;
    }

    try {
      await ref.read(productServiceProvider).addCartItem(product: product.id);

      setState(() {
        _cartProductIds.add(product.id);
        cartCount++;
      });

      if (!mounted) return;
      _showSnackBar(
        message: '${product.name} added to cart!',
        icon: Icons.check_circle,
        color: Colors.green.shade600,
      );
    } on DioException catch (e) {
      if (!mounted) return;

      final statusCode = e.response?.statusCode;
      final responseData = e.response?.data?.toString() ?? '';

      // Backend returned HTML 500 → means item already exists in cart on server
      final isHtml500 =
          statusCode == 500 &&
          responseData.contains('<h1>Server Error (500)</h1>');

      if (isHtml500) {
        // Treat it as "already in cart" — sync local state with server reality
        setState(() {
          _cartProductIds.add(product.id);
        });
        _showSnackBar(
          message: '${product.name} is already in your cart.',
          icon: Icons.info_outline,
          color: Colors.orange.shade700,
        );
      } else if (statusCode == 400 || statusCode == 409) {
        _showSnackBar(
          message: 'Could not add item. Please try again.',
          icon: Icons.warning_amber_rounded,
          color: Colors.orange.shade700,
        );
      } else if (statusCode == 401 || statusCode == 403) {
        _showSnackBar(
          message: 'Session expired. Please log in again.',
          icon: Icons.lock_outline,
          color: Colors.red.shade600,
        );
      } else {
        _showSnackBar(
          message: 'Something went wrong. Try again later.',
          icon: Icons.error_outline,
          color: Colors.red.shade600,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        message: 'Unexpected error. Please try again.',
        icon: Icons.error_outline,
        color: Colors.red.shade600,
      );
    }
  }

  // ── Reusable snackbar helper ──
  void _showSnackBar({
    required String message,
    required IconData icon,
    required Color color,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
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
                    setState(() {
                      sortBy = 'name';
                      ascending = true;
                    });
                    Navigator.pop(context);
                  },
                ),
                _buildSortTile(
                  title: 'Name (Z → A)',
                  isSelected: sortBy == 'name' && !ascending,
                  onTap: () {
                    setState(() {
                      sortBy = 'name';
                      ascending = false;
                    });
                    Navigator.pop(context);
                  },
                ),
                _buildSortTile(
                  title: 'Price (Low → High)',
                  isSelected: sortBy == 'price' && ascending,
                  onTap: () {
                    setState(() {
                      sortBy = 'price';
                      ascending = true;
                    });
                    Navigator.pop(context);
                  },
                ),
                _buildSortTile(
                  title: 'Price (High → Low)',
                  isSelected: sortBy == 'price' && !ascending,
                  onTap: () {
                    setState(() {
                      sortBy = 'price';
                      ascending = false;
                    });
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
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartScreen()),
            );
          },
          child: Consumer(
            builder: (context, ref, _) {
              final count = ref.watch(cartCountProvider);
              return Badge.count(
                count: count,
                isLabelVisible: count > 0,
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  color: Colors.white,
                ),
              );
            },
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
                  // ── Skeleton Loading ──
                  loading:
                      () => Skeletonizer(
                        enabled: true,
                        effect: ShimmerEffect(
                          baseColor: Colors.grey.shade300,
                          highlightColor: Colors.grey.shade100,
                        ),
                        child: _buildGrid(_skeletonProducts),
                      ),

                  // ── Error ──
                  error:
                      (error, stack) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 60,
                              color: Colors.red[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load products',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700],
                              ),
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

                  // ── Data with pull-to-refresh ──
                  data: (products) {
                    final filtered = _getFilteredAndSorted(products);

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_bag_outlined,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No products found'
                                  : 'No products available',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // ── Wrap with CustomRefreshIndicator ──
                    return CustomRefreshIndicator(
                      onRefresh: () async {
                        ref.refresh(productListProvider);
                        // wait for the new data to settle
                        await ref.read(productListProvider.future);
                      },
                      child: _buildGrid(filtered),
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
                        suffixIcon:
                            _searchQuery.isNotEmpty
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
                          horizontal: 16,
                          vertical: 12,
                        ),
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
                        child: const Icon(
                          Icons.settings_input_component,
                          size: 18,
                          color: Colors.black,
                        ),
                      ),
                      if (sortBy != 'name' || !ascending)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 8,
                              color: Colors.white,
                            ),
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

  // ── Extracted GridView to reuse for both real data and skeleton ──
  Widget _buildGrid(List<ProductModel> products) {
    return GridView.builder(
      padding: const EdgeInsets.only(right: 5, left: 5, bottom: 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisSpacing: 10,
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        childAspectRatio: 0.66,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) => _buildProductCard(products[index]),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final price = double.tryParse(product.price) ?? 0.0;
    final hasImage = product.images.isNotEmpty;

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(product.name),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasImage)
                      Image.network(product.images.first.toString())
                    else
                      const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: Colors.grey,
                        ),
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
                child:
                    hasImage
                        ? Image.network(
                          product.images.first.toString(),
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) => const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              ),
                        )
                        : const Center(
                          child: Icon(
                            Icons.inventory_2_outlined,
                            size: 52,
                            color: Colors.grey,
                          ),
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
                      if (product.category != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
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
                              color:
                                  product.stock > 0 ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      // ── Add to Cart Button ──
                      SizedBox(
                        width: double.infinity,
                        height: 34,
                        child: ElevatedButton.icon(
                          onPressed:
                              product.stock > 0
                                  ? () => _addToCart(
                                    product,
                                  ) // 👈 calls our new method
                                  : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromRGBO(
                              244,
                              135,
                              6,
                              1,
                            ),
                            disabledBackgroundColor: Colors.grey[300],
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(
                            Icons.add,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: Text(
                            product.stock > 0 ? 'Add to Cart' : 'Out of Stock',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                            ),
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
