class CheckoutOrderItem {
  final String productId;
  final String productName;
  final String? image;
  final double price;
  final int quantity;
  final double lineTotal;

  const CheckoutOrderItem({
    required this.productId,
    required this.productName,
    this.image,
    required this.price,
    required this.quantity,
    required this.lineTotal,
  });

  factory CheckoutOrderItem.fromJson(Map<String, dynamic> json) =>
      CheckoutOrderItem(
        productId: json['product_id'] as String,
        productName: json['product_name'] as String,
        image: json['image'] as String?,
        price: (json['price'] as num).toDouble(),
        quantity: json['quantity'] as int,
        lineTotal: (json['line_total'] as num).toDouble(),
      );
}

class CheckoutSummaryResponse {
  final String message;
  final String orderId;
  final String fullName;
  final String address;
  final String phoneNumber;
  final String paymentType;
  final List<CheckoutOrderItem> items;
  final int totalItems;
  final double totalAmount;
  final double shippingCharge;
  final double grandTotal;
  final String status;

  const CheckoutSummaryResponse({
    required this.message,
    required this.orderId,
    required this.fullName,
    required this.address,
    required this.phoneNumber,
    required this.paymentType,
    required this.items,
    required this.totalItems,
    required this.totalAmount,
    required this.shippingCharge,
    required this.grandTotal,
    required this.status,
  });

  factory CheckoutSummaryResponse.fromJson(Map<String, dynamic> json) =>
      CheckoutSummaryResponse(
        message: json['message'] as String,
        orderId: json['order_id'] as String,
        fullName: json['full_name'] as String,
        address: json['address'] as String,
        phoneNumber: json['phone_number'] as String,
        paymentType: json['payment_type'] as String,
        items: (json['items'] as List<dynamic>)
            .map((e) =>
                CheckoutOrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalItems: json['total_items'] as int,
        totalAmount: (json['total_amount'] as num).toDouble(),
        shippingCharge: (json['shipping_charge'] as num).toDouble(),
        grandTotal: (json['grand_total'] as num).toDouble(),
        status: json['status'] as String,
      );
}