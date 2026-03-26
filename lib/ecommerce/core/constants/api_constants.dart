class EcommerApi {
  static const String baseUrl = 'http://182.93.94.220:8004/api';
  static const String productList = '$baseUrl/products';
  static const String cartItems = '$baseUrl/cart-items/';
  static const String productDetails = '$baseUrl/products/';
  static String itemUpdate(String id) => '$baseUrl/cart-items/$id/';
  static const String checkout = '$baseUrl/checkout/create_order/';

  // time out
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(seconds: 120);
}
