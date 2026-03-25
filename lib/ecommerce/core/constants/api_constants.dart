class EcommerApi {
  static const String baseUrl = 'http://182.93.94.220:8004/api';
  static const String productList = '$baseUrl/products';

// time out
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(seconds: 120);
}
