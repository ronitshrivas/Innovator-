import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/Innovator/Payment/payment_provider.dart';

class PaymentScreen extends ConsumerWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentAsync = ref.watch(paymentProvider);
    const baseUrlImage = 'http://182.93.94.210:3067';
    return paymentAsync.when(
      data: (payments) {     
        final activePayments = payments
            .where((p) => p.active && (p.qrImage.isNotEmpty || p.cod))
            .toList();   
        if (activePayments.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Payment Methods')),
            body: const Center(
              child: Text(
                'No payment method available currently.\nUse the COD Service',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
          );
        }

        return DefaultTabController(
          length: activePayments.length,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Payment Methods'),
              bottom: TabBar(
                isScrollable: true,
                tabs: activePayments
                    .map((p) => Tab(
                          text: p.name,
                          icon: p.cod
                              ? const Icon(Icons.payments)
                              : const Icon(Icons.qr_code_scanner),
                        ))
                    .toList(),
              ),
            ),
            body: TabBarView(
              children: activePayments.map((payment) {
               
                if (payment.cod) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payments, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Cash on Delivery',
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  );
                }  
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          payment.name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: 250,
                          height: 250,
                          child: Image.network(
                            '$baseUrlImage${payment.qrImage}',
                            fit: BoxFit.contain,
                            loadingBuilder:
                                (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                  child: CircularProgressIndicator());
                            },
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.error, size: 60),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Scan the QR code to pay'),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('Something went wrong')),
      ),
    );
  }
}
