import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/ecommerce/api_calling_service/product_service.dart';
import 'package:innovator/ecommerce/model/cart_model.dart';
import 'package:innovator/ecommerce/model/product_model.dart';

final productServiceProvider = Provider<ProductListService>(
  (_) => ProductListService(),
);

final productListProvider = FutureProvider<List<ProductModel>>((ref) {
  return ref.watch(productServiceProvider).getProductList();
});

final addCartItemProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, productId) {
    return ref.watch(productServiceProvider).addCartItem(product: productId);
  },
);

final cartListProvider = FutureProvider<List<CartItemModel>>((ref) {
  return ref.watch(productServiceProvider).getCartList();
});
 
final cartCountProvider = Provider<int>((ref) {
  return ref.watch(cartListProvider).maybeWhen(
    data: (items) => items.length,
    orElse: () => 0,
  );
});