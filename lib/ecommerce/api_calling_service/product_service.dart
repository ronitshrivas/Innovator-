import 'dart:developer';

import 'package:innovator/ecommerce/core/constants/api_constants.dart';
import 'package:innovator/ecommerce/core/constants/network/base_api_service.dart';
import 'package:innovator/ecommerce/core/constants/network/dio_client.dart';
import 'package:innovator/ecommerce/model/cart_model.dart';
import 'package:innovator/ecommerce/model/product_model.dart';

class ProductListService extends BaseApiService {
  ProductListService() : super(dio: DioClient.instance);

  Future<List<ProductModel>> getProductList() async {
    final data = await get<List<dynamic>>(EcommerApi.productList);
    final products = ProductModel.fromJsonList(data);
    log('Products: $products');
    return products;
  }

  Future<Map<String, dynamic>> addCartItem({required String product}) async {
    return await post(EcommerApi.cartItems, data: {'product': product});
  }
    Future<List<CartItemModel>> getCartList() async {
    final data = await get<List<dynamic>>(EcommerApi.cartItems);
    final items = CartItemModel.fromJsonList(data);
    log('Cart items: $items');
    return items;
  }
}
