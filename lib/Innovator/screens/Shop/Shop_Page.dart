

import 'package:flutter/material.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({Key? key}) : super(key: key);

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String sortBy = 'name';
  bool ascending = true;
  int cartCount = 0;

  // Mock product data
  final List<Map<String, dynamic>> _mockProducts = [
    {
      'id': '1',
      'name': 'Wireless Headphones',
      'price': 2999.0,
      'category': 'Electronics',
      'stock': 15,
      'image': '🎧',
    },
    {
      'id': '2',
      'name': 'USB-C Cable',
      'price': 499.0,
      'category': 'Accessories',
      'stock': 50,
      'image': '🔌',
    },
    {
      'id': '3',
      'name': 'Wireless Mouse',
      'price': 1599.0,
      'category': 'Electronics',
      'stock': 20,
      'image': '🖱️',
    },
    {
      'id': '4',
      'name': 'Phone Case',
      'price': 399.0,
      'category': 'Accessories',
      'stock': 40,
      'image': '📱',
    },
    {
      'id': '5',
      'name': 'Laptop Stand',
      'price': 1299.0,
      'category': 'Electronics',
      'stock': 12,
      'image': '💻',
    },
    {
      'id': '6',
      'name': 'Screen Protector',
      'price': 299.0,
      'category': 'Accessories',
      'stock': 60,
      'image': '🛡️',
    },
    {
      'id': '7',
      'name': 'Keyboard',
      'price': 3499.0,
      'category': 'Electronics',
      'stock': 8,
      'image': '⌨️',
    },
    {
      'id': '8',
      'name': 'Phone Charger',
      'price': 799.0,
      'category': 'Accessories',
      'stock': 35,
      'image': '🔋',
    },
  ];

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

  List<Map<String, dynamic>> _getFilteredAndSortedProducts() {
    var filtered = _mockProducts;

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered
              .where(
                (product) => product['name'].toString().toLowerCase().contains(
                  _searchQuery,
                ),
              )
              .toList();
    }

    // Sort
    filtered.sort((a, b) {
      int comparison = 0;

      if (sortBy == 'name') {
        final nameA = a['name'].toString().toLowerCase();
        final nameB = b['name'].toString().toLowerCase();
        comparison = nameA.compareTo(nameB);
      } else if (sortBy == 'price') {
        final priceA = (a['price'] as num).toDouble();
        final priceB = (b['price'] as num).toDouble();
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

  void _addToCart(String productName) {
    setState(() {
      cartCount++;
    });
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
        duration: const Duration(seconds: 3),
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
    final filteredProducts = _getFilteredAndSortedProducts();

    return Scaffold(
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color.fromRGBO(244, 135, 6, 1),
              Color.fromRGBO(244, 135, 6, 1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () {
            // Show cart
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
          // Body Content
          Column(
            children: [
              const SizedBox(height: 130),
              Expanded(
                child:
                    filteredProducts.isEmpty
                        ? Center(
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
                        )
                        : GridView.builder(
                          padding: const EdgeInsets.only(
                            right: 5,
                            left: 5,
                            bottom: 80,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisSpacing: 10,
                                crossAxisCount: 2,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.66,
                              ),
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            return _buildProductCard(filteredProducts[index]);
                          },
                        ),
              ),
            ],
          ),

          // Top Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Row(
                  children: [
                    // Search Bar
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
                                    : Icon(
                                      Icons.search,
                                      color: Colors.grey[600],
                                    ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Sort Button
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final String name = product['name'];
    final double price = product['price'];
    final String category = product['category'];
    final int stock = product['stock'];
    final String image = product['image'];

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(name),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      image,
                      style: const TextStyle(fontSize: 48),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text('Price: Rs $price'),
                    const SizedBox(height: 8),
                    Text('Category: $category'),
                    const SizedBox(height: 8),
                    Text('Stock: $stock items'),
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
              // Product Image
              Container(
                height: 140,
                width: double.infinity,
                color: Colors.grey[200],
                child: Center(
                  child: Text(image, style: const TextStyle(fontSize: 60)),
                ),
              ),

              // Product Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                    right: 10,
                    left: 10,
                    top: 10,
                    bottom: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Rs ${price.toInt()}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: ElevatedButton(
                              onPressed:
                                  stock > 0 ? () => _addToCart(name) : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromRGBO(
                                  244,
                                  135,
                                  6,
                                  1,
                                ),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Icon(
                                Icons.add,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
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
