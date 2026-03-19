import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/Innovator/models/payment_model.dart';

class PaymentService {
  final Dio dio = Dio();
  Future<List<PaymentModel>> fetchPayment() async {
    try {
      final authToken = await AppData().accessToken;
      final response = await dio.get(
        'http://182.93.94.210:3067/api/v1/payment-methods',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'authorization': 'Bearer $authToken',
          },
        ),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        final List<PaymentModel> payment =
            data.map((e) => PaymentModel.fromJson(e)).toList();
        log(' ${payment.length} Payment Available');
        return payment;
      } else {
        throw Exception('Something went wrong');
      }
    } on DioException catch (e) {
      log('$e');
      throw Exception('Failed to get the payment option');
    }
  }
}
