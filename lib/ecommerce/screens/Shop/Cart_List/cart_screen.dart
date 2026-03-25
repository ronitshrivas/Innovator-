import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/ecommerce/model/cart_model.dart';
import 'package:innovator/ecommerce/provider/product_provider.dart';
import 'package:innovator/ecommerce/screens/Shop/checkout.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({Key? key}) : super(key: key);

  static const _orange = Color.fromRGBO(244, 135, 6, 1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartListProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'My Cart',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          cartAsync.maybeWhen(
            data:
                (items) =>
                    items.isEmpty
                        ? const SizedBox.shrink()
                        : Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Center(
                            child: Text(
                              '${items.length} item${items.length > 1 ? 's' : ''}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: cartAsync.when(
        loading:
            () =>
                const Center(child: CircularProgressIndicator(color: _orange)),
        error:
            (e, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load cart',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => ref.refresh(cartListProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(backgroundColor: _orange),
                  ),
                ],
              ),
            ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 90,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add items from the shop',
                    style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }

          final grandTotal = items.fold<double>(0, (sum, i) => sum + i.total);

          return Column(
            children: [
              // ── List ──
              Expanded(
                child: RefreshIndicator(
                  color: _orange,
                  onRefresh: () async => ref.refresh(cartListProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder:
                        (context, index) => _CartItemCard(item: items[index]),
                  ),
                ),
              ),

              // ── Summary footer ──
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(15),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${items.length} item${items.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          'Rs ${grandTotal.toInt()}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Grand Total',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Rs ${grandTotal.toInt()}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => CheckoutScreen(
                                    totalAmount: grandTotal,
                                    itemCount: items.length,
                                    cartItems: items,
                                  ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Proceed to Checkout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Single cart item card ──
class _CartItemCard extends ConsumerWidget {
  final CartItemModel item;
  const _CartItemCard({required this.item});

  static const _orange = Color.fromRGBO(244, 135, 6, 1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Product icon placeholder ──
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: _orange,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),

          // ── Name + qty ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Qty: ${item.quantity}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Rs ${item.price.toInt()} each',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Total + remove ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rs ${item.total.toInt()}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _orange,
                ),
              ),
              const SizedBox(height: 6),
              // GestureDetector(
              //   onTap: () async {
              //     try {
              //       await ref
              //           .read(productServiceProvider)
              //           .removeCartItem(cartItemId: item.id);
              //       ref.refresh(cartListProvider);
              //       ref.refresh(cartCountProvider as Refreshable);
              //     } catch (_) {
              //       ScaffoldMessenger.of(context).showSnackBar(
              //         SnackBar(
              //           behavior: SnackBarBehavior.floating,
              //           backgroundColor: Colors.red.shade600,
              //           shape: RoundedRectangleBorder(
              //               borderRadius: BorderRadius.circular(12)),
              //           margin: const EdgeInsets.all(12),
              //           content: const Text(
              //             'Failed to remove item',
              //             style: TextStyle(color: Colors.white),
              //           ),
              //         ),
              //       );
              //     }
              //   },
              //   child: Container(
              //     padding: const EdgeInsets.all(4),
              //     decoration: BoxDecoration(
              //       color: Colors.red.withAlpha(20),
              //       borderRadius: BorderRadius.circular(6),
              //     ),
              //     child: const Icon(Icons.delete_outline,
              //         size: 18, color: Colors.red),
              //   ),
              // ),
            ],
          ),
        ],
      ),
    );
  }
}
