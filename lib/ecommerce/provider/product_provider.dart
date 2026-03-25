import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/ecommerce/api_calling_service/product_list_service.dart';
import 'package:innovator/ecommerce/model/product_model.dart';

final productServiceProvider = Provider<ProductListService>(
  (_) => ProductListService(),
);

final productListProvider = FutureProvider<List<ProductModel>>((ref) {
  return ref.watch(productServiceProvider).getProductList();
});