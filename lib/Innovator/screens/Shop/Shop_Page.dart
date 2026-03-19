// //shopepage.dart
// import 'dart:developer' as developer;

// import 'package:flutter/material.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:http/http.dart' as http;
// import 'package:get/get.dart';
// import 'package:innovator/Innovator/App_data/App_data.dart';
// import 'package:innovator/Innovator/screens/Shop/CardIconWidget/CardIconWidget.dart';
// import 'package:innovator/Innovator/screens/Shop/CardIconWidget/cart_state_manager.dart';
// import 'package:innovator/Innovator/screens/Shop/Cart_List/cart_screen.dart';
// import 'package:innovator/Innovator/screens/Shop/Cart_List/orders_page.dart';
// import 'package:innovator/Innovator/screens/Shop/Product_detail_Page.dart';
// import 'dart:convert';

// import 'package:innovator/Innovator/widget/FloatingMenuwidget.dart';
// import 'package:lottie/lottie.dart';

// class ShopPage extends StatefulWidget {
//   const ShopPage({Key? key}) : super(key: key);

//   @override
//   _ShopPageState createState() => _ShopPageState();
// }

// class _ShopPageState extends State<ShopPage>
//     with SingleTickerProviderStateMixin {
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//   final AppData _appData = AppData();
//   List<dynamic> _products = [];
//   List<dynamic> _categories = [];
//   int _currentPage = 0;
//   bool _isLoading = false;
//   bool _hasMore = true;
//   bool _isError = false;
//   String? _errorMessage;
//   final ScrollController _scrollController = ScrollController();
//   final String _baseUrl = "http://182.93.94.210:3067";
//   final double _scrollThreshold = 200.0;
//   final int _pageSize = 10;
//   Map<String, bool> _addingToCart = {};
//   bool _isMounted = true;
//   final TextEditingController _searchController = TextEditingController();
//   String _searchQuery = '';
//   String? _selectedCategoryId;
//   DateTime? _lastSearchTime;
//   String sortBy = 'name';
//   bool ascending = true;
//   late CartStateManager cartManager;
//   List<dynamic>? _cachedFilteredProducts;
//   String? _lastSearchQueryCached;
//   String? _lastSortByCached;
//   bool? _lastAscendingCached;

//   @override
//   void initState() {
//     super.initState();

//     if (!Get.isRegistered<CartStateManager>()) {
//       Get.put(CartStateManager(), permanent: true);
//     }
//     cartManager = Get.find<CartStateManager>();

//     _initializeData();
//     _scrollController.addListener(_scrollListener);
//     _searchController.addListener(_onSearchChanged);

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       cartManager.loadCartCount();
//     });
//   }

//   Future<void> _initializeData() async {
//     await _appData.initialize();
//     await _loadCategories();
//     _loadProducts();
//   }

//   Future<void> _loadCategories() async {
//     try {
//       final headers = {
//         'Content-Type': 'application/json',
//         if (_appData.accessToken != null)
//           'authorization': 'Bearer ${_appData.accessToken}',
//       };

//       developer.log('Loading categories from: $_baseUrl/api/v1/categories');

//       final response = await http
//           .get(Uri.parse('$_baseUrl/api/v1/categories'), headers: headers)
//           .timeout(const Duration(seconds: 10));

//       developer.log('Categories response status: ${response.statusCode}');
//       developer.log('Categories response body: ${response.body}');

//       if (response.statusCode == 200) {
//         try {
//           final data = json.decode(response.body);

//           List<dynamic> categoryList = [];

//           if (data is Map<String, dynamic>) {
//             if (data['data'] != null) {
//               if (data['data']['categories'] is List) {
//                 categoryList = data['data']['categories'] as List;
//               } else if (data['data'] is List) {
//                 categoryList = data['data'] as List;
//               }
//             } else if (data['categories'] is List) {
//               categoryList = data['categories'] as List;
//             } else if (data is List) {
//               categoryList = data as List;
//             }
//           } else if (data is List) {
//             categoryList = data as List;
//           }

//           if (_isMounted && categoryList.isNotEmpty) {
//             setState(() {
//               _categories = categoryList;
//             });
//             developer.log('Loaded ${categoryList.length} categories');
//           } else {
//             developer.log('No categories found in response');
//           }
//         } catch (jsonError) {
//           developer.log('JSON parsing error for categories: $jsonError');
//           developer.log('Response body: ${response.body}');
//         }
//       } else {
//         developer.log('Categories API returned status: ${response.statusCode}');
//         developer.log('Response body: ${response.body}');
//       }
//     } catch (e) {
//       developer.log('Error loading categories: $e');
//     }
//   }

//   void _onSearchChanged() {
//     final now = DateTime.now();
//     if (_lastSearchTime == null ||
//         now.difference(_lastSearchTime!).inMilliseconds > 500) {
//       _lastSearchTime = now;
//       final newQuery = _searchController.text.trim();

//       if (newQuery != _searchQuery) {
//         setState(() {
//           _searchQuery = newQuery;
//           _clearFilterCache();
//         });
//         _resetAndLoadProducts();
//       }
//     }
//   }

//   Future<void> _resetAndLoadProducts() async {
//     if (!_isMounted) return;

//     Future<void> _resetAndLoadProducts() async {
//       if (!_isMounted) return;

//       setState(() {
//         _products.clear();
//         _currentPage = 0;
//         _hasMore = true;
//         _isError = false;
//         _errorMessage = null;
//       });

//       await _loadProducts();
//     }
//   }

//   List<dynamic> _getFilteredAndSortedProducts() {
//     // Check if we can use cached results
//     if (_cachedFilteredProducts != null &&
//         _lastSearchQueryCached == _searchQuery &&
//         _lastSortByCached == sortBy &&
//         _lastAscendingCached == ascending) {
//       return _cachedFilteredProducts!;
//     }

//     // Perform filtering and sorting
//     var filtered = _products;

//     if (_searchQuery.isNotEmpty) {
//       final query = _searchQuery.toLowerCase();
//       filtered =
//           filtered.where((product) {
//             final name = (product['name'] ?? '').toString().toLowerCase();
//             return name.contains(query);
//           }).toList();
//     }

//     filtered = List.from(filtered);
//     filtered.sort((a, b) {
//       int comparison = 0;

//       if (sortBy == 'name') {
//         final nameA = (a['name'] ?? '').toString().toLowerCase();
//         final nameB = (b['name'] ?? '').toString().toLowerCase();
//         comparison = nameA.compareTo(nameB);
//       } else if (sortBy == 'price') {
//         final priceA = (a['price'] ?? 0).toDouble();
//         final priceB = (b['price'] ?? 0).toDouble();
//         comparison = priceA.compareTo(priceB);
//       }

//       return ascending ? comparison : -comparison;
//     });

//     // Cache the results
//     _cachedFilteredProducts = filtered;
//     _lastSearchQueryCached = _searchQuery;
//     _lastSortByCached = sortBy;
//     _lastAscendingCached = ascending;

//     return filtered;
//   }

//   void _clearFilterCache() {
//     _cachedFilteredProducts = null;
//     _lastSearchQueryCached = null;
//     _lastSortByCached = null;
//     _lastAscendingCached = null;
//   }

//   Future<void> _loadProducts() async {
//     if (_isLoading || !_hasMore) return;

//     if (!_isMounted) return;

//     setState(() {
//       _isLoading = true;
//       _isError = false;
//       _errorMessage = null;
//     });

//     try {
//       final headers = {
//         'Content-Type': 'application/json',
//         if (_appData.accessToken != null)
//           'authorization': 'Bearer ${_appData.accessToken}',
//       };

//       developer.log(
//         'Loading products from page $_currentPage (limit: $_pageSize, search: $_searchQuery, category: $_selectedCategoryId)',
//       );

//       final queryParams = <String, String>{
//         'page': _currentPage.toString(),
//         'limit': _pageSize.toString(),
//       };

//       if (_searchQuery.isNotEmpty) {
//         queryParams['search'] = _searchQuery;
//       }

//       if (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty) {
//         queryParams['category'] = _selectedCategoryId!;
//       }

//       final uri = Uri.parse(
//         '$_baseUrl/api/v1/products',
//       ).replace(queryParameters: queryParams);

//       final response = await http
//           .get(uri, headers: headers)
//           .timeout(
//             const Duration(seconds: 15),
//             onTimeout: () {
//               throw Exception(
//                 'Connection timeout. Please check your internet connection.',
//               );
//             },
//           );

//       if (!_isMounted) return;

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         developer.log('API Response: ${response.body}');

//         if (data['data'] != null && data['data']['products'] is List) {
//           final newProducts = data['data']['products'] as List;
//           developer.log('Received ${newProducts.length} products');

//           if (!_isMounted) return;

//           setState(() {
//             _products.addAll(newProducts);
//             _currentPage++;
//             _hasMore = data['data']['hasMore'] ?? false;
//             _clearFilterCache();
//           });
//         } else {
//           if (!_isMounted) return;

//           setState(() {
//             _hasMore = false;
//           });
//         }
//       } else {
//         if (!_isMounted) return;

//         setState(() {
//           _isError = true;
//           _errorMessage = 'Server error: ${response.statusCode}';
//         });
//         _showErrorSnackbar('Failed to load products:');
//       }
//     } catch (e) {
//       if (!_isMounted) return;

//       setState(() {
//         _isError = true;
//         _errorMessage = e.toString();
//       });
//       developer.log('Error loading products: $e');
//       _showErrorSnackbar('Error: ${e.toString()}');
//     } finally {
//       if (_isMounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   void _showSortBottomSheet() {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: Colors.transparent,
//       builder:
//           (context) => Container(
//             decoration: const BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Container(
//                   margin: const EdgeInsets.only(top: 12),
//                   width: 40,
//                   height: 4,
//                   decoration: BoxDecoration(
//                     color: Colors.grey[300],
//                     borderRadius: BorderRadius.circular(2),
//                   ),
//                 ),
//                 const Padding(
//                   padding: EdgeInsets.all(20),
//                   child: Text(
//                     'Sort Products',
//                     style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                   ),
//                 ),
//                 _buildSortTile(
//                   title: 'Name (A → Z)',
//                   isSelected: sortBy == 'name' && ascending,
//                   onTap: () {
//                     setState(() {
//                       sortBy = 'name';
//                       ascending = true;
//                       _clearFilterCache();
//                     });
//                     Navigator.pop(context);
//                   },
//                 ),
//                 _buildSortTile(
//                   title: 'Name (Z → A)',
//                   isSelected: sortBy == 'name' && !ascending,
//                   onTap: () {
//                     setState(() {
//                       sortBy = 'name';
//                       ascending = false;
//                       _clearFilterCache();
//                     });
//                     Navigator.pop(context);
//                   },
//                 ),
//                 _buildSortTile(
//                   title: 'Price (Low → High)',
//                   isSelected: sortBy == 'price' && ascending,
//                   onTap: () {
//                     setState(() {
//                       sortBy = 'price';
//                       ascending = true;
//                       _clearFilterCache();
//                     });
//                     Navigator.pop(context);
//                   },
//                 ),
//                 _buildSortTile(
//                   title: 'Price (High → Low)',
//                   isSelected: sortBy == 'price' && !ascending,
//                   onTap: () {
//                     setState(() {
//                       sortBy = 'price';
//                       ascending = false;
//                       _clearFilterCache();
//                     });
//                     Navigator.pop(context);
//                   },
//                 ),
//                 const SizedBox(height: 20),
//               ],
//             ),
//           ),
//     );
//   }

//   Widget _buildSortTile({
//     required String title,
//     required bool isSelected,
//     required VoidCallback onTap,
//   }) {
//     return ListTile(
//       leading: Icon(
//         isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
//         color: isSelected ? Colors.blue : Colors.grey,
//       ),
//       title: Text(
//         title,
//         style: TextStyle(
//           fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
//           color: isSelected ? Colors.blue : Colors.black87,
//         ),
//       ),
//       onTap: onTap,
//     );
//   }

//   Future<void> _addToCart(
//     String productId,
//     double price, {
//     int quantity = 1,
//   }) async {
//     if (_appData.accessToken == null) {
//       _showErrorSnackbar('Please log in to add items to your cart');
//       return;
//     }

//     final product = _products.firstWhere(
//       (p) => p['_id'] == productId,
//       orElse: () => {'name': 'Unknown Product'},
//     );
//     final String productName = product['name'] ?? 'Unknown Product';

//     if (!_isMounted) return;

//     setState(() {
//       _addingToCart[productId] = true;
//     });

//     developer.log('🛒 Adding $productName to cart (quantity: $quantity)');

//     cartManager.incrementCartCount(quantity);

//     try {
//       final headers = {
//         'Content-Type': 'application/json',
//         'authorization': 'Bearer ${_appData.accessToken}',
//       };

//       final response = await http
//           .post(
//             Uri.parse('$_baseUrl/api/v1/add-to-cart'),
//             headers: headers,
//             body: json.encode({
//               'product': productId,
//               'productName': productName,
//               'quantity': quantity,
//               'price': price,
//             }),
//           )
//           .timeout(
//             const Duration(seconds: 10),
//             onTimeout: () {
//               throw Exception(
//                 'Connection timeout. Please check your internet connection.',
//               );
//             },
//           );

//       if (!_isMounted) return;

//       developer.log('API Response Status: ${response.statusCode}');
//       developer.log('API Response Body: ${response.body}');

//       if (response.statusCode == 200 || response.statusCode == 201) {
//         final data = json.decode(response.body);

//         bool isSuccess = false;
//         String message = '';

//         if (data['success'] == true) {
//           isSuccess = true;
//           message = data['message'] ?? '$productName added to cart';
//         } else if (data['message'] != null) {
//           final messageText = data['message'].toString().toLowerCase();
//           if (messageText.contains('added') ||
//               messageText.contains('success') ||
//               messageText.contains('cart')) {
//             isSuccess = true;
//             message = data['message'];
//           } else {
//             isSuccess = false;
//             message = data['message'];
//           }
//         } else if (data['status'] == 'success' || data['status'] == 200) {
//           isSuccess = true;
//           message = '$productName added to cart';
//         } else {
//           message = '$productName added to cart';
//         }

//         if (isSuccess) {
//           if (_isMounted) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 content: Row(
//                   children: [
//                     const Icon(Icons.check_circle, color: Colors.white),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: Row(
//                         children: [
//                           Text(message),
//                           TextButton(
//                             onPressed: () {
//                               ScaffoldMessenger.of(
//                                 context,
//                               ).hideCurrentSnackBar();
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(builder: (_) => CartScreen()),
//                               ).then((_) {
//                                 if (_isMounted) {
//                                   cartManager.refreshCartCount();
//                                 }
//                               });
//                             },
//                             child: Text(
//                               'View Cart',
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//                 backgroundColor: Colors.green,
//                 duration: const Duration(seconds: 5),
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 12,
//                   vertical: 0,
//                 ),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//               ),
//             );
//           }
//           developer.log('$productName added to cart successfully');
//         } else {
//           cartManager.decrementCartCount(quantity);
//           if (_isMounted) {
//             _showErrorSnackbar(message);
//           }
//           developer.log(' API returned failure: $message');
//         }
//       } else {
//         cartManager.decrementCartCount(quantity);
//         if (_isMounted) {
//           _showErrorSnackbar(
//             'Failed to add $productName to cart: ${response.statusCode}',
//           );
//         }
//         developer.log(' HTTP Error: ${response.statusCode}');
//       }
//     } catch (e) {
//       cartManager.decrementCartCount(quantity);
//       developer.log(' Error adding $productName to cart: $e');
//       if (_isMounted) {
//         _showErrorSnackbar('Error adding $productName: ${e.toString()}');
//       }
//     } finally {
//       if (_isMounted) {
//         setState(() {
//           _addingToCart.remove(productId);
//         });
//       }
//     }
//   }

//   void _scrollListener() {
//     if (_scrollController.hasClients &&
//         _scrollController.position.extentAfter < _scrollThreshold &&
//         !_isLoading &&
//         _hasMore &&
//         !_scrollController.position.outOfRange) {
//       _loadProducts();
//     }
//   }

//   void _showErrorSnackbar(String message) {
//     if (!_isMounted) return;

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             const Icon(Icons.error, color: Colors.white),
//             const SizedBox(width: 12),
//             Expanded(child: Text(message)),
//           ],
//         ),
//         backgroundColor: Colors.green,
//         duration: const Duration(microseconds: 500),
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//         action: SnackBarAction(
//           label: 'Dismiss',
//           textColor: Colors.white,
//           onPressed: () {},
//         ),
//       ),
//     );
//   }

//   Future<void> _refreshProducts() async {
//     _searchController.clear();
//     _selectedCategoryId = null;
//     await _resetAndLoadProducts();
//     cartManager.refreshCartCount();
//     _clearFilterCache();
//     //if (!_isMounted) return;

//     // setState(() {
//     //   _products.clear();
//     //   _currentPage = 0;
//     //   _hasMore = true;
//     //   _searchQuery = '';
//     //   _searchController.clear();
//     //   _selectedCategoryId = null;
//     //   _clearFilterCache();
//     // });
//     // await _loadProducts();

//     // cartManager.refreshCartCount();
//   }

//   @override
//   void dispose() {
//     _isMounted = false;
//     _scrollController.dispose();
//     _searchController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     // KEY FIX: Calculate filtered products once per build
//     final filteredProducts = _getFilteredAndSortedProducts();

//     return Scaffold(
//       floatingActionButton: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             colors: [
//               Color.fromRGBO(244, 135, 6, 1),
//               Color.fromRGBO(244, 135, 6, 1),
//             ],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//           borderRadius: BorderRadius.circular(20),
//         ),
//         child: ShoppingCartBadge(
//           onPressed: () {
//             Navigator.push(
//               context,
//               MaterialPageRoute(builder: (_) => CartScreen()),
//             ).then((_) {
//               if (_isMounted) {
//                 cartManager.refreshCartCount();
//               }
//             });
//           },
//           badgeColor: Colors.red,
//           iconColor: Colors.white,
//         ),
//       ),
//       key: _scaffoldKey,
//       backgroundColor: Colors.grey[50],
//       body: Stack(
//         children: [
//           _buildBody(filteredProducts), // Pass the pre-calculated list
//           //   FloatingMenuWidget(),
//           _buildTopBar(),
//         ],
//       ),
//     );
//   }

//   Widget _buildTopBar() {
//     return Positioned(
//       top: MediaQuery.of(context).padding.top + 10,
//       left: 16,
//       right: 16,
//       child: Column(
//         children: [
//           Row(
//             children: [
//               Expanded(
//                 child: Container(
//                   decoration: BoxDecoration(
//                     color: Colors.grey[100],
//                     borderRadius: BorderRadius.circular(20),
//                     border: Border.all(color: Colors.grey.shade300),
//                   ),
//                   child: TextFormField(
//                     controller: _searchController,
//                     decoration: InputDecoration(
//                       hintText: 'Search products...',
//                       hintStyle: TextStyle(color: Colors.grey[600]),
//                       suffixIcon:
//                           _searchQuery.isNotEmpty
//                               ? IconButton(
//                                 icon: Icon(Icons.clear, size: 20),
//                                 onPressed: () {
//                                   _searchController.clear();
//                                   setState(() => _searchQuery = '');
//                                 },
//                               )
//                               : Icon(Icons.search, color: Colors.grey[600]),
//                       border: InputBorder.none,
//                       contentPadding: const EdgeInsets.symmetric(
//                         horizontal: 16,
//                         vertical: 12,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//               IconButton(
//                 onPressed: _showSortBottomSheet,
//                 icon: Stack(
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.all(6),
//                       decoration: BoxDecoration(
//                         color: Colors.grey[200],
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: const Icon(
//                         Icons.settings_input_component,
//                         size: 18,
//                         color: Colors.black,
//                       ),
//                     ),
//                     if (sortBy != 'name' || !ascending)
//                       Positioned(
//                         right: 0,
//                         top: 0,
//                         child: Container(
//                           padding: const EdgeInsets.all(2),
//                           decoration: const BoxDecoration(
//                             color: Colors.blue,
//                             shape: BoxShape.circle,
//                           ),
//                           child: const Icon(
//                             Icons.check,
//                             size: 8,
//                             color: Colors.white,
//                           ),
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//               IconButton(
//                 onPressed: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => OrdersHistoryPage(),
//                     ),
//                   );
//                 },
//                 icon: Container(
//                   padding: const EdgeInsets.all(6),
//                   decoration: BoxDecoration(
//                     color: Colors.grey[200],
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: const Icon(
//                     Icons.history_rounded,
//                     size: 22,
//                     color: Colors.black,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   // KEY FIX: Accept filteredProducts as parameter
//   Widget _buildBody(List<dynamic> filteredProducts) {
//     if (_isError && _products.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Lottie.asset('animation/No_Internet.json', fit: BoxFit.fill),
//             //Icon(Icons.error_outline, color: Colors.red, size: 64),
//             const SizedBox(height: 16),
//             // Text(
//             //   _errorMessage ?? 'Something went wrong',
//             //   style: TextStyle(fontSize: 16, color: Colors.grey[600]),
//             //   textAlign: TextAlign.center,
//             // ),
//             const SizedBox(height: 16),
//             ElevatedButton.icon(
//               onPressed: _loadProducts,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.blue,
//                 foregroundColor: Colors.white,
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 32,
//                   vertical: 12,
//                 ),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//               ),
//               label: const Text('Retry'),
//               icon: Icon(Icons.refresh),
//             ),
//           ],
//         ),
//       );
//     }

//     // Show loading only when products list is completely empty
//     if (_products.isEmpty && _isLoading) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             CircularProgressIndicator(
//               valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
//             ),
//           ],
//         ),
//       );
//     }

//     if (filteredProducts.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.shopping_bag_outlined,
//               size: 80,
//               color: Colors.grey[400],
//             ),
//             const SizedBox(height: 16),
//             Text(
//               _searchQuery.isNotEmpty || _selectedCategoryId != null
//                   ? 'No products found for current search/category'
//                   : 'No products available',
//               style: TextStyle(fontSize: 18, color: Colors.grey[600]),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 16),
//           ],
//         ),
//       );
//     }

//     return RefreshIndicator(
//       onRefresh: _refreshProducts,
//       color: Colors.blue,
//       child: Column(
//         children: [
//           const SizedBox(height: 130),
//           Expanded(
//             child: GridView.builder(
//               controller: _scrollController,
//               padding: EdgeInsets.only(right: 5, left: 5, bottom: 45),
//               gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisSpacing: 10,
//                 crossAxisCount: 2,
//                 mainAxisSpacing: 10,
//                 childAspectRatio: 0.66,
//               ),
//               // KEY FIX: Use passed parameter instead of calling function
//               itemCount:
//                   filteredProducts.length + (_isLoading && _hasMore ? 1 : 0),
//               itemBuilder: (context, index) {
//                 if (index >= filteredProducts.length) {
//                   return _buildLoader();
//                 }
//                 // KEY FIX: Use passed parameter
//                 return _buildProductCard(filteredProducts[index]);
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildLoader() {
//     return const Center(
//       child: Padding(
//         padding: EdgeInsets.all(16.0),
//         child: CircularProgressIndicator(
//           valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
//         ),
//       ),
//     );
//   }

//   Widget _buildProductCard(dynamic product) {
//     final String id = product['_id'] ?? '';
//     final String name = product['name'] ?? 'Unknown Product';
//     final double price = (product['price'] ?? 0.0).toDouble();
//     final int stock = (product['stock']?.toInt() ?? 0);
//     final List<dynamic> images = product['images'] ?? [];
//     final String imageUrl = images.isNotEmpty ? '$_baseUrl${images[0]}' : '';
//     final bool isAddingToCart = _addingToCart[id] ?? false;
//     final String category = product['category']?['name'] ?? 'Uncategorized';

//     return GestureDetector(
//       onTap: () {
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder:
//                 (context) => ProductDetailPage(
//                   productId: id,
//                   baseUrl: _baseUrl,
//                   authToken: _appData.accessToken,
//                 ),
//           ),
//         );
//       },
//       child: Card(
//         color: Colors.white,
//         elevation: 3,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         child: ClipRRect(
//           borderRadius: BorderRadius.circular(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Container(
//                 height: 140,
//                 width: double.infinity,
//                 color: Colors.grey[200],
//                 child:
//                     imageUrl.isNotEmpty
//                         ? CachedNetworkImage(
//                           imageUrl: imageUrl,
//                           fit: BoxFit.cover,
//                           placeholder:
//                               (context, url) => const Center(
//                                 child: CircularProgressIndicator(
//                                   strokeWidth: 2,
//                                 ),
//                               ),
//                           errorWidget:
//                               (context, url, error) => const Icon(
//                                 Icons.image_not_supported,
//                                 size: 40,
//                                 color: Colors.grey,
//                               ),
//                         )
//                         : const Icon(
//                           Icons.image_not_supported,
//                           size: 40,
//                           color: Colors.grey,
//                         ),
//               ),
//               Expanded(
//                 child: Padding(
//                   padding: const EdgeInsets.only(
//                     right: 10,
//                     left: 10,
//                     bottom: 10,
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         name,
//                         style: const TextStyle(
//                           fontWeight: FontWeight.bold,
//                           fontSize: 14,
//                           color: Colors.black87,
//                         ),
//                         maxLines: 2,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 8,
//                           vertical: 4,
//                         ),
//                         decoration: BoxDecoration(
//                           color: Colors.blue.withAlpha(50),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: Text(
//                           category,
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                           style: TextStyle(
//                             fontSize: 10,
//                             color: Colors.blue.shade700,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             'Rs ${price.toInt()}',
//                             style: TextStyle(
//                               fontSize: 12,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.black87,
//                             ),
//                           ),
//                           SizedBox(
//                             width: 36,
//                             height: 36,
//                             child: ElevatedButton(
//                               onPressed:
//                                   (stock > 0 && !isAddingToCart)
//                                       ? () => _addToCart(id, price)
//                                       : null,
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: const Color.fromRGBO(
//                                   244,
//                                   135,
//                                   6,
//                                   1,
//                                 ),
//                                 padding: EdgeInsets.zero,
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(10),
//                                 ),
//                               ),
//                               child:
//                                   isAddingToCart
//                                       ? const SizedBox(
//                                         width: 16,
//                                         height: 16,
//                                         child: CircularProgressIndicator(
//                                           color: Colors.white,
//                                           strokeWidth: 2,
//                                         ),
//                                       )
//                                       : const Icon(
//                                         Icons.add,
//                                         size: 18,
//                                         color: Colors.white,
//                                       ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

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
