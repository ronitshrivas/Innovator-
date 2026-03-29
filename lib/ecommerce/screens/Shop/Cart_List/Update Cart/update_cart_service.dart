import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'update_cart_model.dart';

class UpdateCartService {
  final Dio _dio = Dio();

  Future<UpdateCartModel> patchCart({
    required String productId,
    required int quantity,
  }) async {
    try {
      final authToken = await AppData().accessToken;

      final response = await _dio.patch(
        'http://182.93.94.210:3067/api/v1/update-cart',
        data: {'product': productId, 'quantity': quantity},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'authorization': 'Bearer $authToken',
          },
        ),
      );

      if (response.statusCode == 200) {
        return UpdateCartModel.fromJson({
          'product': productId,
          'quantity': quantity.toString(),
        });
      } else {
        throw Exception('Failed to update cart');
      }
    } on DioException catch (e) {
      log('UpdateCartService error: $e');
      rethrow;
    }
  }
}
