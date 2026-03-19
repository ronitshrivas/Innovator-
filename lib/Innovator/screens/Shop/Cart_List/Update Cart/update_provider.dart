import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/Innovator/screens/Shop/Cart_List/Update%20Cart/update_cart_model.dart';
import 'update_cart_service.dart';

final updateCartServiceProvider = Provider((ref) => UpdateCartService());

final updateCartProvider = FutureProvider.family<UpdateCartModel, (String, int)>(
  (ref, params) async {
    final (productId, quantity) = params;
    final service = ref.read(updateCartServiceProvider);
    return service.patchCart(productId: productId, quantity: quantity);
  },
);