import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/Innovator/models/payment_model.dart';
import 'package:innovator/Innovator/Payment/payment_service.dart';

final paymentServiceProvider = Provider((ref) => PaymentService());
final paymentProvider = FutureProvider<List<PaymentModel>>((ref) async {
  final payment = ref.watch(paymentServiceProvider);
  return payment.fetchPayment();
});
