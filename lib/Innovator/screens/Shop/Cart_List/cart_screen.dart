import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/Innovator/screens/Shop/Cart_List/Update%20Cart/update_provider.dart';
import 'package:innovator/Innovator/screens/Shop/Cart_List/api_services.dart';
import 'package:innovator/Innovator/screens/Shop/checkout.dart';
import 'package:innovator/Innovator/widget/FloatingMenuwidget.dart';
import '../../../models/Shop_cart_model.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final ApiService _apiService = ApiService();
  late Future<CartListResponse> _cartListFuture;
  final AppData _appData = AppData();
  int _cartItemCount = 0;

  // Local cart management
  List<CartItem> _localCartItems = [];
  bool _isLoading = false;

  // Define color scheme for the cart
  final Color _primaryColor = Colors.indigo;
  final Color _accentColor = Colors.green;
  final Color _cardColor = Colors.white;
  final Color _textColor = Colors.blueGrey.shade800;
  final Color _priceColor = Colors.green.shade700;

  @override
  void initState() {
    super.initState();
    _loadCartItems();
  }

  void _loadCartItems() {
    setState(() {
      _isLoading = true;
    });

    _cartListFuture = _apiService
        .getCartList()
        .then((cartResponse) {
          setState(() {
            _localCartItems = List.from(cartResponse.data);
            _cartItemCount = _localCartItems.length;
            _isLoading = false;
          });
          return cartResponse;
        })
        .catchError((error) {
          setState(() {
            _isLoading = false;
          });
          throw error;
        });
  }

  // Updated quantity update function using Riverpod
  Future<void> _updateCartItemQuantityLocal(
    String productId,
    int newQuantity,
  ) async {
    if (newQuantity <= 0) {
      return;
    }

    // Optimistically update UI
    setState(() {
      final itemIndex = _localCartItems.indexWhere(
        (item) => item.productId == productId,
      );
      if (itemIndex != -1) {
        _localCartItems[itemIndex] = CartItem(
          id: _localCartItems[itemIndex].id,
          email: _localCartItems[itemIndex].email,
          productId: _localCartItems[itemIndex].productId,
          productName: _localCartItems[itemIndex].productName,
          price: _localCartItems[itemIndex].price,
          quantity: newQuantity,
          v: _localCartItems[itemIndex].v,
          images: _localCartItems[itemIndex].images,
        );
      }
    });

    // Update via API using Riverpod
    try {
      final result = await ref.read(
        updateCartProvider((productId, newQuantity)).future,
      );

      log(
        'Cart updated successfully: ${result.product}, quantity: ${result.quantity}',
      );

      // Optional: Show success feedback
      if (kDebugMode)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Cart updated'),
              backgroundColor: _accentColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(milliseconds: 800),
            ),
          );
        }
    } catch (e) {
      log('Failed to update cart: $e');

      // Revert the optimistic update on error
      _loadCartItems();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update cart. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Local delete function
  void _deleteCartItemLocal(String itemId) {
    setState(() {
      _localCartItems.removeWhere((item) => item.id == itemId);
      _cartItemCount = _localCartItems.length;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Item removed from cart'),
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 800),
      ),
    );

    // Sync with server in background
    _syncDeleteWithServerInBackground(itemId);
  }

  Future<void> _syncDeleteWithServerInBackground(String itemId) async {
    try {
      await _apiService.deleteCartItem(itemId);
      log('Synced deletion of item $itemId to server');
    } catch (e) {
      log('Background delete sync failed: $e');
    }
  }

  // Calculate total cart value
  double _calculateTotalCartValue() {
    double total = 0;
    for (var item in _localCartItems) {
      total += (item.price * item.quantity);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'My Cart',
              style: TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 22,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$_cartItemCount Items',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            color: Colors.black,
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
      ),
      backgroundColor: Colors.white,
      key: _scaffoldKey,
      body: Stack(
        children: [
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
                ),
              )
              : _buildCartContent(),
          // const FloatingMenuWidget(),
        ],
      ),
    );
  }

  Widget _buildCartContent() {
    if (_localCartItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: _primaryColor.withAlpha(50),
            ),
            const SizedBox(height: 16),
            Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.shopping_bag),
              label: const Text('Start Shopping'),
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final totalCartValue = _calculateTotalCartValue();

    return Column(
      children: [
        Flexible(
          child: ListView.builder(
            itemCount: _localCartItems.length,
            itemBuilder: (context, index) {
              final item = _localCartItems[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCartItemCard(item),
                  const Divider(thickness: 1, endIndent: 10, indent: 10),
                ],
              );
            },
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(bottom: 20, right: 20, left: 20),
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => CheckoutScreen(
                        totalAmount: totalCartValue,
                        itemCount: _localCartItems.length,
                        cartItems: _localCartItems,
                      ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromRGBO(244, 135, 6, 1),
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
            ),
            child: Text(
              'PROCEED TO CHECKOUT (Rs ${totalCartValue.toStringAsFixed(2)})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCartItemCard(CartItem item) {
    return Padding(
      padding: const EdgeInsets.only(right: 10, left: 10, top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 150,
            width: 150,
            decoration: BoxDecoration(
              border: Border.all(color: _primaryColor.withAlpha(20)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SafeImage(
                images: item.images,
                baseUrl: 'http://182.93.94.210:3067',
                placeholderIcon: Icons.image,
                placeholderColor: _primaryColor.withAlpha(20),
                iconSize: 40,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        item.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        showAdaptiveDialog(
                          barrierDismissible: false,
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              backgroundColor: Colors.white,
                              title: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Remove Item',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.red.shade400,
                                    ),
                                  ],
                                ),
                              ),
                              content: const Text(
                                'Are you sure you want to remove this item from your cart?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: const Text(
                                    'No',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _deleteCartItemLocal(item.id.toString());
                                  },
                                  child: const Text(
                                    'Yes',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      icon: Icon(Icons.delete, color: Colors.red.shade400),
                    ),
                  ],
                ),
                Text(
                  'Quantity: ${item.quantity}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                    fontStyle: FontStyle.normal,
                    fontFamily: 'Monteserrat',
                  ),
                ),
                FittedBox(
                  child: Container(
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        Container(
                          margin: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.remove,
                              size: 25,
                              color:
                                  item.quantity == 1
                                      ? Colors.grey
                                      : Colors.black,
                            ),
                            onPressed:
                                item.quantity > 1
                                    ? () {
                                      _updateCartItemQuantityLocal(
                                        item.productId,
                                        item.quantity - 1,
                                      );
                                    }
                                    : null,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        Container(
                          width: 28,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _accentColor.withAlpha(8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${item.quantity}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.add,
                              size: 25,
                              color: Colors.black,
                            ),
                            onPressed: () {
                              _updateCartItemQuantityLocal(
                                item.productId,
                                item.quantity + 1,
                              );
                              log(
                                'Plus button clicked for item: ${item.productId}',
                              );
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    'RS ${(item.price * item.quantity).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.8,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SafeImage extends StatelessWidget {
  final List<String>? images;
  final String? baseUrl;
  final IconData placeholderIcon;
  final Color placeholderColor;
  final double iconSize;

  const SafeImage({
    Key? key,
    this.images,
    this.baseUrl,
    this.placeholderIcon = Icons.image,
    this.placeholderColor = Colors.grey,
    this.iconSize = 40,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (images == null || images!.isEmpty) {
      return Center(
        child: Icon(placeholderIcon, color: placeholderColor, size: iconSize),
      );
    }

    final imageUrl =
        baseUrl != null ? '$baseUrl${images!.first}' : images!.first;

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder:
          (context, url) => Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(placeholderColor),
            ),
          ),
      errorWidget:
          (context, url, error) => Center(
            child: Icon(
              placeholderIcon,
              color: placeholderColor,
              size: iconSize,
            ),
          ),
    );
  }
}
