// Updated cart_model.dart

class CartListResponse {
  final int status;
  final List<CartItem> data;
  final dynamic error;
  final String message;

  CartListResponse({
    required this.status,
    required this.data,
    required this.error,
    required this.message,
  });

  factory CartListResponse.fromJson(Map<String, dynamic> json) {
    return CartListResponse(
      status: json['status'] ?? 0,
      data:
          json['data'] != null
              ? (json['data'] as List)
                  .map((item) => CartItem.fromJson(item))
                  .toList()
              : [],
      error: json['error'],
      message: json['message'] ?? '',
    );
  }
}

class CartItem {
  final String id;
  final String email;
  final String productId;
  final String productName;
  final int price;
  final int quantity;
  final int v;
  final List<String> images; // Changed to List<String>

  CartItem({
    required this.id,
    required this.email,
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.v,
    required this.images,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    // Extract product information
    final product =
        json['product'] is Map ? json['product'] as Map<String, dynamic> : null;

    // Handle images - they should come from the product object
    List<String> images = [];
    if (product != null && product['images'] is List) {
      images = (product['images'] as List).map((e) => e.toString()).toList();
    }

    return CartItem(
      id: json['_id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      productId:
          product?['_id']?.toString() ?? json['product']?.toString() ?? '',
      productName:
          product?['name']?.toString() ??
          json['productName']?.toString() ??
          'Unknown Product',
      price: (product?['price'] ?? json['price'] ?? 0).toInt(),
      quantity: (json['quantity'] ?? 0).toInt(),
      v: (json['__v'] ?? 0).toInt(),
      images: images,
    );
  }
}

class CustomerInfo {
  final String name;
  final String phone;
  final String address;
  final String? notes;

  CustomerInfo({
    required this.name,
    required this.phone,
    required this.address,
    this.notes,
  });

  factory CustomerInfo.fromJson(Map<String, dynamic> json) {
    return CustomerInfo(
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      notes: json['notes'],
    );
  }
}

// Checkout response model
class CheckoutResponse {
  final int status;
  final CheckoutData? data;
  final dynamic error;
  final String message;

  CheckoutResponse({
    required this.status,
    this.data,
    this.error,
    required this.message,
  });

  factory CheckoutResponse.fromJson(Map<String, dynamic> json) {
    return CheckoutResponse(
      status: json['status'] ?? 0,
      data: json['data'] != null ? CheckoutData.fromJson(json['data']) : null,
      error: json['error'],
      message: json['message'] ?? '',
    );
  }
}

class CheckoutData {
  final List<OrderInfo> orders;
  final double totalAmount;
  final String message;

  CheckoutData({
    required this.orders,
    required this.totalAmount,
    required this.message,
  });

  factory CheckoutData.fromJson(Map<String, dynamic> json) {
    return CheckoutData(
      orders:
          json['orders'] != null
              ? (json['orders'] as List)
                  .map((order) => OrderInfo.fromJson(order))
                  .toList()
              : [],
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      message: json['message'] ?? '',
    );
  }
}

class OrderInfo {
  final String id;
  final String orderNumber;
  final VendorInfo vendor;
  final double total;
  final String status;
  final DateTime createdAt;

  OrderInfo({
    required this.id,
    required this.orderNumber,
    required this.vendor,
    required this.total,
    required this.status,
    required this.createdAt,
  });

  factory OrderInfo.fromJson(Map<String, dynamic> json) {
    return OrderInfo(
      id: json['_id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      vendor: VendorInfo.fromJson(json['vendor'] ?? {}),
      total: (json['total'] ?? 0).toDouble(),
      status: json['status']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class VendorInfo {
  final String id;
  final String name;
  final String email;

  VendorInfo({required this.id, required this.name, required this.email});

  factory VendorInfo.fromJson(Map<String, dynamic> json) {
    return VendorInfo(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }
}

// Order Models
class OrdersResponse {
  final int status;
  final OrdersData? data;
  final String? error;
  final String message;

  OrdersResponse({
    required this.status,
    this.data,
    this.error,
    required this.message,
  });

  factory OrdersResponse.fromJson(Map<String, dynamic> json) {
    return OrdersResponse(
      status: json['status'] ?? 0,
      data: json['data'] != null ? OrdersData.fromJson(json['data']) : null,
      error: json['error'],
      message: json['message'] ?? '',
    );
  }
}

class OrdersData {
  final List<Order> orders;
  final Pagination pagination;

  OrdersData({required this.orders, required this.pagination});

  factory OrdersData.fromJson(Map<String, dynamic> json) {
    return OrdersData(
      orders:
          (json['orders'] as List?)
              ?.map((order) => Order.fromJson(order))
              .toList() ??
          [],
      pagination: Pagination.fromJson(json['pagination'] ?? {}),
    );
  }
}

class Pagination {
  final int page;
  final int limit;
  final int total;
  final int pages;
  final bool hasMore;

  Pagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
    required this.hasMore,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: json['page'] ?? 0,
      limit: json['limit'] ?? 10,
      total: json['total'] ?? 0,
      pages: json['pages'] ?? 0,
      hasMore: json['hasMore'] ?? false,
    );
  }
}

class Order {
  final String id;
  final Customer customer;
  final Vendor vendor;
  final List<OrderItem> items;
  final OrderSummary orderSummary;
  final CustomerInfo customerInfo;
  final PaymentInfo paymentInfo;
  final String status;
  final List<StatusHistory> statusHistory;
  final DateTime createdAt;
  final DateTime updatedAt;

  Order({
    required this.id,
    required this.customer,
    required this.vendor,
    required this.items,
    required this.orderSummary,
    required this.customerInfo,
    required this.paymentInfo,
    required this.status,
    required this.statusHistory,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['_id'] ?? '',
      customer: Customer.fromJson(json['customer'] ?? {}),
      vendor: Vendor.fromJson(json['vendor'] ?? {}),
      items:
          (json['items'] as List?)
              ?.map((item) => OrderItem.fromJson(item))
              .toList() ??
          [],
      orderSummary: OrderSummary.fromJson(json['orderSummary'] ?? {}),
      customerInfo: CustomerInfo.fromJson(json['customerInfo'] ?? {}),
      paymentInfo: PaymentInfo.fromJson(json['paymentInfo'] ?? {}),
      status: json['status'] ?? 'pending',
      statusHistory:
          (json['statusHistory'] as List?)
              ?.map((status) => StatusHistory.fromJson(status))
              .toList() ??
          [],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  String get orderNumber => 'ORD-${id.substring(id.length - 8).toUpperCase()}';
}

class Customer {
  final String id;
  final String email;
  final String name;
  final String phone;
  final String? picture;

  Customer({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    this.picture,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['_id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      picture: json['picture'],
    );
  }
}

class Vendor {
  final String id;
  final String email;
  final String businessName;

  Vendor({required this.id, required this.email, required this.businessName});

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['_id'] ?? '',
      email: json['email'] ?? '',
      businessName: json['businessName'] ?? '',
    );
  }
}

class OrderItem {
  final Product product;
  final int quantity;
  final double price;
  final double totalPrice;

  OrderItem({
    required this.product,
    required this.quantity,
    required this.price,
    required this.totalPrice,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      product: Product.fromJson(json['product'] ?? {}),
      quantity: json['quantity'] ?? 0,
      price: (json['price'] ?? 0).toDouble(),
      totalPrice: (json['totalPrice'] ?? 0).toDouble(),
    );
  }
}

class Product {
  final String id;
  final String name;
  final double price;
  final List<String> images;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.images,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      images:
          (json['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class OrderSummary {
  final double subtotal;
  final double tax;
  final double shipping;
  final double total;

  OrderSummary({
    required this.subtotal,
    required this.tax,
    required this.shipping,
    required this.total,
  });

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    return OrderSummary(
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      tax: (json['tax'] ?? 0).toDouble(),
      shipping: (json['shipping'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
    );
  }
}

// class CustomerInfo {
//   final String name;
//   final String phone;
//   final String address;
//   final String? notes;

//   CustomerInfo({
//     required this.name,
//     required this.phone,
//     required this.address,
//     this.notes,
//   });

//   factory CustomerInfo.fromJson(Map<String, dynamic> json) {
//     return CustomerInfo(
//       name: json['name'] ?? '',
//       phone: json['phone'] ?? '',
//       address: json['address'] ?? '',
//       notes: json['notes'],
//     );
//   }
// }

class PaymentInfo {
  final String method;
  final String? paymentProof;
  final double paidAmount;

  PaymentInfo({
    required this.method,
    this.paymentProof,
    required this.paidAmount,
  });

  factory PaymentInfo.fromJson(Map<String, dynamic> json) {
    return PaymentInfo(
      method: json['method'] ?? '',
      paymentProof: json['paymentProof'],
      paidAmount: (json['paidAmount'] ?? 0).toDouble(),
    );
  }
}

class StatusHistory {
  final String status;
  final String changedBy;
  final DateTime changedAt;
  final String? notes;

  StatusHistory({
    required this.status,
    required this.changedBy,
    required this.changedAt,
    this.notes,
  });

  factory StatusHistory.fromJson(Map<String, dynamic> json) {
    return StatusHistory(
      status: json['status'] ?? '',
      changedBy: json['changedBy'] ?? '',
      changedAt: DateTime.tryParse(json['changedAt'] ?? '') ?? DateTime.now(),
      notes: json['notes'],
    );
  }
}
